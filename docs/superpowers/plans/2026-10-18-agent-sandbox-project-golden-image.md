# Agent Sandbox Project, Golden Image, and Generic Jira Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run ticket sandboxes from a private `agent-sandbox` Incus project and scrubbed local golden image, while accepting safe generic Jira keys for sandbox creation.

**Architecture:** `labctl` consistently targets a configurable Incus project. An explicit image-build lifecycle prepares and scrubs a clean guest before publishing a private project-local alias. Herdr validates Jira only during sandbox creation; cleanup remains offline-safe.

**Tech Stack:** Bash, Incus CLI/projects/images/profiles, cloud-init, Jira CLI, shellcheck, shfmt.

**Spec:** `docs/superpowers/specs/2026-10-18-agent-sandbox-project-golden-image-design.md`

## Global Constraints

- No public image remote, registry, or image publication.
- Preserve sandbox isolation: unprivileged, routed bridge, no host Docker socket/network/raw LXC/host devices.
- Private credentials, profile paths, registry/DNS values, and Jira data remain untracked.
- Existing default-project instances are cleaned up and recreated; never moved between projects.
- Original non-sandbox NVO worktree action remains unchanged.
- Golden image refresh is explicit/manual and versioned.

## Review Focus

- A missing project flag on any Incus command silently escapes isolation; test every lifecycle command path.
- Scrub failure must prevent image publication, not merely warn.
- Generic key create must fail before side effects when Jira lookup fails.
- Cleanup must work if Jira is unavailable or the ticket was deleted.
- The golden image must not contain Docker state, cloud-init identity, credentials, worktrees, or logs.

---

### Task 1: Generic Jira-key validation and create-time lookup

**Files:**
- Modify: `herdr/.config/herdr-spreader/nvo-harness-worktree-sandbox.sh`
- Modify: `herdr/.config/herdr-spreader/nvo-harness-worktree-sandbox-base.sh`
- Test: `tests/herdr/nvo-harness-worktree-sandbox_test.sh`

- [ ] Write failing fixtures for a valid non-NVO key, unsafe key rejection, Jira lookup failure before base creator/workspace/labctl calls, and cleanup’s absence of Jira dependency.
- [ ] Run the focused Herdr test red.
- [ ] Implement generic safe key validation and required `jira issue view --raw` create preflight; preserve submitted key case for host directories and lowercase normalized instance naming.
- [ ] Run the focused Herdr test green.
- [ ] Commit: `herdr: validate generic Jira sandbox tickets`.

### Task 2: Project-aware labctl lifecycle

**Files:**
- Modify: `incus/.config/labctl/config.example.env`
- Modify: `incus/.local/lib/labctl/config.sh`
- Modify: `incus/.local/lib/labctl/common.sh`
- Modify: `incus/.local/lib/labctl/incus.sh`
- Modify: `incus/.local/lib/labctl/host-setup.sh`
- Test: `tests/incus/labctl_test.sh`

- [ ] Write failing fixtures requiring `LABCTL_INCUS_PROJECT=agent-sandbox`; assert lifecycle Incus commands target the project and profile/image queries cannot fall back to default.
- [ ] Run focused labctl test red.
- [ ] Implement validated project config and centralized project-aware Incus command/query helpers; create/reconcile project-scoped safe profile using only approved bridge/pool access.
- [ ] Run focused test green.
- [ ] Commit: `incus: isolate sandboxes in agent project`.

### Task 3: Explicit scrubbed golden-image build command

**Files:**
- Modify: `incus/.local/bin/labctl`
- Modify: `incus/.local/lib/labctl/incus.sh`
- Create: `incus/.local/lib/labctl/image.sh`
- Modify: `incus/.local/share/labctl/cloud-init.yaml.tmpl`
- Test: `tests/incus/labctl_test.sh`

- [ ] Write failing tests for `labctl image build VERSION`, private project aliasing, scrub-command ordering, and publication refusal when scrub verification finds forbidden state.
- [ ] Run focused test red.
- [ ] Implement a clean temporary builder instance, public provisioning wait, scrub/verification, image publish to the project-local alias, and builder destruction on success/failure.
- [ ] Run focused test green.
- [ ] Commit: `incus: build scrubbed sandbox golden image`.

### Task 4: Private active configuration and live migration

**Files:**
- Modify: owner-only `~/.config/labctl/config.env` only; do not commit.
- Test: focused tests from Tasks 1–3 plus explicit Incus project/image inspection.

- [ ] Ask confirmation immediately before creating the Incus project, profile/image, or deleting the active default-project sandbox.
- [ ] Configure `LABCTL_INCUS_PROJECT=agent-sandbox` and approved golden image alias privately.
- [ ] Create/reconcile the project and build the first golden image using the explicit command.
- [ ] With confirmation, remove the default-project sandbox through normal cleanup and recreate it in `agent-sandbox`.
- [ ] Verify project ownership, private image origin, routed IP, mounts, safe profiles, credentials, NVO environment, XIQ, Monitor, LazyDocker, and full stage success.

### Task 5: Final verification and documentation

- [ ] Run `bash tests/incus/labctl_test.sh`, `bash tests/herdr/nvo-harness-worktree-sandbox_test.sh`, shellcheck, shfmt, and `git diff --check`.
- [ ] Update the design only if implementation decisions differ materially.
- [ ] Commit documentation updates if needed.
