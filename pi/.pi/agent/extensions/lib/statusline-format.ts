/**
 * Statusline format helpers for pi custom footer.
 * Classifies health/connection statuses, extracts counts, and manages layout.
 */

export type StatusTone = 'success' | 'info' | 'warning' | 'error' | 'muted';

export interface CompactStatus {
  label: string;
  tone: StatusTone;
}

/**
 * Classify a status string based on its content patterns.
 * Classification is independent of which service the key represents.
 * Empty value defaults to muted.
 */
function classifyTone(value: string): StatusTone {
  const lower = value.toLowerCase();

  // Empty value is muted
  if (value.length === 0) {
    return 'muted';
  }

  // Error patterns: error, fail, disconnected, refused
  if (/error|fail|disconnected|refused/.test(lower)) {
    return 'error';
  }

  // Warning patterns: warn, degraded, unknown
  if (/warn|degraded|unknown/.test(lower)) {
    return 'warning';
  }

  // LSP/pi-lens Active: pattern is info tone
  if (/active:/.test(lower)) {
    return 'info';
  }

  // Success patterns: trace sent, enabled, connected, active
  if (/trace\s+sent|enabled|connected|active/.test(lower)) {
    return 'success';
  }

  // If value is present and no error/warning/info pattern matched -> assume success
  return 'success';
}

/**
 * Extract count from pattern like "MCP: 2" or "📡 MCP: 2 servers".
 * Returns the number if found, undefined if not present.
 */
function extractMcpCount(value: string): number | undefined {
  const match = value.match(/MCP:\s*(\d+)/i);
  return match ? parseInt(match[1], 10) : undefined;
}

/**
 * Count comma-separated names after "Active:" pattern.
 * Returns the count of items, or undefined if pattern not found or no names.
 */
function countLspNames(value: string): number | undefined {
  const lower = value.toLowerCase();
  const match = lower.match(/active:\s*(.+)/);
  if (!match) return undefined;
  const names = match[1].split(',').map((s) => s.trim()).filter((s) => s.length > 0);
  return names.length > 0 ? names.length : undefined;
}

/**
 * Compact a single status value into label and tone.
 * For Langfuse: always label "Langfuse"
 * For MCP: label "MCP" or "MCP <count>" if count present
 * For LSP: label "LSP" or "LSP <count>" if Active: pattern with names
 */
function compactSingle(normKey: string, value: string | undefined): CompactStatus {
  const tone = classifyTone(value || '');

  if (normKey === 'langfuse') {
    return { label: 'Langfuse', tone };
  }

  if (normKey === 'mcp') {
    const count = value ? extractMcpCount(value) : undefined;
    const label = count !== undefined ? `MCP ${count}` : 'MCP';
    return { label, tone };
  }

  if (normKey === 'lsp') {
    // countLspNames returns undefined if no names found (including whitespace-only)
    const count = value ? countLspNames(value) : undefined;
    const label = count !== undefined && count > 0 ? `LSP ${count}` : 'LSP';
    return { label, tone };
  }

  // Fallback (shouldn't happen with expected keys)
  return { label: normKey, tone };
}

/**
 * Find a map key matching the given normalized key, case-insensitively.
 */
function findKeyByNorm(statuses: ReadonlyMap<string, string>, normKey: string): string | undefined {
  for (const key of statuses.keys()) {
    if (key.toLowerCase() === normKey.toLowerCase()) {
      return key;
    }
  }
  return undefined;
}

/**
 * Convert a map of statuses into a compact, stably-ordered array.
 * Always returns exactly 3 entries: LSP, MCP, Langfuse (in that order).
 * Keys are matched case-insensitively.
 * For LSP, tries 'lsp' first, then 'pi-lens' as fallback.
 * Absent integrations produce entries with muted tone.
 */
