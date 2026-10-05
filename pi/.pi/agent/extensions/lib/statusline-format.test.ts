import { test } from 'node:test';
import { strictEqual, deepStrictEqual } from 'node:assert';
import {
  StatusTone,
  CompactStatus,
  compactStatuses,
  chooseLayout,
  shortenRepository,
  formatCount,
  toneToSemanticColor,
  formatTokenUsage,
  formatCost,
  formatContextPercent,
  contextPercentTone,
  formatEffort,
  formatElapsed,
  resolveRepoLabel,
  buildMetadataParts,
  metadataPlainWidth,
  healthPlainWidth,
  chooseFooterLayout,
  footerGap,
  rightAlignPadding,
} from './statusline-format';

// compactStatuses tests
test('compactStatuses: healthy known strings', () => {
  const statuses = new Map([
    ['langfuse', 'Langfuse'],
    ['mcp', 'MCP: 2'],
    ['lsp', 'LSP Active: typescript, eslint'],
  ]);
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [
    { label: 'LSP 2', tone: 'info' as StatusTone },
    { label: 'MCP 2', tone: 'success' as StatusTone },
    { label: 'Langfuse', tone: 'success' as StatusTone },
  ]);
});

test('compactStatuses: spec example - trace sent, mcp with count, pi-lens with names', () => {
  const statuses = new Map([
    ['langfuse', '✓ (trace sent)'],
    ['mcp', '📡 MCP: 2 servers enabled'],
    ['pi-lens', 'LSP Active: bash, html, ast-grep, typos, opengrep'],
  ]);
  const result = compactStatuses(statuses);
  strictEqual(result.length, 3);
  deepStrictEqual(result, [
    { label: 'LSP 5', tone: 'info' as StatusTone },
    { label: 'MCP 2', tone: 'success' as StatusTone },
    { label: 'Langfuse', tone: 'success' as StatusTone },
  ]);
});

test('compactStatuses: always emits 3 entries even with partial input', () => {
  const statuses = new Map([['mcp', 'error: connection refused']]);
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [
    { label: 'LSP', tone: 'muted' as StatusTone },
    { label: 'MCP', tone: 'error' as StatusTone },
    { label: 'Langfuse', tone: 'muted' as StatusTone },
  ]);
});

test('compactStatuses: error pattern classification', () => {
  const statuses = new Map([
    ['langfuse', 'Langfuse error'],
    ['mcp', 'MCP disconnected'],
    ['lsp', 'LSP failed'],
  ]);
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [
    { label: 'LSP', tone: 'error' as StatusTone },
    { label: 'MCP', tone: 'error' as StatusTone },
    { label: 'Langfuse', tone: 'error' as StatusTone },
  ]);
});

test('compactStatuses: warning pattern classification', () => {
  const statuses = new Map([
    ['langfuse', 'Langfuse warn'],
    ['mcp', 'MCP degraded'],
    ['lsp', 'LSP unknown'],
  ]);
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [
    { label: 'LSP', tone: 'warning' as StatusTone },
    { label: 'MCP', tone: 'warning' as StatusTone },
    { label: 'Langfuse', tone: 'warning' as StatusTone },
  ]);
});

test('compactStatuses: classifies by pattern without service name mention', () => {
  const statuses = new Map([
    ['langfuse', 'connected'],
    ['mcp', 'active'],
    ['lsp', 'enabled'],
  ]);
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [
    { label: 'LSP', tone: 'success' as StatusTone },
    { label: 'MCP', tone: 'success' as StatusTone },
    { label: 'Langfuse', tone: 'success' as StatusTone },
  ]);
});

test('compactStatuses: keys are matched case-insensitively', () => {
  const statuses = new Map([
    ['Langfuse', 'LANGFUSE ENABLED'],
    ['MCP', 'MCP: 1'],
    ['LsP', 'LSP ACTIVE: plugin1'],
  ]);
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [
    { label: 'LSP 1', tone: 'info' as StatusTone },
    { label: 'MCP 1', tone: 'success' as StatusTone },
    { label: 'Langfuse', tone: 'success' as StatusTone },
  ]);
});

