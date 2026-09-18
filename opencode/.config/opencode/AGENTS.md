# OpenCode Agent Instructions

## Tool-Call Anti-Pattern (CRITICAL)

**Tool calls (`skill(...)`, `bash(...)`, `read(...)`, etc.) are TOOL INVOCATIONS — NOT bash syntax.** Writing `skill("nvo-dev-env")` inside a Bash block causes zsh to treat it as a glob → `unknown file attribute: v`. Always emit a `skill` tool call in its own step.

---

## Skill Template Compliance (CRITICAL)

**When a loaded skill provides canonical command patterns, copy them verbatim.** Deviating — even on "simple" one-liners — causes subtle failures (missing `-k` → SSL failure; missing `--globoff` → empty response).

Before writing ANY bash command under a loaded skill's domain: (1) find the exact pattern in the skill's reference files, (2) copy verbatim, (3) substitute only variable values.

| Domain | Canonical Pattern | Wrong Deviation |
|--------|-------------------|-----------------|
| Jenkins curl | `curl -sk --globoff -u "$CREDS" ...` | `curl -s -u "$CREDS" ...` |
| Jenkins JSON | `python3 -c "import sys,json; ..."` | `jq '.field'` (crashes on malformed) |
| NVO log access | Loki query via `nvo-loki-access` | `kubectl logs <pod>` (NVO → `/data/log/`) |
| Jenkins job path | `/job/Folder/job/Sub/job/Name/` | `/job/Folder/Sub/job/Name/` (missing `/job/`) |
| PR body | `gh pr view 123 --json body --jq '.body'` | `json.loads` (crashes on code blocks) |

If writing a command from memory rather than a skill reference — **stop, read the skill, copy it**.

---

## GitHub CLI JSON Parse Pattern (CRITICAL)

**ALWAYS use the 4-guard pattern. NEVER use bare `json.load(sys.stdin)`** — `gh` writes errors to stdout on bad repo/auth, causing `JSONDecodeError: Expecting value`.

4-guard pattern: check for empty output → `tr` strip → `try/except` JSON parse → `isinstance` check. Full pattern: `$HOME/.agents/agents/references/gh-cli-patterns.md` → `## GitHub CLI 4-Guard Pattern`.

| Org | GH_HOST | `--repo` |
|-----|---------|----------|
| GoDCApp | `github.extremenetworks.com` | `Engineering/GoDCApp` |
| PlatformCommonModels | `github.extremenetworks.com` | `Engineering/PlatformCommonModels` |
| EMU orgs | `github.com` | `extremenetworks-emu/<repo>` |

**Common mistake**: `extremenetworks/GoDCApp` (wrong org) → stdout empty → JSONDecodeError.

---

## Skill Edit Validation (CRITICAL)

**After ANY edit to a skill file, run `quick_validate.py` and the self-review checklist.**

```bash
python3 $HOME/.agents/skills/skill-creator/scripts/quick_validate.py <skill_dir>
```

Self-review: no commented-out code in fences; all code blocks copy-pasteable; nullable fields use `(x or default)` not `x.get(k, default)`; every new pattern has ❌/✅ table; new content under top-level `##`; curl flags `-sk --globoff`; JSON uses 4-guard pattern; reference file reads linearly.

---

## Learned Rules

_Auto-populated by the memory engine when observations are promoted to rule tier._
_Run `$HOME/.private_agents_memory/memory-engine.sh export-rules` to update._

<!-- MEMORY_RULES_START -->
_No rules promoted yet. Rules require α ≥ 7, confidence ≥ 0.85, and age ≥ 14 days._
<!-- MEMORY_RULES_END -->

<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->

<!-- codebase-memory-mcp:start -->
# Codebase Memory

## Codebase Knowledge Graph (codebase-memory-mcp)

This project uses codebase-memory-mcp to maintain a knowledge graph of the codebase.
ALWAYS prefer MCP graph tools over grep/glob/file-search for code discovery.

### Priority Order
1. `search_graph` — find functions, classes, routes, variables by pattern
2. `trace_path` — trace who calls a function or what it calls
3. `get_code_snippet` — read specific function/class source code
4. `check_index_coverage` — validate candidate paths and missed ranges before claims
5. `query_graph` — run Cypher queries for complex patterns
6. `get_architecture` — high-level project summary

### Evidence tiers
- **Scout (Tier 1):** quick positive lookup with few calls and targeted source checks. Mark it provisional; do not make negative or exhaustive claims.
- **Verify (Tier 2, default):** task-directed graph evidence, relevant trace directions, exact snippets for material claims, and relevant pagination.
- **Auditor (Tier 3):** bounded-scope full verification with current generation, complete relevant pagination, both call directions and broader relationships when material, and every limitation disclosed.
- After candidate paths are known in any tier, call `check_index_coverage` once with every evidence path. Add relevant scopes for negative or exhaustive claims. A clean result means no recorded gap, not proof of completeness. For partial, skipped, excluded, stale, pending, or unknown coverage, read/grep the reported ranges or scope before relying on graph results.

### When to fall back to grep/glob
- Searching for string literals, error messages, config values
- Searching non-code files (Dockerfiles, shell scripts, configs)
- When MCP tools return insufficient results

### Examples
- Find a handler: `search_graph(name_pattern=".*OrderHandler.*")`
- Who calls it: `trace_path(function_name="OrderHandler", direction="inbound")`
- Read source: `get_code_snippet(qualified_name="pkg/orders.OrderHandler")`

### Session resets and subagents
- At session start or after compaction, confirm the nearest graph project and generation with `list_projects` or `index_status`, then choose Scout, Verify, or Auditor.
- Before spawning a subagent, query the graph and coverage in the parent. Pass the tier, project, generation/freshness, bounded scope, queries and pagination state, qualified symbols, paths, call-chain findings, coverage evidence with ranges/reasons, source fallback already performed, and unresolved questions in the delegated task context.
- Do not assume subagents inherit MCP access or the parent conversation. If a child lacks MCP tools, it must not call or claim MCP access. It should use the supplied evidence and read/grep exact source, especially every reported missed-coverage range.
<!-- codebase-memory-mcp:end -->
