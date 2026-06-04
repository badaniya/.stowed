---
description: Self reflection with skills optimization
agent: nvo-developer
model: github-copilot/claude-sonnet-4.6
---

Run a self-reflection on this session:

# DO'S
- Evaluate the session and optimize all skills utilized using the skill-creator, context-engineering-collection, tokenscope skills.
- **GAP ANALYSIS (mandatory before any sub-agent dispatch):** Before dispatching any sub-agent, the parent session MUST: (1) read ALL modified skill files in full, and (2) produce a gap table with columns: skill | file | issue | proposed fix. Sub-agents MUST only be dispatched AFTER the gap table is complete. SECTION 3 mutations must be derived directly from the gap table — not guessed or approximated.
- Use a sub-agent, one per skill that needs to be refactored and optimized. Ensure that sub-agent triggering instruction is generic for any agent harness to understand.
- Ensure that the skills are RELIABLE (skill triggering, referencing resources/examples, and scripts execution MUST be followed).
- Optimize by reducing the number of tool calls by the agent and sub-agents. This takes PRIORITY over token optimizations.
- Any interruptions and course corrections by the user for skill/workflow corrections MUST be incorporated back into the skill.
- Validate the skill is within specification and refactor accordingly, BUT correct triggering and progressive disclosure MUST be maintained.
- Ensure skill compliance with standards with the extra restriction that SKILLS.md should be under 200 lines.
- Ensure skill compliance with the skill description being under 1024 chars.
- If a reference file exceeds 200 lines, SPLIT the overflow into a new reference file; then (1) add a pointer line at the bottom of the original reference file pointing to the new file, and (2) update the SKILL.md dispatch table (the `## Reference Files` section) to include the new file name — NEVER delete domain knowledge to hit the line limit. The 200-line ceiling is a SPLIT trigger, not a deletion trigger.
- Ensure nvo private skills true source dir is under $HOME/.private_skills/, $HOME/.agents/skills/ dir symlinks to these nvo private skills source, and the agent harness tool symlinks the $HOME/.agent/skills dir for skills access.
- **Skill directory layout (ENFORCE during gap analysis):** Each skill MUST follow this structure:
  - `scripts/` — all executable scripts (`.sh`, `.py`). NEVER place scripts in the skill root or in `references/`.
  - `assets/` — all static data files read by scripts at runtime (`.yaml`, `.yml`, `.json`, `.toml`, `.csv`, example templates). NEVER place these in `scripts/` (unless runtime-generated cache), the skill root, or `references/`.
  - `references/` — markdown documentation only (`.md` files loaded as skill knowledge).
  - `evals/` — trigger accuracy test cases (eval JSON files).
  - During gap analysis, flag any `.sh`/`.py` found outside `scripts/` and any static config/data files found outside `assets/` as layout violations. Move them and update all path references in SKILL.md and reference files.
- Snapshot each skill before editing: `cp -r <skill-path> $HOME/.agents/skill-snapshots/<skill-name>/`
  (NEVER snapshot into $HOME/.agents/skills/ — the `**/SKILL.md` glob loads it as a duplicate)