test('compactStatuses: mcp with numeric count', () => {
  const statuses = new Map([['mcp', 'MCP: 3']]);
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [
    { label: 'LSP', tone: 'muted' as StatusTone },
    { label: 'MCP 3', tone: 'success' as StatusTone },
    { label: 'Langfuse', tone: 'muted' as StatusTone },
  ]);
});

test('compactStatuses: lsp counts comma-separated names', () => {
  const statuses = new Map([['lsp', 'LSP Active: python, rust, go, javascript']]);
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [
    { label: 'LSP 4', tone: 'info' as StatusTone },
    { label: 'MCP', tone: 'muted' as StatusTone },
    { label: 'Langfuse', tone: 'muted' as StatusTone },
  ]);
});

test('compactStatuses: output order is always lsp-mcp-langfuse', () => {
  const statuses = new Map([
    ['lsp', 'LSP Active: xyz'],
    ['mcp', 'MCP: 1'],
    ['langfuse', 'Langfuse'],
  ]);
  const result = compactStatuses(statuses);
  strictEqual(result[0].label, 'LSP 1');
  strictEqual(result[1].label, 'MCP 1');
  strictEqual(result[2].label, 'Langfuse');
});

test('compactStatuses: pi-lens fallback when lsp absent', () => {
  const statuses = new Map([['pi-lens', 'LSP Active: rust, python']]);
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [
    { label: 'LSP 2', tone: 'info' as StatusTone },
    { label: 'MCP', tone: 'muted' as StatusTone },
    { label: 'Langfuse', tone: 'muted' as StatusTone },
  ]);
});

test('compactStatuses: lsp key takes precedence over pi-lens fallback', () => {
  const statuses = new Map([
    ['lsp', 'LSP Active: go'],
    ['pi-lens', 'LSP Active: python, rust'],
  ]);
  const result = compactStatuses(statuses);
  strictEqual(result[0].label, 'LSP 1');
  strictEqual(result[0].tone, 'info');
});

test('compactStatuses: case variations in pi-lens key', () => {
  const statuses = new Map([['Pi-Lens', 'LSP Active: typescript']])
;
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [
    { label: 'LSP 1', tone: 'info' as StatusTone },
    { label: 'MCP', tone: 'muted' as StatusTone },
    { label: 'Langfuse', tone: 'muted' as StatusTone },
  ]);
});

test('compactStatuses: LSP Active with whitespace yields no count', () => {
  const statuses = new Map([['lsp', 'LSP Active:   ']])
;
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [
    { label: 'LSP', tone: 'info' as StatusTone },
    { label: 'MCP', tone: 'muted' as StatusTone },
    { label: 'Langfuse', tone: 'muted' as StatusTone },
  ]);
});

test('compactStatuses: empty map emits muted for all services', () => {
  const statuses = new Map<string, string>();
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [
    { label: 'LSP', tone: 'muted' as StatusTone },
    { label: 'MCP', tone: 'muted' as StatusTone },
    { label: 'Langfuse', tone: 'muted' as StatusTone },
  ]);
});

// chooseLayout tests
test('chooseLayout: single when total fits', () => {
  strictEqual(chooseLayout(120, 71, 38), 'single');
});

test('chooseLayout: stacked when total exceeds width', () => {
  strictEqual(chooseLayout(100, 71, 38), 'stacked');
});

test('chooseLayout: boundary at 112 = 71+3+38', () => {
  strictEqual(chooseLayout(111, 71, 38), 'stacked');
  strictEqual(chooseLayout(112, 71, 38), 'single');
});

// shortenRepository tests
test('shortenRepository: original when code-point width allows', () => {
  strictEqual(shortenRepository('user/repo', 20), 'user/repo');
});

