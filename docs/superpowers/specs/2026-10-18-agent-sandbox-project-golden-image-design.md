# Agent Sandbox Incus Project and Golden Image Design

## Intent

Move ticket-development sandboxes into a dedicated private Incus project named `agent-sandbox`, and launch them from a scrubbed, versioned local golden image. In parallel, remove the NVO-only ticket restriction while retaining safe instance naming and cleanup behavior.

## Agent Sandbox Project

`agent-sandbox` is a local-only Incus project. It contains sandbox instances, the private golden image, project-scoped profiles, snapshots, and lifecycle state. No image remote or public publication is configured.

`labctl` receives a private config value:

```text
LABCTL_INCUS_PROJECT=agent-sandbox
```

Every Incus lifecycle operation explicitly targets that project. The project is configured to use the existing approved agent bridge and storage pool; it does not gain host networking, privileged mode, host Docker socket access, raw LXC settings, or host-device passthrough.

The current default-project sandbox must be removed through the existing cleanup lifecycle and recreated in the new project; instances are not moved across projects.

## Golden Image

The golden image is built locally inside `agent-sandbox` from the existing Ubuntu base image. It includes only public, reproducible provisioning:

- OS packages needed by development and monitoring;
- Docker/Compose installation and daemon service enablement;
- configured Go toolchain;
- public pinned `loggo` and compatible `lazydocker` versions;
- guest shell source-point scaffolding.

It excludes all tenant, ticket, or host-private state. The build command scrubs before publishing:

```text
cloud-init state and instance identity
machine-id and SSH host keys
APT caches and package lists
Go module/build caches
Docker containers, images, volumes, networks, and daemon state
systemd credentials
private NVO/Loggo/Git credential files
mounted worktrees and Git metadata
application logs and shell history
```

The image receives a versioned local alias such as:

```text
agent-sandbox/golden:YYYY-MM-DD-N
```

`labctl image build` creates it explicitly; refresh is manual and versioned. `LABCTL_INSTANCE_IMAGE` points to the approved private alias only after successful build/verification.

Per-instance cloud-init continues to apply routed network configuration, Docker daemon private DNS/registry data, sandbox user creation, and public-tool checks. Git/NVO/Loggo credentials and mounted worktrees remain per-instance lifecycle delivery, never golden-image content.

## Generic Jira Keys

Sandbox create accepts a safe generic Jira key syntax:

```text
[A-Z][A-Z0-9]+-[0-9]+
```

The submitted key retains case in the host worktree root and workspace label. `labctl` normalizes the Incus instance/state identifier to lowercase. Create action requires a successful `jira issue view <key> --raw` lookup before worktree or instance changes. Cleanup/destroy does not perform Jira lookup, allowing removal of deleted/unavailable tickets.

The original non-sandbox NVO worktree action remains unchanged.

## Validation

- Project-targeted labctl test fixtures ensure no default-project command escapes.
- Project profile/network/storage validation retains the existing isolation checks.
- Golden-image test verifies scrub list and rejects credentials/worktree/Docker state before publication.
- Generic Jira tests cover valid non-NVO keys, unsafe key rejection, create-time lookup failure, lowercase instance naming, and cleanup without lookup.
- Live validation creates a clean ticket sandbox in `agent-sandbox`, verifies private image origin, routed IP, mounts, credentials, NVO environment, interactive tooling, and complete service readiness.

## Non-goals

- Publishing images to an Incus remote or public registry.
- Migrating existing default-project instances in place.
- Changing the original non-sandbox worktree action.
- Automatic golden-image refresh.