- Source nvo-config-resolver.sh via `bash -c '...'` (bash-only syntax — not zsh-compatible).
- Update the metadata skill version for any changes. Major refactoring or restructuring of the skill warrants a Major version increment plus resetting the Minor version to 0, smaller changes warrant a Minor version increment. Major is greater than or equal to 500 lines, Minor is less than 500 lines.
- After ALL optimizations are complete, backup the entire `$HOME/.private_skills/` directory as a .tgz file: `tar -czf $HOME/private_skills_backup_$(date +%Y%m%d_%H%M%S).tgz $HOME/.private_skills/` — verify the result is ≥ 1MB (a small file means symlinks weren't followed or the wrong path was used)
- If a sub-agent fails 2 or more times (including after RESUME attempts), fall back to direct edits in the parent session using Edit/Write tools — this fallback is NOT a failure, it achieves the same result.

# DONT'S
- Hard-code credentials in the skills. ONLY use the skill config ENV variables or generic labels and terms if no ENV exist.
- Hard-code the credentials file name. ONLY use the skill config ENV variable for the credentials file.
- Remove the bootstrap nvo credentials section in the skill if exists.
- Delete domain knowledge, working commands, or reference content to meet line limits. Line limits are SPLIT triggers — if content doesn't fit, move it to a new reference file and add a pointer. Deletion is NEVER acceptable.
- Leave dangling reference files. Attempt to recover from the opencode sqlite session db.
- Run evals. ONLY do a skill optimization unless specifically prompted to run a eval.
- Restart a delegated agent session — always RESUME by session_id.
- Place scripts (`.sh`, `.py`) anywhere except `scripts/`. Not in root, not in `references/`.
- Place static data files (`.yaml`, `.json`, example templates) anywhere except `assets/`. Not in `scripts/` (unless runtime-generated), not in root, not in `references/`.

---

## SUB-AGENT PROMPT REQUIREMENTS

When constructing a prompt for any sub-agent (hephaestus, explore, librarian, or other),
your prompt MUST contain ALL FIVE of the following sections. A prompt missing any section
WILL produce zero output or silent errors.

### SECTION 1 — FILES (MANDATORY)

List every file the sub-agent must read and/or write, with absolute paths:

```
Files to READ (before any write):
  - /absolute/path/to/skill-name/SKILL.md
  - /absolute/path/to/skill-name/references/<ref>.md

Files to WRITE:
  - /absolute/path/to/skill-name/SKILL.md              (max 200 lines)
  - /absolute/path/to/skill-name/references/<ref>.md   (max 200 lines)
```

Never omit absolute paths. The sub-agent cannot discover files on its own.

### SECTION 2 — READ-BEFORE-WRITE GATE (MANDATORY)

The sub-agent MUST read every target file in full before writing any changes.

```
GATE: Read each target file completely using the Read tool before any Edit or Write.
If a Read call fails or returns empty, STOP and report the error. Do NOT write from memory.
```

### SECTION 3 — EXACT MUTATIONS (MANDATORY)

Specify every change as a precise before/after pair or explicit instruction:

```
Mutations to apply:
  1. In SKILL.md — replace the description block (lines X–Y) with:
       <exact replacement text>
  2. In references/api-operations.md — add the following section after "## Authentication":
       <exact new section text>
  3. Remove lines Z–W from SKILL.md (the deprecated troubleshooting block)
```

Never say "improve", "clean up", or "refactor" without specifying the exact change.

### SECTION 4 — INLINE CONSTRAINTS (MANDATORY)

Repeat the relevant constraints directly in the sub-agent prompt — sub-agents cannot
see parent-session DO's/DON'Ts:

```
Constraints (enforce these — the parent session's rules are NOT visible to you):
  - SKILL.md MUST be ≤ 200 lines after changes
  - Reference files: if over 200 lines, SPLIT overflow into a NEW reference file and add a pointer
    from the original — NEVER delete domain knowledge, commands, or examples to meet the limit
  - Scripts have NO line limit
  - DO NOT hard-code credentials — use ENV variable labels only
  - DO NOT hard-code $NVO_CREDENTIAL_FILE — use the variable, not a literal path
  - DO NOT add emojis unless explicitly instructed
  - Triggering keywords and progressive disclosure MUST be preserved
  - Source nvo-config-resolver.sh via bash -c (bash-only syntax, not zsh-compatible)
  - Skill directory layout MUST be enforced:
      scripts/    → executable .sh/.py files ONLY (no data/config files)
      assets/     → static data files read by scripts (.yaml, .json, .toml, example templates)
      references/ → .md documentation files ONLY
      evals/      → eval JSON files ONLY
    If any script is found outside scripts/, move it and update all path references.
    If any static data file is found outside assets/, move it and update all path references.
```

### SECTION 5 — POST-WRITE VERIFICATION (MANDATORY)

After every write, the sub-agent MUST verify the result:

```
After each write, verify:
  1. Read the file back and count lines — confirm ≤ 200 (for SKILL.md and references)
  2. Confirm the triggering keywords from the original description are still present
  3. Confirm no hardcoded credentials or paths were introduced
  4. If line count EXCEEDS 200, do NOT proceed — report the overage and stop
  5. Report the final line count for each file written
  6. Run: python3 .agents/skills/skill-creator/scripts/quick_validate.py <skill_dir>
     If quick_validate.py reports errors, STOP and fix before continuing
```

---

## Example: Correct Sub-Agent Prompt (all 5 sections)

> Refactor the `nvo-jira-access` skill.
>
> **SECTION 1 — FILES**
> Read:  `$HOME/.private_skills/nvo-jira-access/SKILL.md`
> Read:  `$HOME/.private_skills/nvo-jira-access/references/api-operations.md`
> Write: `$HOME/.private_skills/nvo-jira-access/SKILL.md` (max 200 lines)
>
> **SECTION 2 — READ-BEFORE-WRITE GATE**
> Read both files completely before any edits. Stop and report if Read fails.
>
> **SECTION 3 — EXACT MUTATIONS**
> 1. In SKILL.md, replace the "Triggers:" line (currently line 14) with:
>    `Triggers: "jira", "jira issue", "jira ticket", "JQL", "create ticket", "update issue", "NVO-", "link to jira"`
> 2. In references/api-operations.md, remove the "Legacy v1 endpoints" section (lines 88–101).
>
> **SECTION 4 — INLINE CONSTRAINTS**
> SKILL.md ≤ 200 lines. No hardcoded credentials. No hardcoded file paths. Preserve all trigger keywords.
>
> **SECTION 5 — POST-WRITE VERIFICATION**
> After each write: read file back, count lines, confirm triggers preserved, report final line count.

---

## Example: Splitting an Oversized Reference File

> Split the oversized `operations.md` reference file in the `nvo-example` skill.
>
> **SECTION 1 — FILES**
> Read:  `$HOME/.private_skills/nvo-example/SKILL.md`
> Read:  `$HOME/.private_skills/nvo-example/references/operations.md`  (currently 280 lines — exceeds 200-line limit)
> Write: `$HOME/.private_skills/nvo-example/references/operations.md`          (trimmed to ≤ 200 lines, pointer added at bottom)
> Write: `$HOME/.private_skills/nvo-example/references/operations-advanced.md` (new file — receives overflow lines 201–280)
> Write: `$HOME/.private_skills/nvo-example/SKILL.md`                          (dispatch table updated to include new file)
>
> **SECTION 2 — READ-BEFORE-WRITE GATE**
> Read all three target files completely before any edits. If any Read fails or returns empty, STOP and report the error. Do NOT write from memory.
>
> **SECTION 3 — EXACT MUTATIONS**
> 1. In `references/operations.md` — remove lines 201–280 (the overflow content) and append the
>    following pointer line at the very bottom of the file:
>    `> ➡ Continued in: references/operations-advanced.md`
> 2. Create `references/operations-advanced.md` as a new file containing exactly the overflow
>    content (original lines 201–280 of `operations.md`), preceded by this header:
>    ```
>    # Operations (Advanced)
>    <!-- Overflow split from operations.md — do NOT delete; update both files together -->
>    ```
> 3. In `SKILL.md` — locate the dispatch table (the block that lists reference file names) and
>    add `references/operations-advanced.md` as a new entry immediately after the existing
>    `references/operations.md` entry.
>
> **SECTION 4 — INLINE CONSTRAINTS**
> SKILL.md ≤ 200 lines. Each reference file ≤ 200 lines after the split. NEVER delete domain
> knowledge, working commands, or examples to meet line limits — the 200-line ceiling is a SPLIT
> trigger, not a deletion trigger. No hardcoded credentials or literal file paths. Do NOT add
> emojis unless explicitly instructed. Preserve all trigger keywords and progressive disclosure.
>
> **SECTION 5 — POST-WRITE VERIFICATION**
> After each write:
> 1. Read the file back and count lines — confirm `operations.md` ≤ 200 lines,
>    `operations-advanced.md` ≤ 200 lines, and `SKILL.md` ≤ 200 lines.
> 2. Confirm the pointer line (`➡ Continued in: references/operations-advanced.md`) is present
>    at the bottom of `operations.md`.
> 3. Run `python3 quick_validate.py --skill nvo-example` to confirm the skill passes structural
>    validation (dispatch table entries, line counts, no dangling references).
> 4. If any file still exceeds 200 lines, do NOT proceed — report the overage and stop.
> 5. Report the final line count for each of the three files written.