test('shortenRepository: uses …/last/two pattern when it fits', () => {
  const result = shortenRepository('badaniya/GoDCApp/NVO-13662', 20);
  strictEqual(result, '…/GoDCApp/NVO-13662');
});

test('shortenRepository: fallback ellipsis when two-segment doesn\'t fit', () => {
  const result = shortenRepository('a/b/c/d/e/f', 5);
  strictEqual(result.startsWith('…'), true);
  const cpWidth = Array.from(result).length;
  strictEqual(cpWidth <= 5, true);
});

test('shortenRepository: single segment path with tight width', () => {
  const result = shortenRepository('verylongsinglesegment', 10);
  const cpWidth = Array.from(result).length;
  strictEqual(cpWidth <= 10, true);
  strictEqual(result.startsWith('…'), true);
});

test('shortenRepository: emoji code-point width enforcement', () => {
  const result = shortenRepository('a/b/c/d/😀x', 3);
  strictEqual(result.length > 0, true);
  const cpWidth = Array.from(result).length;
  strictEqual(cpWidth <= 3, true);
  // Verify no lone surrogates
  for (let i = 0; i < result.length; i++) {
    const code = result.charCodeAt(i);
    if (code >= 0xd800 && code <= 0xdbff) {
      const next = result.charCodeAt(i + 1);
      strictEqual(next >= 0xdc00 && next <= 0xdfff, true, 'surrogate pairs must be complete');
    }
  }
});

test('shortenRepository: emoji handling in path segments', () => {
  const result = shortenRepository('user/😀/repo', 15);
  strictEqual(typeof result, 'string');
  const codePoints = Array.from(result);
  strictEqual(codePoints.length > 0, true);
});

// formatCount tests - correctness
test('formatCount(999500) === "999.5K" (k = 999.5 < 999.95)', () => {
  strictEqual(formatCount(999500), '999.5K');
});

test('formatCount(999899) === "999.9K" (k = 999.899, toFixed(1) = 999.9 < 1000)', () => {
  strictEqual(formatCount(999899), '999.9K');
});

test('formatCount(999940) === "999.9K" (k = 999.94, toFixed(1) = 999.9 < 1000)', () => {
  strictEqual(formatCount(999940), '999.9K');
});

test('formatCount(999950) === "1M" (k = 999.95 >= 999.95 threshold)', () => {
  strictEqual(formatCount(999950), '1M');
});

test('formatCount(999500000) === "999.5M" (m = 999.5 < 999.95)', () => {
  strictEqual(formatCount(999500000), '999.5M');
});

test('formatCount(999950000) === "1B" (m = 999.95 >= 999.95 threshold)', () => {
  strictEqual(formatCount(999950000), '1B');
});

test('formatCount: K/M/B unit formatting', () => {
  strictEqual(formatCount(1000), '1K');
  strictEqual(formatCount(1500), '1.5K');
  strictEqual(formatCount(1000000), '1M');
  strictEqual(formatCount(1500000), '1.5M');
  strictEqual(formatCount(1000000000), '1B');
  strictEqual(formatCount(1500000000), '1.5B');
});

test('formatCount: sub-1000 integers', () => {
  strictEqual(formatCount(1), '1');
  strictEqual(formatCount(5), '5');
  strictEqual(formatCount(42), '42');
  strictEqual(formatCount(999), '999');
});

test('formatCount: zero and negative values', () => {
  strictEqual(formatCount(0), '0');
  strictEqual(formatCount(-1), '-1');
  strictEqual(formatCount(-100), '-100');
  strictEqual(formatCount(-999), '-999');
});

// toneToSemanticColor tests
test('toneToSemanticColor: maps each tone to a valid theme token', () => {
  strictEqual(toneToSemanticColor('success'), 'success');
  strictEqual(toneToSemanticColor('warning'), 'warning');
  strictEqual(toneToSemanticColor('error'), 'error');
  strictEqual(toneToSemanticColor('info'), 'accent');
  strictEqual(toneToSemanticColor('muted'), 'muted');
});