export function compactStatuses(statuses: ReadonlyMap<string, string>): CompactStatus[] {
  // Always emit exactly 3 entries in fixed order
  const serviceSpecs: Array<{ normKey: string; fallback?: string }> = [
    { normKey: 'lsp', fallback: 'pi-lens' },
    { normKey: 'mcp' },
    { normKey: 'langfuse' },
  ];

  const result: CompactStatus[] = [];

  for (const spec of serviceSpecs) {
    let mapKey = findKeyByNorm(statuses, spec.normKey);
    if (!mapKey && spec.fallback) {
      mapKey = findKeyByNorm(statuses, spec.fallback);
    }

    // Always emit an entry, using value if found or undefined if not
    const value = mapKey ? statuses.get(mapKey) : undefined;
    result.push(compactSingle(spec.normKey, value));
  }

  return result;
}

/**
 * Choose layout based on available width.
 * Single-line layout if metadataWidth + 3 + healthWidth <= width.
 * Otherwise stacked layout.
 */
export function chooseLayout(
  width: number,
  metadataWidth: number,
  healthWidth: number,
): 'single' | 'stacked' {
  const required = metadataWidth + 3 + healthWidth;
  return required <= width ? 'single' : 'stacked';
}

/**
 * Get a code-point-safe suffix of a string.
 * Uses Array.from() to iterate code points, then takes from the end.
 */
function getCodePointSuffix(str: string, maxCodePoints: number): string {
  const codePoints = Array.from(str);
  if (codePoints.length <= maxCodePoints) {
    return str;
  }
  return codePoints.slice(-maxCodePoints).join('');
}

/**
 * Get the code-point width of a string.
 */
function codePointWidth(str: string): number {
  return Array.from(str).length;
}

/**
 * Shorten a repository path to fit within maxWidth (measured in code points).
 * Strategy:
 * 1. Return original if it fits.
 * 2. Retain last two slash segments under …/ prefix.
 * 3. Fall back to … + code-point-safe suffix if needed.
 */
export function shortenRepository(repository: string, maxWidth: number): string {
  const repoWidth = codePointWidth(repository);
  if (repoWidth <= maxWidth) {
    return repository;
  }

  const parts = repository.split('/');

  // Try …/last/two/segments
  if (parts.length >= 2) {
    const last = parts.at(-1);
    const secondLast = parts.at(-2);
    if (last && secondLast) {
      const twoSegment = `…/${secondLast}/${last}`;
      if (codePointWidth(twoSegment) <= maxWidth) {
        return twoSegment;
      }
    }
  }

  // Fall back to … plus a code-point-safe suffix
  const ellipsis = '…';
  const maxSuffix = Math.max(1, maxWidth - codePointWidth(ellipsis));
  const suffix = getCodePointSuffix(repository, maxSuffix);
  const result = `${ellipsis}${suffix}`;
  // Trim the final result to maxWidth, code-point-safe
  const resultWidth = codePointWidth(result);
  if (resultWidth <= maxWidth) {
    return result;
  }
  const codePoints = Array.from(result);
  return codePoints.slice(0, maxWidth).join('');
}

/**
 * Format a count: 0-999 as-is, 1000+ with K/M/B suffixes.
 * e.g., 1500 -> "1.5K", 2500000 -> "2.5M", 1500000000 -> "1.5B"
 * Never emits "1000.0<K|M|B>"; if rounding would produce that, steps to next unit.
 * Negative values return their string representation.
 */
export function formatCount(value: number): string {
  // Below 1000 (including negative)
  if (value < 1000) {
    return String(Math.floor(value));
  }

  // K range: 1000-999999
  if (value < 1000000) {
    const k = value / 1000;
    // Check if k rounded to 1 decimal would be >= 1000; if so, step to M
    // This happens when k >= 999.95
    if (k >= 999.95) {
      return '1M';
    }
    const formatted = k % 1 === 0 ? String(Math.floor(k)) : k.toFixed(1);
    return `${formatted}K`;
  }

  // M range: 1000000-999999999
  if (value < 1000000000) {
    const m = value / 1000000;
    // Check if m rounded to 1 decimal would be >= 1000; if so, step to B
    // This happens when m >= 999.95
    if (m >= 999.95) {
      return '1B';
    }
    const formatted = m % 1 === 0 ? String(Math.floor(m)) : m.toFixed(1);
    return `${formatted}M`;
  }

  // B range: 1000000000+
  const b = value / 1000000000;
  const formatted = b % 1 === 0 ? String(Math.floor(b)) : b.toFixed(1);
  return `${formatted}B`;
}

