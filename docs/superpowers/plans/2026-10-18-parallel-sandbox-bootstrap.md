# Parallel Sandbox Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Start NVO sandbox application stages concurrently where safe, with explicit PCM/tagging dependency markers, visible Build-pane progress, and reliable Git/log behavior.

**Architecture:** `labctl` gains allowlisted private stage commands executed in the existing credential-aware guest wrapper. The Herdr action coordinates stages through ticket-scoped atomic marker files and assigns each Build pane its own stage output. Application commands remain in owner-only private configuration; tracked scripts contain only stage identifiers, dependencies, and marker mechanics.

**Tech Stack:** Bash, Incus CLI, Herdr CLI, Git, existing labctl private config parser, shellcheck, shfmt.

**Spec:** `docs/superpowers/specs/2026-10-18-parallel-sandbox-bootstrap-design.md`

## Global Constraints

- Do not commit credentials, internal registry/DNS values, stack commands, Loggo templates, or ticket-specific ports.
- Keep the sandbox unprivileged; do not add host networking, host Docker socket mounts, or unsafe Incus/LXC devices.
- Preserve the existing non-sandbox NVO worktree action unchanged.
- Use named ready/failed markers for stage synchronization; never use sleeps as a dependency mechanism.
- Do not delete/recreate active sandboxes, worktrees, or Herdr tabs for verification without explicit user approval.
- Keep failure panes interactive for diagnosis.

## Review Focus

- Private config accepts all required stage hooks but rejects missing, duplicate, placeholder, or unrecognized variables; test in Task 1.
- A user cannot invoke an arbitrary private hook through `labctl stage`; only fixed stage names are accepted; test in Task 2.
- Root and the configured guest user both trust only the linked mounted worktrees, not arbitrary directories; test in Task 3.
- A failed prerequisite unblocks dependents with a named failure result rather than causing indefinite waits; test in Task 4.
- Stage output does not make the lifecycle marker log binary or hide `SUCCESS`/`FAILED`; test in Task 4.

---

### Task 1: Private stage-hook configuration contract

**Files:**
- Modify: `incus/.config/labctl/config.example.env`
- Modify: `incus/.local/lib/labctl/config.sh`
- Test: `tests/incus/labctl_test.sh`

**Interfaces:**
- Consumes: owner-only `config.env` parsing without shell evaluation.
- Produces: required string variables `LABCTL_STAGE_SHARED_COMMAND`, `LABCTL_STAGE_PCM_DB_COMMAND`, `LABCTL_STAGE_PLATFORM_TAGGING_BUILD_COMMAND`, `LABCTL_STAGE_PLATFORM_TAGGING_START_COMMAND`, `LABCTL_STAGE_GODCAPP_BUILD_COMMAND`, `LABCTL_STAGE_GODCAPP_INFRA_COMMAND`, and `LABCTL_STAGE_GODCAPP_SERVICES_COMMAND`.

- [ ] **Step 1: Write failing config tests**

Add test configuration fixtures containing the seven stage variables. Add individual failure assertions for a missing stage command, a duplicate stage command, an unrecognized stage command, and a placeholder stage command.

- [ ] **Step 2: Run the focused test to verify it fails**

Run: `bash tests/incus/labctl_test.sh`

Expected: FAIL because the current parser does not recognize the stage variables.

- [ ] **Step 3: Add the stage variables to the allowlisted required configuration**

Update `labctl_config_required_vars` and `config.example.env`. Keep values opaque non-empty strings—do not execute, parse, print, or log them during configuration validation.

- [ ] **Step 4: Run the focused test to verify it passes**

