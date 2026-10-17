# Incus development sandbox operator guide

This package provides `labctl`, a host-side controller for disposable,
ticket-scoped development sandboxes. It separates each sandbox's nested Docker
state while preserving the existing Git worktree layout. It is an operational
isolation boundary, not a safe boundary for hostile code.

All configuration values in this repository are placeholders. Keep topology,
workspace locations, image choices, service identifiers, ports, and secrets in
the owner-only active configuration; never add them to this package.

## Install and configure

Stow the package, then create the private active configuration from the
example. The active configuration path follows the standard XDG configuration
location (or the corresponding home-directory fallback).

```bash
stow -d "$HOME/.stowed" incus
install -D -m u=rw,go= incus/.config/labctl/config.example.env \
  "${XDG_CONFIG_HOME:-$HOME/.config}/labctl/config.env"
```

Replace every placeholder in the copied file before use. Store credentials only
through the approved secret mechanism; do not copy them from shell aliases,
private files, or home-directory state. Keep the active file owner-readable and
owner-writable only.

The local prerequisites are:

- `bash`, `incus`, `jq`, `flock`, `docker`, `ip`, `sysctl`, `df`, `lxc`, and
  `multipass`; these are the commands checked by `labctl preflight`.
- `nc` for the `verify` TCP reachability checks.
- GNU Stow for package installation.
- An account that can query and manage only the intended Incus daemon. Grant
  membership in the locally designated Incus administration group (commonly
  `incus-admin`) rather than using broad elevation, then confirm `incus info`
  succeeds as that account.

## Host prerequisites and proof

Before any setup, inventory the host's existing container, virtualization,
bridge, storage, and route resources. `labctl preflight` is read-only and must
succeed without conflicts. Do not migrate, stop, reconfigure, or delete
pre-existing resources.

An operator must complete these manual prerequisites outside `labctl`:

- Add a static route from the device or lab network to the configured sandbox
  subnet through the approved host gateway.
- Allow only the approved device-facing TCP contract through the host firewall;
  keep management endpoints and unrelated services private.
- Confirm forwarding and the chosen network do not overlap an existing route or
  bridge.

Before creating a real ticket sandbox, prove nested Docker in a disposable,
unprivileged test instance using the selected image and storage/network drivers.
If it needs host compatibility changes, review and apply them explicitly at the
host profile level. Do not solve a failed proof by enabling privileged Docker,
host networking, a host Docker socket, or broad device passthrough.

## Docker registry and private stack bootstrap

The generic cloud-init installs and readies Docker only. Set
`LABCTL_INTERNAL_INSECURE_REGISTRIES` to a comma-separated list of internal
`host:port` registry endpoints. The controller rejects schemes, paths,
credentials, malformed ports, and duplicates, then renders those endpoints into
Docker's `insecure-registries` array and restarts Docker. Keep endpoint values
solely in the owner-only active configuration: they are not represented in the
example or documentation, and cloud-init payloads are passed to Incus on
standard input rather than logged.

For a direct-Docker private stack setup, set the private stack-up command with
an explicit `IMAGE_IMPORT=false` prefix, for example:

```bash
LABCTL_STACK_UP_COMMAND='IMAGE_IMPORT=false ./private-stack-setup.sh'
```

Use a command appropriate to the mounted workspace; do not add ticket, project,
or repository identifiers to this documentation. `labctl` transfers the hook to
the guest on standard input rather than placing its contents on an `incus exec`
command line, so private hook text is not included in controller command logs.
Store credentials through the approved credential mechanism, not in stack hook
values.

K3s installation, service configuration, readiness checks, and registry mirror
configuration are intentionally outside the generic bootstrap. K3s remains a
deferred, opt-in workload scope that needs a separately reviewed design.

## Command reference

Run `labctl help` for the installed interface. Use `<ticket>` and `<repo>` as
placeholders below; never put private identifiers in committed documentation.