// formatTokenUsage tests
test('formatTokenUsage: renders input upward and output downward', () => {
  strictEqual(formatTokenUsage(0, 0), '\u21910 \u21930');
  strictEqual(formatTokenUsage(1500, 2500000), '\u21911.5K \u21932.5M');
});

// formatCost tests
test('formatCost: omits when zero', () => {
  strictEqual(formatCost(0), undefined);
});

test('formatCost: formats to 3 decimal places', () => {
  strictEqual(formatCost(1.2), '$1.200');
  strictEqual(formatCost(0.0051), '$0.005');
});

// formatContextPercent tests
test('formatContextPercent: undefined/null yields undefined', () => {
  strictEqual(formatContextPercent(undefined), undefined);
  strictEqual(formatContextPercent(null), undefined);
});

test('formatContextPercent: rounds to whole number', () => {
  strictEqual(formatContextPercent(42.4), '42%');
  strictEqual(formatContextPercent(42.5), '43%');
});

// contextPercentTone tests
test('contextPercentTone: boundaries at 70 and 90', () => {
  strictEqual(contextPercentTone(0), 'success');
  strictEqual(contextPercentTone(69), 'success');
  strictEqual(contextPercentTone(70), 'warning');
  strictEqual(contextPercentTone(89), 'warning');
  strictEqual(contextPercentTone(90), 'error');
  strictEqual(contextPercentTone(100), 'error');
});

// formatEffort tests
test('formatEffort: undefined yields undefined, otherwise the level label', () => {
  strictEqual(formatEffort(undefined), undefined);
  strictEqual(formatEffort('high'), 'high');
});

// formatElapsed tests
test('formatElapsed: omits hours segment when zero', () => {
  strictEqual(formatElapsed(0), '\u231a0m');
  strictEqual(formatElapsed(59999), '\u231a0m');
  strictEqual(formatElapsed(60000), '\u231a1m');
});

test('formatElapsed: includes hours segment when non-zero', () => {
  strictEqual(formatElapsed(3600000), '\u231a1h0m');
  strictEqual(formatElapsed(3660000), '\u231a1h1m');
  strictEqual(formatElapsed(7320000), '\u231a2h2m');
});

test('formatElapsed: negative values clamp to zero', () => {
  strictEqual(formatElapsed(-500), '\u231a0m');
});

// resolveRepoLabel tests
test('resolveRepoLabel: basename with branch', () => {
  strictEqual(resolveRepoLabel('/home/user/project', 'main'), 'project (main)');
});

test('resolveRepoLabel: basename without branch', () => {
  strictEqual(resolveRepoLabel('/home/user/project', null), 'project');
  strictEqual(resolveRepoLabel('/home/user/project', undefined), 'project');
});

test('resolveRepoLabel: trailing slash handled', () => {
  strictEqual(resolveRepoLabel('/home/user/project/', 'dev'), 'project (dev)');
});

// buildMetadataParts tests
test('buildMetadataParts: full order model, effort, context, tokens, cost, elapsed, repo', () => {
  const parts = buildMetadataParts({
    modelId: 'claude-sonnet',
    tokenInput: 100,
    tokenOutput: 200,
    cost: 0.5,
    contextPercent: 42,
    effort: 'high',
    elapsedMs: 60000,
    repoLabel: 'project (main)',
  });
  deepStrictEqual(parts, [
    { text: 'claude-sonnet', color: 'accent' },
    { text: 'high', color: 'muted', attachToPrevious: true },
    { text: '42%', color: 'success' },
    { text: '\u2191100 \u2193200', color: 'syntaxType' },
    { text: '$0.500', color: 'warning' },
    { text: '\u231a1m', color: 'dim' },
    { text: 'project (main)', color: 'accent' },
  ]);
});