import type { Color } from '@earendil-works/pi-tui';

/**
 * Semantic color names used by the custom footer. Each is a valid pi Theme
 * `ThemeColor` token (never a hard-coded ANSI value); the runtime extension
 * passes these straight into `theme.style(text, { fg: color })`.
 */
export type SemanticColor = 'accent' | 'success' | 'warning' | 'error' | 'muted' | 'dim' | 'syntaxType';

export const FOOTER_METADATA_COLORS = Object.freeze({
  model: Object.freeze({ kind: 'rgb', r: 250, g: 179, b: 135 }),
  effort: Object.freeze({ kind: 'rgb', r: 203, g: 166, b: 247 }),
  directory: Object.freeze({ kind: 'rgb', r: 180, g: 190, b: 254 }),
  branch: Object.freeze({ kind: 'rgb', r: 203, g: 166, b: 247 }),
} satisfies Record<'model' | 'effort' | 'directory' | 'branch', Color>);

export type MetadataColor = SemanticColor | Color;

/**
 * Map a health-status tone to a semantic theme color.
 * There is no dedicated "info" theme token, so info maps to 'accent'.
 */
export function toneToSemanticColor(tone: StatusTone): SemanticColor {
  switch (tone) {
    case 'success':
      return 'success';
    case 'warning':
      return 'warning';
    case 'error':
      return 'error';
    case 'info':
      return 'accent';
    case 'muted':
    default:
      return 'muted';
  }
}

/** Format aggregated token usage as "↑<input> ↓<output>" using formatCount. */
export function formatTokenUsage(input: number, output: number): string {
  return `↑${formatCount(input)} ↓${formatCount(output)}`;
}

/** Format aggregated cost, omitting it entirely when zero. */
export function formatCost(cost: number): string | undefined {
  if (cost === 0) {
    return undefined;
  }
  return `$${cost.toFixed(3)}`;
}

/** Format context usage percent, rounded to a whole number. Undefined/null yields undefined. */
export function formatContextPercent(percent: number | null | undefined): string | undefined {
  if (percent === null || percent === undefined) {
    return undefined;
  }
  return `${Math.round(percent)}%`;
}

/** Classify context percent into a tone: green below 70, warning 70-89, error 90+. */
export function contextPercentTone(percent: number): 'success' | 'warning' | 'error' {
  if (percent >= 90) {
    return 'error';
  }
  if (percent >= 70) {
    return 'warning';
  }
  return 'success';
}

/** Format the thinking/effort level. Undefined input yields undefined. */
export function formatEffort(level: string | undefined): string | undefined {
  return level;
}

/** Format elapsed milliseconds as "󰥔 <Nh><Nm>", omitting the hours segment when zero. */
export function formatElapsed(elapsedMs: number): string {
  const totalMinutes = Math.max(0, Math.floor(elapsedMs / 60000));
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  return hours > 0 ? `󰥔 ${hours}h${minutes}m` : `󰥔 ${minutes}m`;
}

/**
 * Resolve the repository label: "<basename> (<branch>)" when a branch is known,
 * otherwise just the working directory basename.
 */
export function resolveRepoLabel(cwd: string, branch: string | null | undefined): string {
  const segments = cwd.split('/').filter((s) => s.length > 0);
  const base = segments.at(-1) ?? cwd;
  return branch ? `${base} (${branch})` : base;
}

/** A single colored segment of the metadata row. */
export interface MetadataPart {
  text: string;
  color: MetadataColor;
  /** Render this metadata text in bold without affecting adjacent separators or icons. */
  bold?: true;
  /** Join with a preceding segment using one space instead of " │ ". */
  attachToPrevious?: true;
}