Run: `bash tests/incus/labctl_test.sh`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add incus/.config/labctl/config.example.env incus/.local/lib/labctl/config.sh tests/incus/labctl_test.sh
git commit -m "incus: configure parallel bootstrap stages"
```

### Task 2: Allowlisted guest stage execution

**Files:**
- Modify: `incus/.local/bin/labctl`
- Modify: `incus/.local/lib/labctl/incus.sh`
- Test: `tests/incus/labctl_test.sh`

**Interfaces:**
- Consumes: `labctl stage TICKET STAGE_NAME` and the seven private stage variables from Task 1.
- Produces: `labctl_stage(ticket, stage_name)` and `labctl_incus_run_stage(instance, ticket_root, private_command)` using the current credential-aware wrapper.

- [ ] **Step 1: Write failing CLI tests**

Add tests asserting `labctl stage bootstrap-new pcm-db` runs the configured PCM private command through the Incus wrapper, and `labctl stage bootstrap-new arbitrary-command` fails before guest execution. Assert emitted lifecycle output names the stage but not the private command value.

- [ ] **Step 2: Run the focused test to verify it fails**

Run: `bash tests/incus/labctl_test.sh`

Expected: FAIL because `stage` is not a supported command.

- [ ] **Step 3: Implement `labctl stage`**

Add `stage TICKET STAGE_NAME` usage and dispatch. Map only the seven fixed identifiers (`shared`, `pcm-db`, `platform-tagging-build`, `platform-tagging-start`, `godcapp-build`, `godcapp-infra`, `godcapp-services`) to their private variables. Reuse the existing askpass/credential wrapper without printing the configured command.

- [ ] **Step 4: Run the focused test to verify it passes**

Run: `bash tests/incus/labctl_test.sh`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add incus/.local/bin/labctl incus/.local/lib/labctl/incus.sh tests/incus/labctl_test.sh
git commit -m "incus: add allowlisted sandbox stages"
```

### Task 3: Root Git safe-directory support

**Files:**
- Modify: `incus/.local/lib/labctl/incus.sh`
- Test: `tests/incus/labctl_test.sh`

**Interfaces:**
- Consumes: the existing linked-worktree enumerator and configured sandbox user.
- Produces: Git `safe.directory` setup for root and the configured sandbox user for every linked ticket worktree.

- [ ] **Step 1: Write failing tests**

Extend the lifecycle fixture assertions to require one root `git config --global --add safe.directory` call and one `su - <instance-user>` call for each linked worktree. Assert both target the exact ticket worktree paths.

- [ ] **Step 2: Run the focused test to verify it fails**

Run: `bash tests/incus/labctl_test.sh`

Expected: FAIL because root receives no `safe.directory` entries.

- [ ] **Step 3: Configure each safe directory for root and the guest user**

Modify `labctl_incus_configure_git_safe_directories` to make the root call and retain the existing configured-user call. Do not use `safe.directory=*`.

- [ ] **Step 4: Run the focused test to verify it passes**

Run: `bash tests/incus/labctl_test.sh`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add incus/.local/lib/labctl/incus.sh tests/incus/labctl_test.sh
git commit -m "incus: trust mounted worktrees for root"
```

### Task 4: Herdr stage coordinator and Build-pane ownership

**Files:**
- Modify: `herdr/.config/herdr-spreader/nvo-harness-worktree-sandbox.sh`
- Modify: `tests/herdr/nvo-harness-worktree-sandbox_test.sh`

**Interfaces:**
- Consumes: `labctl create`, `credential sync`, `template sync`, `instance-user`, and `stage TICKET STAGE_NAME` from Task 2.
- Produces: ticket stage directory `<XDG_STATE_HOME>/herdr-spreader/<TICKET>.stages`, atomic `*.ready`/`*.failed` markers, `run_stage`, `wait_for_stage`, and Build-pane stage commands.

- [ ] **Step 1: Write failing coordinator tests**

Extend the fake `labctl` fixture to record stage invocations and optionally fail a named stage. Assert:

- shared runs before all application stages;
- PCM DB, Platform Services tagging build, GoDCApp build, and GoDCApp infra are started after shared and before their dependent stages;
- Platform Services tagging start waits for both PCM DB and tagging build ready markers;
- GoDCApp services waits for PCM DB and Platform Services tagging ready markers;
- failed PCM DB writes `pcm-db.failed`, prevents both dependent starts, writes the lifecycle failed marker, and leaves workspace creation non-blocking;
- state marker writes use temporary files plus rename/move semantics;
- generated Build panes run stage commands rather than only opening directories.

- [ ] **Step 2: Run the focused test to verify it fails**

Run: `bash tests/herdr/nvo-harness-worktree-sandbox_test.sh`

Expected: FAIL because the current script calls one monolithic `labctl bootstrap` and lower panes only open shells.

- [ ] **Step 3: Replace monolithic bootstrap coordination with stage markers**

Keep instance creation, credential sync, and shared-stage execution in the asynchronous coordinator. Create stage markers in the ticket state directory. Start independent ready stages in background processes, record their output in stage-specific text logs, and only invoke dependent stages after `wait_for_stage` sees all prerequisites ready. On a stage failure, record its named failed marker, stop scheduling dependents, and write the lifecycle failure marker.

Sanitize lifecycle log handling at the coordinator boundary: preserve normal text output, but redirect non-text/binary output to a named per-stage artifact and append a text-only diagnostic/path to the lifecycle log.

- [ ] **Step 4: Assign Build-pane commands to lifecycle stages**

Keep the monitor top pane behavior. Start LazyDocker after guest Docker readiness. Make PCM, Platform Services, and GoDCApp panes attach to the corresponding stage log/process and then open an interactive guest shell. Ensure each pane remains open with an actionable diagnostic on failure.

- [ ] **Step 5: Run the focused test to verify it passes**

Run: `bash tests/herdr/nvo-harness-worktree-sandbox_test.sh`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add herdr/.config/herdr-spreader/nvo-harness-worktree-sandbox.sh tests/herdr/nvo-harness-worktree-sandbox_test.sh
git commit -m "herdr: parallelize sandbox application stages"
```

