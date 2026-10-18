# Parallel Ticket Sandbox Bootstrap Design

## Intent

Make the NVO ticket sandbox usable before the full application stack has completed by replacing the current single, blocking stack-up hook with visible, dependency-aware stages. Each Build pane owns and reports one stage, while the top pane remains responsible for sandbox readiness and shared dependencies.

This design preserves the existing security model: an unprivileged Incus guest, no host Docker socket, routed guest networking, mounted ticket worktrees, and private configuration outside the repository.

## Current State and Evidence

`labctl bootstrap` currently creates/starts the guest and invokes `labctl_stack_up` as one blocking private hook. The Herdr lower panes wait for that lifecycle to finish before opening only interactive guest shells.

The live `NVO-20130` lifecycle did reach `NVO_SANDBOX_BOOTSTRAP_SUCCESS`, but revealed two separate reliability defects:

- Stack commands execute as root, but Git `safe.directory` is configured only for the configured guest user. GoDCApp Make targets therefore emit repeated dubious-ownership warnings.
- A PCM failure path writes binary content into the lifecycle log, which makes the Build monitor log non-textual and causes standard line searches to report it as binary.

These defects must be fixed independently of stage concurrency.

## Approved Startup Graph

```text
Top pane: guest readiness, shared dependencies/updates, lifecycle coordination

LazyDocker: attach when guest Docker is ready

PCM: setup database

Platform Services:
  build tagging ────────────────┐
                                ├─ start tagging
PCM database setup ─────────────┘

GoDCApp:
  build ────────────────┐
  start infrastructure ─┴─ run in parallel with PCM and Platform Services build

PCM database setup ─────────────┐
Platform Services tagging ready ─┴─ start GoDCApp services
```

GoDCApp build and `start-infra` explicitly do **not** wait for PCM database setup. Only GoDCApp `start-services` waits for both the PCM database completion marker and the Platform Services tagging readiness marker.

## Architecture

### Stage contract

Add a private, configuration-driven stage contract rather than embedding product commands in tracked `labctl` or Herdr scripts. The private config supplies one command per application stage:

- shared dependency/update preparation;
- PCM database setup;
- Platform Services tagging build;
- Platform Services tagging start/readiness;
- GoDCApp build;
- GoDCApp infrastructure start/readiness;
- GoDCApp service start/readiness.

`labctl` exposes a narrow `stage` subcommand that validates the ticket and runs exactly one configured stage in the guest through the existing credential-aware stack wrapper. Stage names are fixed, allowlisted identifiers; their commands remain private configuration.

### State and synchronization

Use a ticket-scoped guest-independent host state directory next to the current lifecycle log. Each stage writes an atomic marker only after its command exits successfully:

```text
<state-dir>/<ticket>.stages/
  shared.ready
  pcm-db.ready
  platform-tagging-build.ready
  platform-tagging.ready
  godcapp-build.ready
  godcapp-infra.ready
  godcapp-services.ready
  <stage>.failed
```

A stage waits for prerequisite `*.ready` markers and exits with a clear diagnostic if any prerequisite has a matching `*.failed` marker. The implementation must not use fixed sleeps as synchronization.

The top coordinator starts the shared stage, waits for it, then starts PCM, Platform Services build, GoDCApp build, and GoDCApp infrastructure as independent background processes. It starts Platform Services tagging only after PCM and tagging-build succeed; it starts GoDCApp services only after PCM and tagging succeed. It waits for all requested terminal stages before writing `NVO_SANDBOX_BOOTSTRAP_SUCCESS`; any stage failure writes a named failure marker and `NVO_SANDBOX_BOOTSTRAP_FAILED`.

### Build-tab behavior

- The top pane tails the existing ticket lifecycle log from launch. After the successful coordinator marker and private Loggo template sync, it transitions to the five-service Loggo monitor.
- LazyDocker waits only for the guest Docker readiness probe, then attaches.
- PCM, Platform Services, and GoDCApp panes run their respective stage commands and remain in an interactive diagnostic shell if their stage fails.
- Each pane displays its stage output, not just a blank shell. The Build pane therefore shows actual progress and failure ownership.
- The spinner is merely readiness feedback before a pane command can start; it is not a synchronization primitive.

## Reliability Repairs

1. Configure Git `safe.directory` for both the configured guest user and root, for every mounted linked worktree. This removes the root-run Make warnings without weakening repository safety globally.
2. Ensure the stage wrapper captures only textual stage output in the lifecycle log. A stage failure must report a file path/metadata rather than emitting raw file contents. Product command changes are not made in this repository; the wrapper should preserve output while preventing binary bytes from corrupting monitor state.
3. Keep private stack commands, registry endpoints, credentials, Loggo template paths/content, and ticket-specific ports exclusively in the private configuration file.

## Non-goals

- Changing application Makefiles or product build behavior.
- Running application stages on the host.
- Adding host networking, privileged Incus instances, a host Docker socket, or unsafe LXC devices.
- Changing the existing non-sandbox NVO worktree action.
- Recreating active sandboxes as part of implementation validation without explicit user approval.

## Acceptance Criteria

1. A new Build tab appears immediately after worktree setup.
2. LazyDocker attaches once the guest Docker daemon is available, without waiting for application bootstrap.
3. PCM database setup, Platform Services tagging build, GoDCApp build, and GoDCApp infrastructure start overlap when their prerequisites permit.
4. Platform Services tagging start begins only after PCM database setup and tagging build complete.
5. GoDCApp services start only after PCM database setup and Platform Services tagging readiness complete.
6. Every stage has one named log/marker outcome; failures keep their Build pane alive with diagnostics.
7. Root and guest-user Git operations on mounted worktrees do not produce dubious-ownership warnings.
8. The monitor remains line-oriented text even when a stage command fails.
9. Existing focused labctl and Herdr tests continue to pass, with new tests covering the dependency graph, failure propagation, root safe-directory setup, and binary-log protection.