test('buildMetadataParts: omits cost when zero, effort when undefined, model when absent', () => {
  const parts = buildMetadataParts({
    tokenInput: 0,
    tokenOutput: 0,
    cost: 0,
    contextPercent: undefined,
    elapsedMs: 0,
  });
  deepStrictEqual(parts, [
    { text: '\u21910 \u21930', color: 'syntaxType' },
    { text: '\u231a0m', color: 'dim' },
  ]);
});

test('buildMetadataParts: high context percent gets error tone', () => {
  const parts = buildMetadataParts({
    tokenInput: 0,
    tokenOutput: 0,
    cost: 0,
    contextPercent: 95,
    elapsedMs: 0,
  });
  strictEqual(parts.some((p) => p.text === '95%' && p.color === 'error'), true);
});

test('buildMetadataParts: shortens repoLabel when repoMaxWidth is given', () => {
  const parts = buildMetadataParts({
    tokenInput: 0,
    tokenOutput: 0,
    cost: 0,
    elapsedMs: 0,
    repoLabel: 'badaniya/GoDCApp/NVO-13662 (main)',
    repoMaxWidth: 10,
  });
  const repoPart = parts.find((p) => p.color === 'accent');
  strictEqual(repoPart !== undefined, true);
  strictEqual(Array.from(repoPart!.text).length <= 10, true);
});

// metadataPlainWidth / healthPlainWidth tests
test('metadataPlainWidth: sums text widths plus " │ " separators', () => {
  const parts = [
    { text: 'ab', color: 'accent' as const },
    { text: 'cde', color: 'dim' as const },
  ];
  strictEqual(metadataPlainWidth(parts), 2 + 3 + 3);
});

test('metadataPlainWidth: uses one space for an attached effort level', () => {
  const parts = [
    { text: 'model', color: 'accent' as const },
    { text: 'high', color: 'muted' as const, attachToPrevious: true as const },
    { text: '42%', color: 'success' as const },
  ];
  strictEqual(metadataPlainWidth(parts), 5 + 1 + 4 + 3 + 3);
});

test('metadataPlainWidth: empty array is zero', () => {
  strictEqual(metadataPlainWidth([]), 0);
});

test('footerGap: right-aligns health after the metadata-to-health separator', () => {
  strictEqual(footerGap(80, 30, 20), ' '.repeat(27));
  strictEqual(footerGap(53, 30, 20), '');
  strictEqual(footerGap(52, 30, 20), '');
});

test('rightAlignPadding: aligns a standalone health row to the terminal edge', () => {
  strictEqual(rightAlignPadding(80, 20), ' '.repeat(60));
  strictEqual(rightAlignPadding(20, 20), '');
  strictEqual(rightAlignPadding(19, 20), '');
});

test('healthPlainWidth: accounts for colored-dot prefixes and " │ " separators', () => {
  const statuses: CompactStatus[] = [
    { label: 'Langfuse', tone: 'muted' },
    { label: 'MCP 2', tone: 'success' },
    { label: 'LSP', tone: 'muted' },
  ];
  // Each rendered status is "● <label>"; two separators are " │ ".
  strictEqual(healthPlainWidth(statuses), 8 + 5 + 3 + 2 * 3 + 3 * 2);
});

test('healthPlainWidth: empty array is zero', () => {
  strictEqual(healthPlainWidth([]), 0);
});

// chooseFooterLayout tests
test('chooseFooterLayout: delegates to chooseLayout using computed widths', () => {
  const parts = [{ text: '0123456789'.repeat(7), color: 'accent' as const }]; // 70 chars
  const statuses: CompactStatus[] = [
    { label: 'Langfuse', tone: 'muted' },
    { label: 'MCP', tone: 'muted' },
    { label: 'LSP', tone: 'muted' },
  ];
  // metadataWidth=70; healthWidth = labels 14 + dots 6 + separators 6 = 26.
  strictEqual(chooseFooterLayout(99, parts, statuses), 'single');
  strictEqual(chooseFooterLayout(98, parts, statuses), 'stacked');
});
