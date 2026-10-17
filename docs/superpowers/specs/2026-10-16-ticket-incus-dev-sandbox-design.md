# Ticket-scoped Incus Development Sandbox Design

## Intent

Provide disposable, ticket-scoped development labs on the existing Ubuntu host. Each lab must isolate its Docker/Compose dependencies and service state while preserving the existing host Git worktree layout. GNS3 digital twins and real devices must reach each lab over a routed private subnet using the same device-facing service port numbers that the current single dev environment exposes.

The purpose is to isolate messy development dependencies and allow several agents to work concurrently. This is not a hostile-code security boundary.

## Goals

- Create an Incus system-container sandbox for a ticket workspace, named from its normalized ticket identifier (for example, `<ticket>`).
- Support both existing workspace forms without moving or rewriting them:
  - single repository ticket roots such as `~/workspace/<user>/<ticket>/repo-worktree-1`;
  - multi-repository harness roots such as `~/workspace/<user>/<ticket>/{repo-worktree-1,repo-worktree-2,repo-worktree-3,repo-worktree-4}` plus generated agent-context trees.
- Preserve the current Git topology:
  - shared bare repositories under `~/workspace/<user>/master/<repo>`;
  - ticket worktrees under `~/workspace/<user>/<TICKET>/<repo>`;
  - absolute `.git` indirection from each linked worktree to its shared bare repository.
- Make the assigned worktree usable by Git tools inside the sandbox.
- Run a private Docker daemon inside every Incus sandbox, with independent images, volumes, networks, containers, and Compose state.
- Run the existing database, device-facing, and application development services in that nested Docker daemon without changing their internal port definitions.
- Give each sandbox a stable, routable IPv4 address from an agent-lab subnet. Initial capacity is five concurrent sandboxes and a design capacity of ten.
- Let GNS3 nodes and real devices use the existing device-facing TCP port contract against the sandbox IP.
- Enforce CPU, memory, process, and storage limits at the Incus-instance boundary so nested Docker activity is bounded.
- Make sandbox lifecycle explicit: create, start, status, stop, destroy, and an optional separate source-worktree cleanup action.

## Non-goals

- Reproduce K3s/Kubernetes, Jenkins-agent behavior, GitOps control planes, or application-configuration repository access.
- Replace existing worktree-creation, worktree-removal, or terminal-workspace automation.
- Move, rename, clone, or restructure existing host worktrees.
- Expose the host Docker socket to any sandbox.
- Use privileged Docker-in-Docker as the isolation mechanism.
- Automatically delete source worktrees when an Incus sandbox is destroyed.
- Make a security claim equivalent to a dedicated VM boundary.

## Existing Constraints and Evidence

### Host and capacity

The host has sufficient general CPU, memory, and disk capacity for a measured prototype, but available memory and swap pressure must be checked at provisioning time. The initial five-environment target therefore requires enforced limits and an empirical measurement of one complete service stack before allowing ten concurrent labs.

IPv4 forwarding is already enabled. The host has an existing lab-facing bridge; the planned agent subnet is routed through the host from the GNS3/device side. An existing LXD/Multipass installation remains in place during the prototype; Incus must use distinct storage, bridge, profile, and instance names and must not migrate, stop, reconfigure, or delete existing LXD/Multipass resources.

### Current device-facing ports

The existing device-facing service publishes a defined TCP port contract. The sandbox must preserve the same external port numbers on each sandbox's unique IP:

| External port | Service target |
| --- | --- |
| `PORT_A` | `PORT_A` |
| `PORT_B` | `PORT_B` |
| `PORT_C` | `PORT_C` |
| `PORT_D` | `PORT_D` |
| `PORT_E` | `INTERNAL_PORT_E` |
| `PORT_F` | `INTERNAL_PORT_F` |

Other currently published local services are not automatically part of the inbound device contract.

### Git layout

The current worktree creators use bare repositories under `~/workspace/<user>/master/<repo>` and create ticket roots under `~/workspace/<user>/<TICKET>/`. Linked worktrees use `.git` files with absolute `gitdir:` paths into the bare repositories' `worktrees/` directories. The sandbox must keep these paths valid rather than rewriting `.git` files.

Some pre-existing bare repositories report prunable worktree records. This design must not run broad automatic `git worktree prune` operations against the existing layout.

## Architecture

```text
GNS3 / real devices
  | static route: AGENT_SUBNET via host lab-facing gateway
  v
Ubuntu host
  |- existing lab-facing bridge
  |- Incus managed bridge: agentbr0 (AGENT_GATEWAY/CIDR)
  |    |- <ticket> (SANDBOX_IP_1)
  |    |- <ticket> (SANDBOX_IP_2)
  |    `- ...
  |
  `- host Git control plane
       |- ~/workspace/<user>/master/
       `- ~/workspace/<user>/<TICKET>/

