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

test('compactStatuses: spec example 1 - trace sent, mcp with emoji, pi-lens with multiple names', () => {
  const statuses = new Map([
    ['langfuse', '✓ (trace sent)'],
    ['mcp', '📡 MCP: 2 servers enabled'],
    ['pi-lens', 'LSP Active: bash, html, ast-grep, typos, opengrep'],
  ]);
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [
    { label: 'Langfuse', tone: 'success' as StatusTone },
    { label: 'MCP 2', tone: 'success' as StatusTone },
    { label: 'LSP 5', tone: 'info' as StatusTone },
  ]);
});

test('compactStatuses: always 3 entries, mcp only with error', () => {
  const statuses = new Map([['mcp', 'error: connection refused']]);
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [
    { label: 'Langfuse', tone: 'muted' as StatusTone },
    { label: 'MCP', tone: 'error' as StatusTone },
    { label: 'LSP', tone: 'muted' as StatusTone },
  ]);
});

test('compactStatuses: error strings map to error tone', () => {
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

test('compactStatuses: warning strings map to warning tone', () => {
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

test('compactStatuses: values without service mention are classified by pattern only', () => {
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

test('compactStatuses: case-insensitive matching', () => {
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

test('compactStatuses: mcp extraction', () => {
  const statuses = new Map([['mcp', 'MCP: 3']]);
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [
    { label: 'Langfuse', tone: 'muted' as StatusTone },
    { label: 'MCP 3', tone: 'success' as StatusTone },
    { label: 'LSP', tone: 'muted' as StatusTone },
  ]);
});

test('compactStatuses: lsp counting comma-separated names', () => {
  const statuses = new Map([['lsp', 'LSP Active: python, rust, go, javascript']]);
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [
    { label: 'Langfuse', tone: 'muted' as StatusTone },
    { label: 'MCP', tone: 'muted' as StatusTone },
    { label: 'LSP 4', tone: 'info' as StatusTone },
  ]);
});

test('compactStatuses: stable order is langfuse, mcp, lsp', () => {
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

test('compactStatuses: lsp takes precedence over pi-lens', () => {
  const statuses = new Map([
    ['lsp', 'LSP Active: go'],
    ['pi-lens', 'LSP Active: python, rust'],
  ]);
  const result = compactStatuses(statuses);
  strictEqual(result[2].label, 'LSP 1');
});

test('compactStatuses: capitalized pi-lens key', () => {
  const statuses = new Map([['Pi-Lens', 'LSP Active: typescript']]);
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [
    { label: 'Langfuse', tone: 'muted' as StatusTone },
    { label: 'MCP', tone: 'muted' as StatusTone },
    { label: 'LSP 1', tone: 'info' as StatusTone },
  ]);
});

test('chooseLayout: single when metadata + 3 + health <= width', () => {
  const layout = chooseLayout(120, 71, 38);
  strictEqual(layout, 'single');
});

test('chooseLayout: stacked when metadata + 3 + health > width', () => {
  const layout = chooseLayout(100, 71, 38);
  strictEqual(layout, 'stacked');
});

test('chooseLayout: boundary single at exact fit', () => {
  const layout = chooseLayout(112, 71, 38);
  strictEqual(layout, 'single');
});

test('chooseLayout: boundary stacked just over fit', () => {
  const layout = chooseLayout(111, 71, 38);
  strictEqual(layout, 'stacked');
});

test('shortenRepository: returns original when it fits', () => {
  const result = shortenRepository('user/repo', 20);
  strictEqual(result, 'user/repo');
});

test('shortenRepository: shortens to …/last/two/segments at width 20', () => {
  const result = shortenRepository('badaniya/GoDCApp/NVO-13662', 20);
  const expected = '…/GoDCApp/NVO-13662';
  strictEqual(result, expected);
});

test('shortenRepository: fallback to … with safe suffix when necessary', () => {
  const result = shortenRepository('a/b/c/d/e/f', 5);
  strictEqual(result.startsWith('…'), true);
  strictEqual(result.length <= 5, true);
});

test('shortenRepository: handles single segment', () => {
  const result = shortenRepository('verylongsinglesegment', 10);
  strictEqual(result.length <= 10, true);
});

test('shortenRepository: emoji safety (no lone surrogates)', () => {
  const result = shortenRepository('a/b/c/d/😀x', 3);
  // Must be code-point safe: no lone surrogates
  strictEqual(result.length > 0, true);
  // Check that it doesn't have lone surrogates
  for (let i = 0; i < result.length; i++) {
    const code = result.charCodeAt(i);
    // High surrogate without low surrogate is bad
    if (code >= 0xd800 && code <= 0xdbff) {
      const next = result.charCodeAt(i + 1);
      strictEqual(next >= 0xdc00 && next <= 0xdfff, true, 'high surrogate must be followed by low surrogate');
    }
  }
});

test('shortenRepository: emoji in fallback suffix', () => {
  // Verify output is valid UTF-16 string
  const result = shortenRepository('🎉/emoji/test/path', 10);
  strictEqual(typeof result, 'string');
  // Can be converted to array of code points without errors
  const codePoints = Array.from(result);
  strictEqual(codePoints.length > 0, true);
});

test('formatCount: zero', () => {
  strictEqual(formatCount(0), '0');
});

test('formatCount: formats positive integers', () => {
  strictEqual(formatCount(5), '5');
  strictEqual(formatCount(42), '42');
});

test('formatCount: formats large numbers with K suffix', () => {
  strictEqual(formatCount(1000), '1K');
  strictEqual(formatCount(1500), '1.5K');
});

test('formatCount: formats mega numbers with M suffix', () => {
  strictEqual(formatCount(1000000), '1M');
  strictEqual(formatCount(2500000), '2.5M');
});
