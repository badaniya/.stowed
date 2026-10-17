# Task 3 Report — workspace validation and sandbox lifecycle

## Changes

- Added constrained ticket-workspace discovery and linked-worktree metadata validation in `incus/.local/lib/labctl/workspace.sh`.
- Added lifecycle CLI commands for create, start, stop, status, destroy, and separate confirmed worktree cleanup.
- Added profile-based launch readiness, exact-path idmapped `master` and ticket-root disk attachments, private Docker/stack lifecycle helpers, and state lifecycle updates.
- Added fake-command regressions for absent and escaping ticket roots, missing bare metadata, harnesses, malformed worktrees, dry-run launch/mount plans, matching/conflicting existing instances, and separate cleanup behavior.
- Fixed ticket-root lookup to select exactly one immediate directory under `LABCTL_WORKSPACE_ROOT` by case-insensitive comparison after strict normalization. Missing and ambiguous matches fail; canonical-path containment is rechecked after resolution.
- Added a regression with on-disk `NVO-20130` and mixed-case user input. It verifies the resolved host path preserves `NVO-20130`, while the state record instance/key remains `nvo-20130`; a second case variant is rejected as ambiguous.

## Commit

`8e443cd7` — `incus: resolve ticket roots case-insensitively`

## Checks

### Red-green regression

Before the production change, `bash tests/incus/labctl_test.sh` failed the new regression with:

```text
expected [.../workspace/NVO-20130], got [.../workspace/nvo-20130]
expected command to succeed: labctl_workspace_validate NvO-20130
```

After the production change, the full suite passed:

```text
bash tests/incus/labctl_test.sh
shellcheck incus/.local/bin/labctl incus/.local/lib/labctl/*.sh
shfmt -d incus/.local/bin/labctl incus/.local/lib/labctl/*.sh
git diff --check
```

No real Incus instance, profile, bridge, disk device, route, firewall, Docker service, Git worktree, or user hook was created or changed. The lifecycle assertions use the existing fake-command test harness and dry-run invocations.

## Concerns

- Real-host lifecycle execution remains intentionally untested; this task was verified exclusively with fakes/dry-run behavior.
- The pre-existing unrelated modified and untracked files remain untouched and are not part of the Task 3 commit.

---

## Lifecycle follow-up — inherited `eth0` fixed address

### Changes

- `labctl_incus_launch` now launches the profile-based instance stopped with `--no-start`, overrides inherited `eth0` through the Incus 6 device-override API with the reserved `ipv4.address`, then starts it before workspace attachment/readiness.
- The existing profile validation remains before launch and the existing runtime isolation checks are unchanged.
- The fake Incus fixture now rejects the invalid inherited-device `config device set` form. The lifecycle regression requires the fixed-address `config device override`, verifies no direct set is logged, and checks the override precedes both instance start and cloud-init readiness.

### Red-green regression

**Red:** before the production change, the new non-dry-run fake lifecycle create reached the direct form and failed with:

```text
Error: Cannot update inherited device; use config device override
FAIL: expected command to succeed: ... labctl ... create JIRA-#
FAIL: expected command log to contain [config device override jira-# eth0 ipv4.address=10.42.0.10]
FAIL: expected command log not to contain [config device set jira-# eth0 ipv4.address=]
```

**Green:** after the change, all checks passed:

```text
bash tests/incus/labctl_test.sh
shellcheck incus/.local/bin/labctl incus/.local/lib/labctl/*.sh
shfmt -d incus/.local/bin/labctl incus/.local/lib/labctl/*.sh
git diff --check
```

No real Incus command, host configuration, or incomplete real instance was accessed or changed; all lifecycle execution used the fake command binary.

### Commit

`0370c429` — `incus: override inherited profile NIC before start`

## Incus 6 stopped-instance lifecycle compatibility follow-up

### Commit

`3b6e7fd4` — `incus: use init for stopped instances`

### Red-green regression

**Red:** The fake Incus command now rejects `incus launch ... --no-start` with `Error: unknown flag: --no-start`. Before the production edit, `bash tests/incus/labctl_test.sh` failed at the non-dry-run lifecycle create because production used that unsupported invocation; the regression also required an `init` command and the subsequent device override.