| Command | Purpose and safety boundary |
| --- | --- |
| `labctl preflight` | Read-only dependency, access, forwarding, conflict, and route validation. |
| `labctl setup-host --yes` | Creates or reconciles only controller-owned Incus resources; `--yes` is required. |
| `labctl create <ticket> [--repo <repo>] [--ensure-worktree]` | Creates or reuses the sandbox for an existing workspace. |
| `labctl start <ticket>` | Starts only the named sandbox and its private runtime. |
| `labctl stop <ticket>` | Stops only the named sandbox; source worktrees remain intact. |
| `labctl status <ticket>` | Reports controller state, workspace validity, and instance state. |
| `labctl verify <ticket>` | Checks isolation, private Docker, stack health, and configured TCP reachability. |
| `labctl destroy <ticket> --yes` | Removes the named sandbox and private runtime state, not source worktrees. |
| `labctl cleanup-worktree <ticket> --yes` | Separately delegates source-worktree removal after explicit confirmation. |
| `labctl credential sync <ticket>` | Reads the configured HTTPS host credential without displaying it and updates only the configured sandbox system credential. |
| `labctl credential unset <ticket>` | Removes only the configured sandbox system credential. |

Use `--dry-run` before every state-changing action, including host setup,
creation, destruction, and worktree cleanup. The global form places it before
the command, for example `labctl --dry-run setup-host --yes` and
`labctl --dry-run create <ticket>`. `--yes` is deliberately required for
host setup, destruction, and separate worktree cleanup; inspect the target
before confirming it.

## Workspace and Git safety

`labctl` recognizes both a single-repository ticket workspace and a harness
workspace containing multiple repositories and generated context. In either
case it mounts the ticket root together with the shared bare Git metadata so
linked-worktree `.git` indirection remains valid.

Continue using the existing worktree creation and removal scripts. The
controller does not replace, move, rename, clone, or restructure worktrees.
It preserves shared bare repositories, existing absolute Git metadata paths,
and root-level harness context. Do not run broad automatic worktree pruning
against the shared metadata. If Git needs an ownership exception for an
idmapped mount, scope it to the required mounted worktree inside that sandbox;
never disable ownership checks globally.

## State, recovery, and lifecycle

The controller registry is stored under the XDG state location. It records the
sandbox identity, persistent address reservation, workspace type, mount roots,
and lifecycle status. Back up that registry before destructive maintenance.

If a lifecycle action is interrupted, first preserve the registry copy and
inspect `labctl status <ticket>` plus the Incus instance. Reconcile only the
named sandbox: retain or restore its recorded address reservation, verify the
workspace mounts, then use `start`, `stop`, or `destroy` deliberately. Do not
reconstruct state by deleting shared Git metadata or by running broad cleanup.
Escalate conflicting state or missing worktrees for operator review.

`stop` preserves the sandbox and its private runtime for later `start`.
`destroy --yes` removes the sandbox and its private runtime while preserving
source worktrees and shared Git metadata. `cleanup-worktree --yes` is a
separate action because removing a source worktree is not an incidental effect
of sandbox destruction.

## Capacity and rollout gate

Treat five concurrent sandboxes as the initial maximum. Before enabling a
larger fleet or changing resource limits, measure one complete sandbox stack:
CPU, memory, process count, disk use, and host headroom under representative
load. Record the measurement and obtain an operator decision before scaling.

Kubernetes workload classes, CI agent registration, GitOps control planes,
application-configuration repository access, and DNS naming are explicitly
deferred. They are not part of this package's initial rollout.

## Private Git credential delivery

Set `LABCTL_GIT_HOST` to the Git HTTPS host. `LABCTL_GIT_CREDENTIAL_NAME` is
optional and defaults to `git-module-token`. Do not place a credential value or
username in active configuration. `labctl credential sync <ticket>` uses the
host Git credential helper, writes restrictive temporary files, and patches only
`systemd.credential.<configured-name>` on the target instance. It never prints
the returned credential. Use `labctl credential unset <ticket>` to remove that
key.

During stack hooks, a root-only temporary askpass helper reads the systemd
credential at runtime, supplies the returned username and token to Git, sets
`GOPRIVATE` and `GONOSUMDB` for the configured host, and removes itself even if
the hook fails. The token is not written to the sandbox filesystem.
