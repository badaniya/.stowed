---
description: Self reflection with skills optimization
agent: nvo-developer
model: github-copilot/claude-opus-4.6
---

Run a self-reflection on this session:

# DO'S
- Evaluate the session and optimize all skills utilized using the skill-creator, tokenscope skills.
- Use a sub-agent, one per skill that needs to be refactored and optimized. Ensure that sub-agent triggering instruction is generic for any agent harness to understand.
- Ensure that the skills are RELIABLE (skill triggering, referencing resources/examples, and scripts execution MUST be followed).
- Optimize by reducing the number of tool calls by the agent and sub-agents. This takes PRIORITY over token optimizations.
- Any interruptions and course corrections by the user for skill/workflow corrections MUST be incorporated back into the skill.
- Validate the skill is within specification and refactor accordingly, BUT correct triggering and progressive disclosure MUST be maintained.
- Ensure skill compliance with standards with the extra restriction that SKILLS.md should be under 200 lines.
- Ensure skill compliance with the skill description being under 1024 chars.
- Limit skill references to 200 lines as well and refactor to preserve domain knowledge.
- Snapshot each skill before editing: `cp -r <skill-path> ~/.agents/skill-snapshots/<skill-name>/`
  (NEVER snapshot into ~/.config/opencode/skills/ — the `**/SKILL.md` glob loads it as a duplicate)
- Source nvo-config-resolver.sh via `bash -c '...'` (bash-only syntax — not zsh-compatible).
- Update the metadata skill version for any changes. Major refactoring or restructuring of the skill warrants a Major version increment plus resetting the Minor version to 0, smaller changes warrant a Minor version increment. Major is greater than or equal to 500 lines, Minor is less than 500 lines.
- After ALL optimizations are complete, backup the entire ~/.private_skills/* directory as a .tgz file and save the file as ~/.private_skills_backup_<datetimestamp>.tgz

# DONT'S
- Hard-code credentials in the skills. ONLY use the skill config ENV variables or generic labels and terms if no ENV exist.
- Hard-code the credentials file name. ONLY use the skill config ENV variable for the credentials file.
- Remove the bootstrap nvo credentials section in the skill if exists.
- Leave dangling reference files. Attempt to recover from the opencode sqlite session db.
- Run evals. ONLY do a skill optimization unless specifically prompted to run a eval.
- Restart a delegated agent session — always RESUME by session_id.

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
  - Reference files MUST be ≤ 200 lines after changes
  - Scripts have NO line limit
  - DO NOT hard-code credentials — use ENV variable labels only
  - DO NOT hard-code $NVO_CREDENTIAL_FILE — use the variable, not a literal path
  - DO NOT add emojis unless explicitly instructed
  - Triggering keywords and progressive disclosure MUST be preserved
  - Source nvo-config-resolver.sh via bash -c (bash-only syntax, not zsh-compatible)
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
```

---

## Example: Correct Sub-Agent Prompt (all 5 sections)

> Refactor the `nvo-jira-access` skill.
>
> **SECTION 1 — FILES**
> Read:  `/home/badaniya/.private_skills/nvo-jira-access/SKILL.md`
> Read:  `/home/badaniya/.private_skills/nvo-jira-access/references/api-operations.md`
> Write: `/home/badaniya/.private_skills/nvo-jira-access/SKILL.md` (max 200 lines)
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
