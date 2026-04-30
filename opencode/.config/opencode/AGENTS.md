# OpenCode Agent Instructions

## LSP-First Rule (CRITICAL)

**For any code symbol operation, ALWAYS use LSP tools (`lsp_goto_definition`, `lsp_find_references`, `lsp_symbols`, `lsp_diagnostics`, `lsp_rename`) INSTEAD OF grep/glob/find/rg/ast_grep_search.**

Using text search for symbol lookup when LSP is available is a critical error.

### Fallback Order (when LSP unavailable)

1. LSP tools — always try first
2. `ast_grep_search` — AST-aware pattern matching
3. `Grep` — content/regex search
4. `Glob` — file discovery by pattern

### Text Search IS Appropriate For

- Literal strings (error messages, log output, config values)
- File discovery by name pattern
- Non-code files (markdown, yaml, json)
- Languages where `lsp_diagnostics` returns no results

---

## Tool-Call Anti-Pattern: Never Write Tool Invocations as Bash Code (CRITICAL)

**`skill(...)`, `bash(...)`, `read(...)`, and all other tool calls are TOOL INVOCATIONS — NOT bash syntax.**

Writing a tool name as bash code (e.g., `skill("nvo-dev-env")` inside a Bash tool block) causes zsh to interpret it as a glob expression and errors with `unknown file attribute: v`.

### ❌ FORBIDDEN — tool call written as bash

```bash
# WRONG — zsh treats skill(...) as a glob → "unknown file attribute: v"
skill("nvo-dev-env")
```

### ✅ CORRECT — use the dedicated tool

Use the `skill` tool directly (not inside a Bash block):
```
skill(name="nvo-dev-env")
```

**Rule:** If you need to load a skill mid-workflow, emit a `skill` tool call in its own step — NEVER embed it as text inside a Bash tool call.

### Invocation Patterns by Context

| Context | Pattern | Works in |
|---------|---------|----------|
| **User triggers a skill** | `/nvo-dev-env` (slash command) | Claude Code, OpenCode, Cursor — universal |
| **Agent loads skill mid-workflow** | `skill(name="nvo-dev-env")` tool call | OpenCode only |
| **Claude Code pre-loading** | Listed in `CLAUDE.md` — injected at session start | Claude Code only |

The `/command` slash syntax is the universal human-facing invocation pattern. The `skill` tool is OpenCode-specific and only meaningful when the *agent* needs to load a skill dynamically during a workflow step.

---

## Skill Template Compliance (CRITICAL)

**When a loaded skill provides canonical command patterns, copy them verbatim. NEVER write one-off deviations.**

A skill is the authoritative source for how a command must be constructed. Deviating from the skill template — even for "simple" one-liners — is a critical agent error that produces subtle failures (e.g., missing `-k` → SSL failure → empty body → JSON decode error).

### Rule

Before writing ANY bash command that falls under a loaded skill's domain:

1. **Check the skill's templates first** — find the exact pattern in the skill's reference files
2. **Copy verbatim** — flags, options, pipes, and all
3. **Only substitute** the variable values (URLs, build numbers, job names)

### Examples

