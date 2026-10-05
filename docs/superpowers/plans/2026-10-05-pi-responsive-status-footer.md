# Pi Responsive Status Footer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore a responsive lower Pi footer with historical session metadata and compact Langfuse, MCP, and LSP health summaries.

**Architecture:** A presentation-only user extension in `pi/.pi/agent/extensions/statusline.ts` owns Pi’s custom footer. Pure parsing and layout helpers are kept in `pi/.pi/agent/extensions/statusline-format.ts`, allowing a Node test file to exercise health classification and width selection without loading a Pi interactive session. The extension receives Git branch and integration status text from Pi’s `ReadonlyFooterDataProvider`, aggregates branch usage, and computes all colorized segments at render time.

**Tech Stack:** Pi 1.0.3 extension API, `@earendil-works/pi-ai`, `@earendil-works/pi-coding-agent`, `@earendil-works/pi-tui`, Node.js built-in `node:test`, TypeScript via Pi’s bundled `jiti` runtime.

---

## File structure

- **Create:** `pi/.pi/agent/extensions/statusline-format.ts` — pure types and functions for format-safe usage, status classification, compact labels, visible-width layout selection, and repository labeling.
- **Create:** `pi/.pi/agent/extensions/statusline-format.test.ts` — focused Node tests for the pure helper contract.
- **Create:** `pi/.pi/agent/extensions/statusline.ts` — Pi lifecycle registration, `/statusline` toggle, session usage aggregation, and custom footer component.
- **Modify:** `pi/.pi/agent/.gitignore` — ignore `.superpowers/` visual-companion artifacts only if that location is not already ignored.

## Task 1: Lock down the pure compact-status and layout contract

**Files:**
- Create: `pi/.pi/agent/extensions/statusline-format.ts`
- Create: `pi/.pi/agent/extensions/statusline-format.test.ts`

- [ ] **Step 1: Write the failing tests for status classification and width fallback**

Create `pi/.pi/agent/extensions/statusline-format.test.ts`:

```ts
import assert from "node:assert/strict";
import test from "node:test";
import { chooseLayout, compactStatuses, shortenRepository } from "./statusline-format.ts";

test("compactStatuses summarizes known healthy integration strings", () => {
  const result = compactStatuses(
    new Map([
      ["langfuse", "✓ (trace sent)"],
      ["mcp", "📡 MCP: 2 servers enabled"],
      ["pi-lens", "LSP Active: bash, html, ast-grep, typos, opengrep"],
    ]),
  );

  assert.deepEqual(result, [
    { label: "Langfuse", tone: "success" },
    { label: "MCP 2", tone: "success" },
    { label: "LSP 5", tone: "info" },
  ]);
});

test("compactStatuses degrades absent and error integrations without claiming health", () => {
  const result = compactStatuses(new Map([["mcp", "error: connection refused"]]));

  assert.deepEqual(result, [
    { label: "Langfuse", tone: "muted" },
    { label: "MCP", tone: "error" },
    { label: "LSP", tone: "muted" },
  ]);
});

test("chooseLayout uses two rows when the joined footer exceeds available columns", () => {
  assert.equal(chooseLayout(100, 71, 38), "stacked");
  assert.equal(chooseLayout(120, 71, 38), "single");
});

test("shortenRepository retains the final repository path segments", () => {
  assert.equal(shortenRepository("badaniya/GoDCApp/NVO-13662", 20), "…/GoDCApp/NVO-13662");
});
```

- [ ] **Step 2: Run the tests to verify they fail because the formatter does not exist**

Run:

```bash
cd /home/badaniya/.stowed
node --import ./pi/.pi/agent/npm/node_modules/jiti/lib/jiti-register.mjs --test pi/.pi/agent/extensions/statusline-format.test.ts
```

Expected: test loading fails with `Cannot find module './statusline-format.ts'`.

- [ ] **Step 3: Implement the minimal pure formatter**

Create `pi/.pi/agent/extensions/statusline-format.ts` with these exact public types and functions:

```ts
export type StatusTone = "success" | "info" | "warning" | "error" | "muted";
export type CompactStatus = { label: string; tone: StatusTone };

export function compactStatuses(statuses: ReadonlyMap<string, string>): CompactStatus[];
export function chooseLayout(width: number, metadataWidth: number, healthWidth: number): "single" | "stacked";
export function shortenRepository(repository: string, maxWidth: number): string;
export function formatCount(value: number): string;
```

Implementation rules:

- Find source status strings case-insensitively by matching status-map keys and values for `langfuse`, `mcp`, and `lsp`/`pi-lens`.
- Treat `/error|fail|disconnected|refused/i` as `error`; `/warn|degraded|unknown/i` as `warning`; missing input as `muted`; `LSP Active:` as `info`; and `/trace sent|enabled|connected|active/i` as `success`.
- Extract `MCP: <n>` and count the comma-separated names after `LSP Active:`. Use no number when the input has no numeric/countable payload.
- Return statuses in fixed order Langfuse, MCP, LSP, so the footer does not reorder while updates arrive.
- Make `chooseLayout()` return `"single"` exactly when `metadataWidth + 3 + healthWidth <= width`; the 3 columns reserve the visible group gap.
- Make `shortenRepository()` return the original when it fits; otherwise preserve the last two slash-separated segments under a `…/` prefix, falling back to `…` plus a column-safe suffix.

- [ ] **Step 4: Run the formatter tests and verify they pass**

Run:

```bash
cd /home/badaniya/.stowed
node --import ./pi/.pi/agent/npm/node_modules/jiti/lib/jiti-register.mjs --test pi/.pi/agent/extensions/statusline-format.test.ts
```

Expected: four passing subtests and zero failures.

- [ ] **Step 5: Commit the formatter contract**

```bash
git add pi/.pi/agent/extensions/statusline-format.ts pi/.pi/agent/extensions/statusline-format.test.ts
git commit -m "pi: add statusline layout formatter"
```

## Task 2: Add the custom Pi footer and controlled toggle

**Files:**
- Create: `pi/.pi/agent/extensions/statusline.ts`
- Modify: `pi/.pi/agent/extensions/statusline-format.ts`
- Test: `pi/.pi/agent/extensions/statusline-format.test.ts`

- [ ] **Step 1: Add failing metadata-layout tests**

Append to `pi/.pi/agent/extensions/statusline-format.test.ts`:

```ts
import { formatMetadata } from "./statusline-format.ts";

test("formatMetadata renders token counts, cost, effort, and repository in the historical order", () => {
  assert.deepEqual(
    formatMetadata({
      model: "claude-sonnet-5.5",
      inputTokens: 38,
      outputTokens: 11_200,
      cost: 1.28,
      effort: "minimal",
      repository: "badaniya/GoDCApp/NVO-13662",
    }),
    ["claude-sonnet-5.5", "38/11.2k", "$1.28", "minimal", "badaniya/GoDCApp/NVO-13662"],
  );
});
```

- [ ] **Step 2: Run the targeted test to verify it fails**

Run:

```bash
cd /home/badaniya/.stowed
node --import ./pi/.pi/agent/npm/node_modules/jiti/lib/jiti-register.mjs --test --test-name-pattern="formatMetadata" pi/.pi/agent/extensions/statusline-format.test.ts
```

Expected: failure reporting that `formatMetadata` is not exported.

- [ ] **Step 3: Add `formatMetadata` and create the extension**

Extend `pi/.pi/agent/extensions/statusline-format.ts` with:

```ts
export type MetadataInput = {
  model: string;
  inputTokens: number;
  outputTokens: number;
  cost: number;
  effort: string;
  repository: string;
};

export function formatMetadata(input: MetadataInput): [string, string, string, string, string];
```

It must use `formatCount()` for token values and return the exact field order asserted by the test.

Create `pi/.pi/agent/extensions/statusline.ts` that:

1. imports `AssistantMessage` from `@earendil-works/pi-ai`, `ExtensionAPI` from `@earendil-works/pi-coding-agent`, `truncateToWidth` and `visibleWidth` from `@earendil-works/pi-tui`, and the helpers from `./statusline-format.ts`;
2. exposes `export default function (pi: ExtensionAPI): void`;
3. registers `/statusline`, which toggles the custom footer with `ctx.ui.setFooter(undefined)` when off and reinstalls the factory when on;
4. installs the footer at `session_start` (when `ctx.hasUI` is true) and reinstalls it after `model_select` and `session_switch`;
5. registers the footer using `ctx.ui.setFooter((tui, theme, footerData) => ...)`, subscribes to `footerData.onBranchChange(() => tui.requestRender())`, and returns a component with `dispose`, `invalidate`, and `render(width)`;
6. aggregates `input`, `output`, and `cost.total` from every assistant message in `ctx.sessionManager.getBranch()`;
7. reads `ctx.model?.id`, `ctx.thinkingLevel ?? "minimal"`, `footerData.getGitBranch()`, `footerData.getExtensionStatuses()`, and `ctx.cwd` without performing filesystem, network, MCP, Langfuse, or LSP calls;
8. generates styled segments only inside `render()` with `theme.fg("accent", ...)`, `theme.fg("muted", ...)`, `theme.fg("success", ...)`, `theme.fg("warning", ...)`, and `theme.fg("error", ...)`; and
9. selects a one-row or two-row layout through `chooseLayout()`, then uses `truncateToWidth()` on every returned line.

