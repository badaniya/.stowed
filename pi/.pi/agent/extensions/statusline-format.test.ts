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

test('compactStatuses: malformed/unrecognized values map to muted tone', () => {
  const statuses = new Map([
    ['langfuse', ''],
    ['mcp', 'unknown entry'],
    ['lsp', 'does not match'],
  ]);
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [
    { label: 'Langfuse', tone: 'muted' as StatusTone },
    { label: 'MCP', tone: 'muted' as StatusTone },
    { label: 'LSP', tone: 'muted' as StatusTone },
  ]);
});

test('compactStatuses: case-insensitive matching', () => {
  const statuses = new Map([
    ['langfuse', 'LANGFUSE ENABLED'],
    ['mcp', 'MCP: 1'],
    ['lsp', 'LSP ACTIVE: plugin1'],
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
  deepStrictEqual(result, [{ label: 'MCP 3', tone: 'success' as StatusTone }]);
});

test('compactStatuses: lsp counting comma-separated names', () => {
  const statuses = new Map([['lsp', 'LSP Active: python, rust, go, javascript']]);
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [{ label: 'LSP 4', tone: 'info' as StatusTone }]);
});

test('compactStatuses: bare keyword patterns (no key name) not recognized', () => {
  const statuses = new Map([
    ['langfuse', 'connected'],
    ['mcp', 'active'],
  ]);
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [
    { label: 'Langfuse', tone: 'muted' as StatusTone },
    { label: 'MCP', tone: 'muted' as StatusTone },
  ]);
});

test('compactStatuses: service-name-prefixed success patterns', () => {
  const statuses = new Map([
    ['langfuse', 'Langfuse connected'],
    ['mcp', 'MCP active'],
  ]);
  const result = compactStatuses(statuses);
  deepStrictEqual(result, [
    { label: 'Langfuse', tone: 'success' as StatusTone },
    { label: 'MCP', tone: 'success' as StatusTone },
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
  strictEqual(result, '…/GoDCApp/NVO-13662');
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