| Domain | Canonical Pattern (from skill) | Common Wrong Deviation |
|--------|-------------------------------|------------------------|
| Jenkins curl | `curl -sk --globoff -u "$CREDS" ...` | `curl -s -u "$CREDS" ...` (missing `-k --globoff`) |
| Jenkins JSON parse | `python3 -c "import sys,json; ..."` | `jq '.field'` (crashes on malformed responses) |
| NVO log access | Loki query via `nvo-loki-access` | `kubectl logs <pod>` (NVO doesn't write to stdout) |
| Jenkins nested job path | `/job/Folder/job/SubFolder/job/JobName/` | `/job/Folder/SubFolder/job/JobName/` (missing `/job/` separator) |

### Signal That You Are Deviating

If you find yourself writing a curl/bash command from memory rather than from a skill reference file — **stop, read the skill template, copy it**.

---

## GitHub CLI JSON Parse Pattern (CRITICAL)

**ALWAYS use the 4-guard pattern when parsing `gh` CLI output via Python. NEVER use bare `json.load(sys.stdin)`.**

The `gh` CLI writes errors to stderr AND stdout depending on context. If the repo is wrong, GH_HOST is missing, or auth fails, stdout is **empty** — causing `JSONDecodeError: Expecting value: line 1 column 1 (char 0)`.

### ❌ FORBIDDEN — bare json.load (crashes on empty output)

```bash
gh pr view 28704 --repo extremenetworks/GoDCApp --json title | python3 -c "
import sys,json
d=json.load(sys.stdin)   # ← CRASH if stdout empty
print(d['title'])
"
```

### ✅ CORRECT — 4-guard pattern

```bash
GH_HOST=github.extremenetworks.com gh pr view 28704 --repo Engineering/GoDCApp --json title,state,isDraft,reviewDecision,statusCheckRollup,reviews 2>&1 | python3 -c "
import sys,json
raw = sys.stdin.read().strip()
if not raw:
    print('ERROR: empty output from gh CLI — wrong repo, GH_HOST, or auth failure')
    sys.exit(1)
try:
    d = json.loads(raw)
except json.JSONDecodeError as e:
    print('ERROR: JSON parse failed:', e)
    print('Raw output:', raw[:500])
    sys.exit(1)
if not isinstance(d, dict):
    print('ERROR: unexpected type:', type(d), raw[:200])
    sys.exit(1)
print('Title:', d.get('title'))
print('State:', d.get('state'), '| Draft:', d.get('isDraft'))
for c in (d.get('statusCheckRollup') or []):
    name = c.get('name') or c.get('context', '?')
    state = c.get('state') or c.get('status', '?')
    conclusion = c.get('conclusion', '')
    print(f'  Check: {name} -> {state} {conclusion}')
"
```

### GitHub Enterprise Repo Rules

| Org | GH_HOST | Correct `--repo` |
|-----|---------|-----------------|
| GoDCApp | `github.extremenetworks.com` | `Engineering/GoDCApp` |
| PlatformCommonModels | `github.extremenetworks.com` | `Engineering/PlatformCommonModels` |
| EMU orgs | `github.com` | `extremenetworks-emu/<repo>` |

**Common mistake**: Using `extremenetworks/GoDCApp` (wrong org) or omitting `GH_HOST=github.extremenetworks.com` → stdout empty → JSONDecodeError.

---

## Skill Edit Validation (CRITICAL)

**After ANY edit to a skill file (`SKILL.md`, `references/*.md`, `scripts/*`), run `quick_validate.py` and a self-review checklist before considering the edit complete.**

Skill edits without post-edit validation silently degrade the skill ecosystem. A broken reference file has no runtime error — it only fails when an agent uses it in production.

### Mandatory Post-Edit Steps

After editing any file under a skill directory (`~/.config/opencode/skills/*/` or `~/.private_skills/*/`):

```bash
# 1. Structural validation (frontmatter, description, required fields)
python3 ~/.config/opencode/skills/skill-creator/scripts/quick_validate.py <skill_dir>

# 2. Self-review checklist (run mentally or as comments)
```

### Self-Review Checklist (every skill edit)

| # | Check | Why |
|---|-------|-----|
| 1 | No commented-out code inside code fences | Comments inside fences are not copy-pasteable — extract to a dedicated section |
| 2 | All code blocks are uncommented and copy-pasteable | Agents copy verbatim — commented code fails silently |
| 3 | Nullable fields use `(x or default)` not `x.get('k', default)` | `dict.get(k, default)` ignores default when key exists with `null` value |
| 4 | Every new pattern has a ❌/✅ comparison table | Makes the correct form unambiguous at a glance |
| 5 | New content is under a top-level `##` section | Buried documentation inside other sections is never found |
| 6 | No deviation from canonical curl flags: `-sk --globoff` | Missing `-k` → HTTP 000 silently; missing `--globoff` → empty response |
| 7 | JSON parsing uses 4-guard pattern (tr + empty check + try/except + isinstance) | Any fewer guards → crash on malformed Jenkins responses |
| 8 | Reference file still reads linearly top-to-bottom | New sections should not orphan existing context |

### Examples of Violations Caught by This Checklist

| Violation | Checklist Item | Correct Fix |
|-----------|---------------|-------------|
| Python fallback in `# comment` inside bash fence | #1, #2 | Extract to `## Python Alternative` section with clean code block |
| `pd.get('description', '')[:80]` on Jenkins JSON | #3 | `(pd.get('description') or '')[:80]` |
| New pattern described only in prose | #4 | Add ❌/✅ table |
| Guidance added inside an existing function block | #5 | Add top-level `## <Topic>` section |

---

## Learned Rules

_Auto-populated by the memory engine when observations are promoted to rule tier._
_Run `~/.private_agents_memory/memory-engine.sh export-rules` to update._

<!-- MEMORY_RULES_START -->
_No rules promoted yet. Rules require α ≥ 7, confidence ≥ 0.85, and age ≥ 14 days._
<!-- MEMORY_RULES_END -->
