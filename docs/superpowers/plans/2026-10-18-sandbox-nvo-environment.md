# Sandbox NVO Environment Delivery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Safely deliver approved NVO/XIQ settings to ticket sandboxes, rewrite host-bound values to the routed guest address, isolate sensitive values with Incus credentials, and make XIQ thread-pool sandbox-configurable.

**Architecture:** `labctl` parses an allowlisted NVO section from an owner-only private profile without evaluation, renders a private POSIX environment file, and installs it through a systemd credential. Every stage wrapper sources that file. GoDCApp’s Makefile retains its default thread pool but accepts an environment override.

**Tech Stack:** Bash, Incus systemd credentials, existing labctl private config parser, Make, shellcheck, shfmt.

**Spec:** `docs/superpowers/specs/2026-10-18-sandbox-nvo-environment-design.md`

## Global Constraints

- Never source/evaluate the host private profile.
- Never commit values, tokens, credential paths/content, or host addresses.
- Allow only the approved NVO/XIQ variable names.
- Deliver sensitive values through separate Incus credentials, not the normal guest environment file.
- Preserve default non-sandbox GoDCApp behavior.

## Review Focus

- A hostile shell expression in the profile must remain data and cause rejection, never execution.
- Host-bound XIQ values must always be rewritten to the routed sandbox IP.
- Unknown or duplicate variables must fail closed.
- Generated normal environment content must contain no token or credential material.
- `XIQ_THREAD_POOL=100` must affect only sandbox startup and retain Makefile default compatibility.

---

### Task 1: Private NVO source configuration and parser

**Files:**
- Modify: `incus/.config/labctl/config.example.env`
- Modify: `incus/.local/lib/labctl/config.sh`
- Create: `incus/.local/lib/labctl/nvo-env.sh`
- Test: `tests/incus/labctl_test.sh`

**Interfaces:**
- Produces `labctl_nvo_env_render(ticket, output)` from `LABCTL_NVO_ENV_SOURCE_PATH`.
- Fixed allowlist and literal-only parser; no profile execution.

- [ ] Write failing fixtures for valid NVO input, host-value rewrite, unknown/duplicate/malformed entries, and command-substitution rejection.
- [ ] Run `bash tests/incus/labctl_test.sh`; verify parser behavior fails before implementation.
- [ ] Implement owner/mode validation, section-bounded literal parsing, allowlist validation, guest-IP rewrite, and POSIX `KEY=VALUE` rendering.
- [ ] Run the focused test green.
- [ ] Commit: `incus: parse private NVO sandbox environment`.

### Task 2: Credential delivery and stage sourcing

**Files:**
- Modify: `incus/.local/bin/labctl`
- Modify: `incus/.local/lib/labctl/incus.sh`
- Modify: `incus/.local/lib/labctl/network.sh`
- Test: `tests/incus/labctl_test.sh`

**Interfaces:**
- Produces `labctl nvo-env sync TICKET`.
- Installs normal env at a private sandbox-user path; installs sensitive NVO credential artifacts separately.
- `labctl_incus_stack_command` sources the normal environment before private stage commands.

- [ ] Write failing tests for allowlisted `nvo-env sync`, private file mode/ownership, credential redaction, and stage-wrapper sourcing.
- [ ] Run the focused test red.
- [ ] Implement native credential delivery and guest install; add CLI dispatch without printing rendered values.
- [ ] Run the focused test green.
- [ ] Commit: `incus: sync private NVO sandbox environment`.

### Task 3: Bootstrap integration and environment shell source point

**Files:**
- Modify: `herdr/.config/herdr-spreader/nvo-harness-worktree-sandbox.sh`
- Modify: `incus/.local/share/labctl/cloud-init.yaml.tmpl`
- Test: `tests/herdr/nvo-harness-worktree-sandbox_test.sh`
- Test: `tests/incus/labctl_test.sh`

**Interfaces:**
- Bootstrap invokes NVO environment sync after create/credential sync and before shared stage.
- Bash sources the guest environment file conditionally.

- [ ] Write failing Herdr ordering and cloud-init source-point tests.
- [ ] Run focused tests red.
- [ ] Add bootstrap sync marker/order and Bash source snippet; ensure missing private source fails safely before stage execution.
- [ ] Run focused tests green.
- [ ] Commit: `herdr: provision NVO environment before stages`.

### Task 4: Configurable XIQ emulator thread pool

**Files:**
- Modify: `~/workspace/badaniya/NVO-20130/GoDCApp/NVO/scripts/development/Makefile` (ticket worktree only, after explicit confirmation)
- Modify: owner-only `~/.config/labctl/config.env`
- Test: Make target dry-run or focused assertion in the GoDCApp worktree.

**Interfaces:**
- `XIQ_THREAD_POOL ?= 1000` preserves existing product default.
- `start-xiqemu-kafka` uses `thread-pool=$(XIQ_THREAD_POOL)`.
- Sandbox private stage config sets `XIQ_THREAD_POOL=100` before `make start-infra`.

- [ ] Ask for explicit confirmation immediately before modifying the ticket worktree Makefile.
- [ ] Write a failing dry-run/assertion proving `make XIQ_THREAD_POOL=100 -n start-infra` still emits `thread-pool=1000` before the change.
- [ ] Add the configurable Make variable and replace only the hardcoded emulator argument.
- [ ] Run the dry-run/assertion green for both default and override values.
- [ ] Update the private GoDCApp stage command without printing it; validate `labctl config-load`.
- [ ] Commit the ticket-worktree change separately with its repository’s conventions; do not commit private config.

### Task 5: Verification and approved live validation

- [ ] Run `bash tests/incus/labctl_test.sh`, `bash tests/herdr/nvo-harness-worktree-sandbox_test.sh`, shellcheck, shfmt, and `git diff --check`.
- [ ] With explicit user approval, recreate the sandbox and verify generated environment ownership/mode, rewritten XIQ hosts, stage environment visibility, working Loggo/LazyDocker, and `xiqemu-server` remains running.
- [ ] Record any expected ticket-worktree diff separately from `.stowed` changes.