### Task 5: Documentation and full static verification

**Files:**
- Modify: `docs/superpowers/specs/2026-10-18-parallel-sandbox-bootstrap-design.md` only if implementation decisions materially differ from the approved design.
- Modify: `.superpowers/sdd/.../progress.md` if that existing task progress record is maintained for this feature.

**Interfaces:**
- Consumes: completed Tasks 1–4.
- Produces: verified tracked implementation with private active configuration updated manually outside Git.

- [ ] **Step 1: Update the owner-only active configuration manually**

Add the seven stage command variables to `~/.config/labctl/config.env` with the existing product Make targets. Do not add the file to Git and do not print its values.

- [ ] **Step 2: Run all focused checks**

Run:

```bash
bash tests/incus/labctl_test.sh
bash tests/herdr/nvo-harness-worktree-sandbox_test.sh
shellcheck -e SC1091 incus/.local/bin/labctl incus/.local/lib/labctl/config.sh incus/.local/lib/labctl/incus.sh herdr/.config/herdr-spreader/nvo-harness-worktree-sandbox.sh
gshfmt -d incus/.local/bin/labctl incus/.local/lib/labctl/config.sh incus/.local/lib/labctl/incus.sh herdr/.config/herdr-spreader/nvo-harness-worktree-sandbox.sh
git diff --check
```

Expected: all commands exit zero.

- [ ] **Step 3: Live validation only after explicit approval**

With user approval, create a new sandbox workspace and verify stage timestamps/markers demonstrate the approved parallel graph, Build panes show their own output, no root Git dubious-ownership warnings appear, and the lifecycle log remains text-readable.

- [ ] **Step 4: Commit documentation updates if any**

```bash
git add docs/superpowers/specs/2026-10-18-parallel-sandbox-bootstrap-design.md .superpowers/sdd
git commit -m "docs: record parallel sandbox validation"
```

## Self-Review

- **Spec coverage:** Tasks 1–2 provide private stage hooks and safe execution; Task 3 repairs root Git ownership warnings; Task 4 implements the full approved graph, pane behavior, failure propagation, and text-only lifecycle logs; Task 5 updates private local config and verifies without recreating a live workspace absent permission.
- **Type consistency:** stage identifiers are fixed across config names, `labctl stage`, marker names, and Herdr coordination.
- **Review focus:** every listed risk is explicitly assigned to a test in Tasks 1–4.
- **Proportion:** the plan defines interfaces, test evidence, and dependency order without embedding application-specific private commands.