export interface MetadataInput {
  modelId?: string;
  tokenInput: number;
  tokenOutput: number;
  cost: number;
  contextPercent?: number | null;
  effort?: string;
  elapsedMs: number;
  directory?: string;
  branch?: string | null;
  /** When provided, directory is shortened to fit this code-point width via shortenRepository. */
  repoMaxWidth?: number;
}

/**
 * Build the ordered metadata parts for the footer's first row:
 * model/effort, context/token usage/cost/duration, then directory and branch icon-label pairs.
 */
export function buildMetadataParts(input: MetadataInput): MetadataPart[] {
  const parts: MetadataPart[] = [];

  if (input.modelId) {
    parts.push({ text: input.modelId, color: FOOTER_METADATA_COLORS.model, bold: true });
  }

  const effortText = formatEffort(input.effort);
  if (effortText !== undefined) {
    parts.push({
      text: effortText,
      color: FOOTER_METADATA_COLORS.effort,
      attachToPrevious: input.modelId ? true : undefined,
    });
  }

  const pctText = formatContextPercent(input.contextPercent);
  if (pctText !== undefined) {
    const pct = Math.round(input.contextPercent as number);
    parts.push({ text: pctText, color: contextPercentTone(pct) });
  }

  parts.push({
    text: formatTokenUsage(input.tokenInput, input.tokenOutput),
    color: 'syntaxType',
    ...(pctText !== undefined ? { attachToPrevious: true } : {}),
  });

  const costText = formatCost(input.cost);
  if (costText !== undefined) {
    parts.push({ text: costText, color: 'warning', attachToPrevious: true });
  }

  parts.push({ text: formatElapsed(input.elapsedMs), color: 'muted', attachToPrevious: true });

  if (input.directory) {
    const directory =
      input.repoMaxWidth !== undefined ? shortenRepository(input.directory, input.repoMaxWidth) : input.directory;
    parts.push({ text: '󰉋', color: 'muted' });
    parts.push({ text: directory, color: FOOTER_METADATA_COLORS.directory, bold: true, attachToPrevious: true });

    if (input.branch) {
      parts.push({ text: '󰊢', color: 'muted', attachToPrevious: true });
      parts.push({ text: input.branch, color: FOOTER_METADATA_COLORS.branch, bold: true, attachToPrevious: true });
    }
  }

  return parts;
}

function metadataSeparatorWidth(part: MetadataPart, index: number): number {
  if (index === 0) {
    return 0;
  }
  return part.attachToPrevious ? 1 : 3;
}

/** Code-point width of the metadata row, before coloring. */
export function metadataPlainWidth(parts: readonly MetadataPart[]): number {
  return parts.reduce(
    (sum, part, index) => sum + Array.from(part.text).length + metadataSeparatorWidth(part, index),
    0,
  );
}

/** Spaces required to right-align health after its leading " │ " separator. */
export function footerGap(width: number, metadataWidth: number, healthWidth: number): string {
  return ' '.repeat(Math.max(0, width - metadataWidth - 3 - healthWidth));
}

/** Spaces required to right-align a standalone row. */
export function rightAlignPadding(width: number, contentWidth: number): string {
  return ' '.repeat(Math.max(0, width - contentWidth));
}

/** Code-point width of `● <label>` health entries joined with " │ ", before coloring. */
export function healthPlainWidth(statuses: readonly CompactStatus[]): number {
  if (statuses.length === 0) {
    return 0;
  }
  const textWidth = statuses.reduce((sum, s) => sum + Array.from(s.label).length + 2, 0);
  return textWidth + (statuses.length - 1) * 3;
}

/** Convenience wrapper: choose single/stacked layout directly from metadata parts and health statuses. */
export function chooseFooterLayout(
  width: number,
  metadataParts: readonly MetadataPart[],
  healthStatuses: readonly CompactStatus[],
): 'single' | 'stacked' {
  return chooseLayout(width, metadataPlainWidth(metadataParts), healthPlainWidth(healthStatuses));
}
