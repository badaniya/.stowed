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
 * Always returns exactly 3 entries: Langfuse, MCP, LSP (in that order).
 * Keys are matched case-insensitively.
 * For LSP, tries 'lsp' first, then 'pi-lens' as fallback.
 * Absent integrations produce entries with muted tone.
 */
export function compactStatuses(statuses: ReadonlyMap<string, string>): CompactStatus[] {
  // Always emit exactly 3 entries in fixed order
  const serviceSpecs: Array<{ normKey: string; fallback?: string }> = [
    { normKey: 'langfuse' },
    { normKey: 'mcp' },
    { normKey: 'lsp', fallback: 'pi-lens' },
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
    // Check if rounded value would be >= 1000; if so, emit 1M
    if (Math.round(k) >= 1000) {
      return '1M';
    }
    const formatted = k % 1 === 0 ? String(Math.floor(k)) : k.toFixed(1);
    return `${formatted}K`;
  }

  // M range: 1000000-999999999
  if (value < 1000000000) {
    const m = value / 1000000;
    // Check if rounded value would be >= 1000; if so, emit 1B
    if (Math.round(m) >= 1000) {
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