Incus instance: <ticket>
  |- host-mounted master Git metadata, same absolute path
  |- host-mounted assigned ticket root, same absolute path
  |- nested dockerd
  |    |- database service
  |    |- device-facing service
  |    `- application development services
  `- instance NIC: SANDBOX_IP
```

## Networking

### Agent bridge

Create one Incus-managed bridge for agent environments:

- bridge name: `agentbr0`;
- gateway address: `AGENT_GATEWAY/CIDR`;
- DHCP/DNS managed by Incus;
- outbound NAT enabled for package and image access;
- sandbox addresses allocated persistently from the subnet;
- initial usable allocation range reserved for ten labs.

The host forwards traffic between the existing lab network and `agentbr0`. The GNS3/device side receives a static route for `AGENT_SUBNET` through the host's lab-facing address. Firewall rules allow only the selected inbound TCP port contract to the agent subnet and deny unneeded host-management access.

### Port behavior

Every Incus instance has a separate network namespace and IP. Its nested Docker daemon can therefore publish the device-facing TCP contract without colliding with another ticket or with the host.

Traffic is direct routed traffic, not Incus host-port proxying:

```text
SANDBOX_IP_1:PORT_A -> <ticket> Incus NIC -> nested Docker port mapping -> device-facing service
SANDBOX_IP_2:PORT_A -> <ticket> Incus NIC -> nested Docker port mapping -> device-facing service
```

Incus proxy devices are deliberately excluded: they would compete for one host IP/port and do not meet the same-port-per-environment requirement.

## Incus Instance Profile

All ticket sandboxes inherit an `agent-dev-env` profile with:

- an Ubuntu base image compatible with the host and nested Docker;
- `security.nesting=true` so Docker can run inside the system container;
- one NIC attached to `agentbr0`;
- an instance-specific fixed IPv4 assignment;
- a private root disk and persistent private Docker storage;
- enforced resource limits;
- no host Docker socket, host networking, or broad device passthrough.

Before installing or initializing Incus, a non-destructive coexistence preflight must inventory existing LXD/Multipass services, bridges, storage pools, instances, and routes. It must reject any configured Incus name or subnet that conflicts with those resources and must not migrate, stop, reconfigure, or delete them. Before any ticket sandbox is created, a disposable unprivileged Incus test instance must prove that the selected Ubuntu image can run the required Docker storage and networking drivers under `security.nesting=true`. Any required host kernel modules or AppArmor adjustments must be explicitly documented and applied at the host profile level; do not solve compatibility failures by making ticket sandboxes privileged.

Initial resource policy is a starting guardrail, not a final sizing decision:

```text
limits.cpu:            2
limits.memory:         4GiB
limits.memory.enforce: hard
limits.memory.swap:    false or a tightly bounded value
limits.processes:      4096
```

The team must measure a complete device/application lab before enabling more than five concurrent sandboxes or changing the default quota.

## Source Mount Model

For ticket `<TICKET>`, attach two idmapped Incus disk devices, both read/write and mounted at exactly their host paths:

```text
host source: ~/workspace/<user>/master
container path: ~/workspace/<user>/master

