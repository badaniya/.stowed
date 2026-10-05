import { test } from 'node:test';
import { strictEqual, deepStrictEqual } from 'node:assert';
import {
  StatusTone,
  CompactStatus,
  compactStatuses,
  chooseLayout,
  shortenRepository,
  formatCount,
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
    { label: 'Langfuse', tone: 'success' as StatusTone },
    { label: 'MCP 2', tone: 'success' as StatusTone },
    { label: 'LSP 2', tone: 'info' as StatusTone },
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
    { label: 'Langfuse', tone: 'success' as StatusTone },
    { label: 'MCP 2', tone: 'success' as StatusTone },
    { label: 'LSP 5', tone: 'info' as StatusTone },
  ]);
});

test('compactStatuses: always emits 3 entries even with partial input', () => {
  const statuses = new Map([['mcp', 'error: connection refused']]);
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [
    { label: 'Langfuse', tone: 'muted' as StatusTone },
    { label: 'MCP', tone: 'error' as StatusTone },
    { label: 'LSP', tone: 'muted' as StatusTone },
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
    { label: 'Langfuse', tone: 'error' as StatusTone },
    { label: 'MCP', tone: 'error' as StatusTone },
    { label: 'LSP', tone: 'error' as StatusTone },
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
    { label: 'Langfuse', tone: 'warning' as StatusTone },
    { label: 'MCP', tone: 'warning' as StatusTone },
    { label: 'LSP', tone: 'warning' as StatusTone },
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
    { label: 'Langfuse', tone: 'success' as StatusTone },
    { label: 'MCP', tone: 'success' as StatusTone },
    { label: 'LSP', tone: 'success' as StatusTone },
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
    { label: 'Langfuse', tone: 'success' as StatusTone },
    { label: 'MCP 1', tone: 'success' as StatusTone },
    { label: 'LSP 1', tone: 'info' as StatusTone },
  ]);
});

test('compactStatuses: mcp with numeric count', () => {
  const statuses = new Map([['mcp', 'MCP: 3']]);
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [
    { label: 'Langfuse', tone: 'muted' as StatusTone },
    { label: 'MCP 3', tone: 'success' as StatusTone },
    { label: 'LSP', tone: 'muted' as StatusTone },
  ]);
});

test('compactStatuses: lsp counts comma-separated names', () => {
  const statuses = new Map([['lsp', 'LSP Active: python, rust, go, javascript']]);
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [
    { label: 'Langfuse', tone: 'muted' as StatusTone },
    { label: 'MCP', tone: 'muted' as StatusTone },
    { label: 'LSP 4', tone: 'info' as StatusTone },
  ]);
});

test('compactStatuses: output order is always langfuse-mcp-lsp', () => {
  const statuses = new Map([
    ['lsp', 'LSP Active: xyz'],
    ['mcp', 'MCP: 1'],
    ['langfuse', 'Langfuse'],
  ]);
  const result = compactStatuses(statuses);
  strictEqual(result[0].label, 'Langfuse');
  strictEqual(result[1].label, 'MCP 1');
  strictEqual(result[2].label, 'LSP 1');
});

test('compactStatuses: pi-lens fallback when lsp absent', () => {
  const statuses = new Map([['pi-lens', 'LSP Active: rust, python']]);
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [
    { label: 'Langfuse', tone: 'muted' as StatusTone },
    { label: 'MCP', tone: 'muted' as StatusTone },
    { label: 'LSP 2', tone: 'info' as StatusTone },
  ]);
});

test('compactStatuses: lsp key takes precedence over pi-lens fallback', () => {
  const statuses = new Map([
    ['lsp', 'LSP Active: go'],
    ['pi-lens', 'LSP Active: python, rust'],
  ]);
  const result = compactStatuses(statuses);
  strictEqual(result[2].label, 'LSP 1');
  strictEqual(result[2].tone, 'info');
});

test('compactStatuses: case variations in pi-lens key', () => {
  const statuses = new Map([['Pi-Lens', 'LSP Active: typescript']])
;
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [
    { label: 'Langfuse', tone: 'muted' as StatusTone },
    { label: 'MCP', tone: 'muted' as StatusTone },
    { label: 'LSP 1', tone: 'info' as StatusTone },
  ]);
});

test('compactStatuses: LSP Active with whitespace yields no count', () => {
  const statuses = new Map([['lsp', 'LSP Active:   ']])
;
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [
    { label: 'Langfuse', tone: 'muted' as StatusTone },
    { label: 'MCP', tone: 'muted' as StatusTone },
    { label: 'LSP', tone: 'info' as StatusTone },
  ]);
});

test('compactStatuses: empty map emits muted for all services', () => {
  const statuses = new Map([]);
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [
    { label: 'Langfuse', tone: 'muted' as StatusTone },
    { label: 'MCP', tone: 'muted' as StatusTone },
    { label: 'LSP', tone: 'muted' as StatusTone },
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