Rendering requirements:

- Model and repository are accent-colored; token counts use a lavender-compatible accent token available in the current Pi theme; cost is warning-colored; effort and healthy statuses are success-colored; informational LSP is accent-colored; separators and unknowns are muted.
- One row has metadata on the left and health status right-aligned with `" │ "` separators.
- Two rows put model/tokens/cost/effort on row one and repository/status health on row two.
- `render()` returns no more than two lines and never returns a line whose `visibleWidth()` exceeds `width`.
- Any missing state produces safe labels such as `no-model`, `unknown repo`, `Langfuse`, `MCP`, or `LSP`; the component must not throw.

- [ ] **Step 4: Run all formatter tests and extension diagnostics**

Run:

```bash
cd /home/badaniya/.stowed
node --import ./pi/.pi/agent/npm/node_modules/jiti/lib/jiti-register.mjs --test pi/.pi/agent/extensions/statusline-format.test.ts
```

Expected: five passing subtests and zero failures.

Then run proactive diagnostics for the two new TypeScript files through Pi Lens:

```text
lens_diagnostics(source="lsp", scope="paths", mode="full", paths=["pi/.pi/agent/extensions/statusline.ts", "pi/.pi/agent/extensions/statusline-format.ts"], serverScope="all", severity="warning")
```

Expected: no error diagnostics. Resolve any type/API incompatibility before committing.

- [ ] **Step 5: Manually verify Pi rendering and interaction**

1. Start a fresh interactive Pi session from `/home/badaniya/.stowed`.
2. Verify the existing `@eiei114/pi-sub-bar` provider/context/quota bar remains above the footer.
3. In a wide terminal, confirm one metadata/health row, correct colors, and right-aligned `Langfuse`, `MCP`, and `LSP` compact labels.
4. Split the terminal vertically or resize to approximately 100 columns; confirm the footer uses two readable lines without dropping health labels or overflowing.
5. Run `/statusline` twice; confirm first invocation restores Pi’s standard footer and second reinstates the custom footer.
6. Change models with `/model`; confirm the footer updates the model label.
7. Confirm a missing or error integration status is muted/yellow/red and never rendered as green.

- [ ] **Step 6: Commit the extension**

```bash
git add pi/.pi/agent/extensions/statusline.ts pi/.pi/agent/extensions/statusline-format.ts pi/.pi/agent/extensions/statusline-format.test.ts
git commit -m "pi: restore responsive status footer"
```

## Task 3: Keep visual-companion artifacts out of dotfiles commits

**Files:**
- Modify: `pi/.pi/agent/.gitignore`

- [ ] **Step 1: Check whether `.superpowers/` is already ignored**

Run:

```bash
cd /home/badaniya/.stowed
git check-ignore -v .superpowers/brainstorm/3495902-1791228917/content/half-width-feasibility.html || true
```

Expected: if no ignore rule is reported, the visual companion artifacts are untracked and need an explicit ignore rule.

- [ ] **Step 2: Add the narrow ignore rule only if required**

Append this exact line to `pi/.pi/agent/.gitignore` only if the prior command reported no matching ignore rule:

```gitignore
# Local visual-companion artifacts
.superpowers/
```

If `.superpowers/` belongs at repository root instead, add the same two lines to the root `.gitignore` instead; do not add duplicate rules.

- [ ] **Step 3: Verify the rule and the final diff**

Run:

```bash
cd /home/badaniya/.stowed
git check-ignore -v .superpowers/brainstorm/3495902-1791228917/content/half-width-feasibility.html
git diff --check
git status --short
```

Expected: the companion artifact is ignored, `git diff --check` has no output, and only intentional footer files are staged/committed.

- [ ] **Step 4: Commit the ignore rule if it was added**

```bash
git add .gitignore pi/.pi/agent/.gitignore
git commit -m "pi: ignore local visual companion artifacts"
```

If no rule was necessary, do not create an empty commit.

## Final verification

- [ ] **Step 1: Review the completed implementation against the approved spec**

Check each requirement in `docs/superpowers/specs/2026-10-05-pi-responsive-status-footer-design.md` against `pi/.pi/agent/extensions/statusline.ts` and the manual rendering checks. Confirm the upper subscription bar was not changed and that all three integrations have truthful compact fallbacks.

- [ ] **Step 2: Confirm repository cleanliness without touching unrelated user changes**

Run:

```bash
cd /home/badaniya/.stowed
git status --short
git log --oneline -3
```

Expected: status may still show the pre-existing `pi/.pi/agent/models-store.json` modification; do not stage, edit, revert, or commit it as part of this work.