host source: ~/workspace/<user>/<TICKET>
container path: ~/workspace/<user>/<TICKET>
```

Use idmapped mount support (`shift=true`) rather than recursive host `chown`. This preserves host ownership and lets the sandbox developer identity write its assigned worktree.

Mounting the shared `master` tree is required because every ticket worktree's `.git` file points to the bare repository metadata beneath it. Mounting only the ticket directory would leave Git unable to resolve the `gitdir` path.

The mount is intentionally scoped to the assigned ticket root plus common Git metadata, not the entire workspace directory. This avoids exposing unrelated ticket worktree files while preserving normal Git behavior.

Git safety policy:

- Ticket worktrees use independent branches, as created by the existing scripts.
- The existing worktree-creation/removal scripts remain the only supported mechanism for creating and removing ticket roots.
- Agents may edit, test, commit, and use normal Git operations in their assigned worktree.
- If Git reports ownership safety for an idmapped mount, configure only the required mounted worktree as an instance-local `safe.directory`; never disable Git ownership checks globally.
- A host-side control command owns cross-worktree lifecycle operations: fetch-all, worktree add/remove, and any deliberate prune/garbage-collection operation.
- Never automatically prune the existing shared bare repositories during sandbox creation or destruction.

## Lifecycle Contract

A host-side ticket sandbox controller, tentatively named `labctl`, is the sole entry point for sandbox lifecycle. It composes with existing worktree scripts; it does not replace them.

### Create `<TICKET>`

1. Verify the ticket root exists. If asked to create it, invoke the existing single-repo or harness worktree creator rather than duplicating its Git logic.
2. Normalize and validate the Incus instance name from the ticket identifier.
3. Reserve or restore the ticket's persisted agent-subnet address.
4. Create the Incus instance from the shared profile.
5. Attach the `master` and ticket-root idmapped disk devices at their existing absolute paths.
6. Install or verify Docker/Compose inside the instance and initialize its private Docker state.
7. Start the existing Compose stack from the assigned ticket workspace using the existing stack configuration.
8. Validate service health, the private Docker daemon, the assigned IP, and each required inbound port from the host/lab route.
9. Record lifecycle state: ticket, Incus instance name, IP, workspace type, mounted paths, creation time, and stack status.

### Stop and start

Stop and start only the named Incus instance. Source worktrees remain mounted on the host and are never removed by these commands.

### Destroy `<TICKET>`

1. Stop the nested Compose stack and Incus instance.
2. Remove the Incus instance and its private root disk/Docker state.
3. Release or retain the recorded IP reservation according to the ticket lifecycle policy; retain it by default while the host worktree remains.
4. Leave the ticket root and shared bare Git repositories unchanged.
5. Offer a separate, explicit worktree cleanup action that delegates to the existing removal script only after confirmation.

## Workspace Types

The controller recognizes but does not recreate the following layouts:

| Type | Required host path | Typical content |
| --- | --- | --- |
| `single-repo` | `~/workspace/<user>/<TICKET>/<repo>` | one linked repository worktree |
| `harness` | `~/workspace/<user>/<TICKET>/` | multiple repository worktrees plus aggregate agent context |

For a harness sandbox, mount the entire ticket root once; this preserves the inter-repository layout and root-level context files. For a single-repository sandbox, mount the ticket root as well, not only the repository directory, so the layout has one consistent lifecycle model.

## Security and Operational Boundaries

- The design protects host-level Docker and unrelated service state from accidental dependency contamination. It does not claim to safely execute hostile arbitrary code.
- No sandbox gets `/var/run/docker.sock` from the host.
- No sandbox uses `--privileged` Docker-in-Docker.
- No sandbox uses host networking.
- The host firewall admits only the documented device-facing TCP ports from allowed lab/device networks.
- Database, messaging, GNS3 control, SSH, and Incus management endpoints remain private unless separately and explicitly required.
- Credentials are injected through an approved secret mechanism during implementation; they are not copied from existing shell aliases, private config files, or host home-directory state.

## Direct Docker Stack Bootstrap

Generic guest cloud-init installs and readies Docker plus the configured Docker
insecure-registry endpoints. It must not install, configure, start, or wait for
K3s, and it must not render K3s registry mirrors. The service builder defaults
`IMAGE_IMPORT=true` and gates its Docker-save and container-runtime import work
on that value, while the direct setup script uses Docker. A private stack-up
hook may therefore run a direct-Docker setup command with an explicit
`IMAGE_IMPORT=false` prefix. The controller transfers that hook on standard
input, not as an `incus exec` command-line argument, so private hook contents
are not emitted in controller command logs. Credentials remain outside hook
values and use the approved secret mechanism.

## Validation Criteria

The first prototype is successful only if all of the following are demonstrated with one ticket sandbox before scaling out:

1. Existing worktree scripts create or reuse the ticket workspace without layout changes.
2. Git commands run successfully inside the sandbox from the mounted worktree.
3. A commit on an agent-specific branch is visible from the host checkout and vice versa.
4. `docker ps` inside the sandbox shows only that sandbox's Docker resources.
5. Host `docker ps` does not show sandbox-inner resources, and the sandbox cannot control the host Docker daemon.
6. The existing dev stack starts from the mounted ticket workspace.
7. Each documented device-facing TCP port is reachable at the sandbox IP from the host and from the GNS3/device route.
8. A second sandbox starts with identical service port numbers on a distinct IP and does not conflict with the first.
9. CPU/memory/process limits constrain the complete nested Docker workload.
10. Destroying the sandbox removes private runtime state but leaves the ticket worktree and shared bare repositories intact.

The five-sandbox target is enabled only after observing the full-stack resource use of one sandbox and confirming headroom on the host.

## Future Extensions

These are intentionally deferred:

- K3s/Kubernetes as an optional heavier workload class, designed and enabled separately from the generic Docker bootstrap.
- CI agent registration and pipeline parameterization.
- GitOps control planes and application-configuration repository access.
- A workspace control plane above the Incus provider.
- VM profiles for workloads that require full VM behavior.
- DNS names for ticket sandboxes.
- Automated temporary-device credentials and per-lab firewall policies.