**Green:** `labctl_incus_launch` now uses `incus init` with the unchanged default and managed profiles and `user.user-data` cloud-init configuration. `init` leaves the instance stopped, preserving the existing fixed-IP inherited-device override, explicit start, idmapped workspace mounts, and cloud-init/Docker readiness order. The fake regression asserts `init` is used (and `launch` is absent), verifies both profiles and cloud-init are present, and checks `init -> device override -> start -> cloud-init readiness` ordering.

### Verification

```text
bash tests/incus/labctl_test.sh                                                    PASS
shellcheck incus/.local/bin/labctl incus/.local/lib/labctl/*.sh                    PASS
shellcheck -e SC1091 tests/incus/labctl_test.sh                                    PASS
shfmt -d incus/.local/bin/labctl incus/.local/lib/labctl/*.sh tests/incus/labctl_test.sh PASS
git diff --check                                                                   PASS
```

No real Incus command, instance, profile, device, mount, worktree, Docker service, or hook ran; the lifecycle execution uses the fake command binary.

### Concern

- Live-host verification remains intentionally out of scope; Incus 6 command compatibility is covered by the fake command contract.

## Empty-IP reservation recovery follow-up

### Changes

- `labctl create` now treats an existing state record with an empty or malformed IP as an incomplete reservation and atomically re-reserves the next available address before any Incus lifecycle call.
- `labctl_state_reserve_ip` only reuses syntactically valid IPv4 state values; replacement reservations retain the lock-protected temporary-file-and-rename write path.
- State claim/record and Incus launch now reject empty or malformed IPv4 values as defense in depth, so they cannot persist an empty address or create/override a NIC with one.
- Added a fake lifecycle regression seeded with the real failure shape: `nvo-20130` exists in the test registry with `ip: ""`. Create recovers the next free address, records it, and passes that same address to the Incus inherited-`eth0` override.

### Reservation behavior

The selected behavior is recovery, rather than failure: an empty record has no usable reservation to preserve. Under the existing state lock, `create` replaces it with the next available pool address using the existing atomic temp-file rename, then uses that address for launch. This preserves the normal reservation lifecycle and prevents empty-IP side effects.

### Red-green regression

**Red:** Before the production change, `bash tests/incus/labctl_test.sh` launched `nvo-20130` with `ipv4.address=` after reading its pre-existing empty state value. The regression failed because the persisted IP remained empty and no valid override was logged.

**Green:** The regression now records `10.42.0.11` atomically and logs exactly `config device override nvo-20130 eth0 ipv4.address=10.42.0.11`; an exact empty override is rejected by the test.

### Verification

```text
bash tests/incus/labctl_test.sh                                                    PASS
shellcheck incus/.local/bin/labctl incus/.local/lib/labctl/*.sh                    PASS
shellcheck -e SC1091 tests/incus/labctl_test.sh                                    PASS
shfmt -d incus/.local/bin/labctl incus/.local/lib/labctl/*.sh tests/incus/labctl_test.sh PASS
git diff --check                                                                   PASS
```

No real host state, Incus instance/profile/device, bridge, route, firewall, Docker service, worktree, or user hook was accessed or modified; lifecycle commands ran solely through the fake test binary.

## Incus 6 inspection API compatibility follow-up

### Changes

- Replaced the Task 3 status inspection path with a validated, URI-encoded `incus query /1.0/instances/<name>` helper. Instance names must be normalized ticket identifiers before they form an API path.
- The fake Incus CLI now rejects `incus info <instance> --format json` and both expanded/non-expanded `incus config show <instance> --format json` inspection forms, while serving the same data through the instance endpoint.
- The status regression proves `labctl status` succeeds through `/1.0/instances/jira-%23` without either unsupported format command.

### Red-green regression

**Red:** with the Incus 6 fake rejection in place, the unmodified status helper failed with `Error: unknown flag: --format` and the focused status assertion failed because no instance API query was made.

**Green:** status now queries the URI-encoded instance endpoint. The fake suite passes and the command log contains the endpoint only, not an unsupported formatted inspection command.

No real Incus command, instance, profile, mount, network, stack, or worktree was accessed or changed.
