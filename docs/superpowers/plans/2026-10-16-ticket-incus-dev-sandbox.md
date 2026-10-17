# Ticket-scoped Incus Development Sandbox Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a stow-managed `labctl` command that creates and manages ticket-scoped, routed Incus system-container development sandboxes while preserving the existing host Git worktree layout.

**Architecture:** A small Bash command-line tool reads a private local configuration file, persists ticket-to-instance/IP assignments locally, and invokes Incus through narrow adapter functions. A shared Incus profile and managed bridge provide nested Docker, resource limits, and per-ticket addresses; ticket worktrees and shared bare Git metadata are idmapped mounts at their existing absolute paths.

**Tech Stack:** Bash, Incus CLI, cloud-init, Docker Compose inside unprivileged Incus containers, `jq`, `flock`, GNU Stow, ShellCheck, shfmt, repository-local Bash test runner with mocked commands.

**Spec:** `docs/superpowers/specs/2026-10-16-ticket-incus-dev-sandbox-design.md`

## Global Constraints

- Preserve the host Git layout and absolute linked-worktree `.git` paths; never copy, rename, or rewrite worktrees.
- Support both single-repository and multi-repository harness ticket roots.
- Do not expose the host Docker socket, use host networking, or use privileged Docker-in-Docker.
- Use unprivileged Incus instances with `security.nesting=true`; fail preflight rather than making an instance privileged.
- Preserve existing LXD/Multipass services and resources: preflight name, subnet, bridge, storage, route, and instance conflicts; never migrate, stop, reconfigure, or delete them.
- Mount only the ticket root and shared bare-repository root, at the identical absolute paths used by the host, using idmapped mounts.
- Keep concrete host paths, addresses, ports, repository names, service commands, and credentials out of committed configuration and documentation examples.
- Keep the external device-facing TCP port contract unchanged on each sandbox’s unique routed IP.
- Initial concurrency target is five; do not authorize ten without recorded full-stack resource measurements.
- Destroying a sandbox removes private runtime state but leaves its source worktree and shared bare Git repositories intact.
- Use two-space indentation in Bash, quote variables, and pass `shellcheck` and `shfmt -d` for every changed shell file.

## Review Focus

- **Ticket/path traversal:** test that ticket normalization rejects separators, whitespace-only input, shell metacharacters, and values that escape the configured workspace root.
- **Shared Git safety:** test that create uses the existing ticket root and common bare-repository root at exactly configured paths and never issues a `git worktree prune`, `remove`, or `branch -D` command.
- **IP collisions and persistence:** test that reserved addresses are reused for the same ticket, never duplicated across active tickets, and remain unchanged after stop/start.
- **Destructive lifecycle:** test that destroy refuses without `--yes`, removes only the ticket’s Incus instance and state record, and never invokes the configured worktree cleanup hook unless an explicit separate cleanup command is used.
- **Network boundary:** test that validation checks only the configured device TCP ports against the sandbox IP and rejects a profile/instance that enables host networking, privileged mode, or a host Docker socket mount.

---

## File Structure

| Path | Responsibility |
| --- | --- |
| `incus/.local/bin/labctl` | Stowed CLI entry point and command dispatcher. |
| `incus/.local/lib/labctl/common.sh` | Logging, error handling, command prerequisites, ticket normalization, and confirmation helpers. |
| `incus/.local/lib/labctl/config.sh` | Loads and validates the private local configuration; exposes readonly configuration accessors. |
| `incus/.local/lib/labctl/state.sh` | Lock-protected JSON registry for ticket/instance/IP lifecycle state. |
| `incus/.local/lib/labctl/incus.sh` | All Incus CLI interactions: bridge, profile, instance, disk devices, exec, and inspection. |
| `incus/.local/lib/labctl/workspace.sh` | Ticket-root detection, workspace-type detection, mounted-path validation, and optional configured worktree hooks. |
| `incus/.local/lib/labctl/network.sh` | Device-port validation and local route/firewall preflight checks; no remote device configuration. |
| `incus/.local/lib/labctl/host-setup.sh` | Idempotent, sudo-required host bootstrap for the Incus bridge/profile only. |
| `incus/.local/share/labctl/cloud-init.yaml.tmpl` | Guest bootstrap template to install/start Docker and create the sandbox developer account without secrets. |
| `incus/.config/labctl/config.example.env` | Sanitized configuration template; never source it as the active configuration. |
| `incus/README.md` | Installation, private configuration, operator workflow, route/firewall prerequisites, recovery, and safe cleanup guidance. |
| `tests/incus/test_helper.sh` | Bash assertions, temporary directories, and fake `incus`, `docker`, `git`, `nc`, and hook commands. |
| `tests/incus/labctl_test.sh` | Black-box and library-level tests for parsing, state, create/stop/start/destroy behavior, and guardrails. |

## Task 1: Establish the stowed command package, private configuration contract, and test harness

**Files:**
- Create: `incus/.local/bin/labctl`
- Create: `incus/.local/lib/labctl/common.sh`
- Create: `incus/.local/lib/labctl/config.sh`
- Create: `incus/.local/lib/labctl/state.sh`
- Create: `incus/.config/labctl/config.example.env`
- Create: `tests/incus/test_helper.sh`
- Create: `tests/incus/labctl_test.sh`

**Interfaces:**
- Produces: `labctl <command> [args]`, with commands `help`, `preflight`, `status`, `create`, `start`, `stop`, `destroy`, and `cleanup-worktree`.
- Produces: `labctl_normalize_ticket(raw: string) -> normalized_ticket` and `labctl_state_*` functions using `${XDG_STATE_HOME:-$HOME/.local/state}/labctl/sandboxes.json`.
- Consumes: private `~/.config/labctl/config.env`, loaded only after strict ownership and readability checks.

- [ ] **Step 1: Write failing tests for ticket parsing, missing configuration, and registry allocation**

```bash
assert_fails labctl_normalize_ticket '../<ticket>'
assert_fails labctl_normalize_ticket '<ticket>;rm'
assert_equals '<ticket>' "$(labctl_normalize_ticket '<ticket>')"
assert_fails labctl config-load
assert_equals 'SANDBOX_IP_1' "$(labctl_state_reserve_ip '<ticket>')"
assert_equals 'SANDBOX_IP_1' "$(labctl_state_reserve_ip '<ticket>')"
assert_fails labctl_state_claim_ip '<ticket>-two' 'SANDBOX_IP_1'
```

- [ ] **Step 2: Run the test runner to verify it fails**

Run: `bash tests/incus/labctl_test.sh`

Expected: FAIL because `labctl`, parsing, configuration, and state functions do not exist.

- [ ] **Step 3: Add the sanitized configuration contract and common helpers**

Define exact required private configuration names in `config.example.env`:

```text
LABCTL_WORKSPACE_ROOT
LABCTL_MASTER_ROOT
LABCTL_AGENT_BRIDGE
LABCTL_AGENT_CIDR
LABCTL_AGENT_GATEWAY
LABCTL_IP_POOL_START
LABCTL_IP_POOL_END
LABCTL_LAB_ROUTE_GATEWAY
LABCTL_INSTANCE_IMAGE
LABCTL_INSTANCE_USER
LABCTL_DEVICE_TCP_PORTS
LABCTL_STACK_UP_COMMAND
LABCTL_STACK_DOWN_COMMAND
LABCTL_STACK_HEALTH_COMMAND
LABCTL_WORKTREE_CREATE_HOOK
LABCTL_WORKTREE_REMOVE_HOOK
LABCTL_HARNESS_REPO_NAMES
```

`config.sh` must reject placeholders, missing values, non-absolute workspace paths, a master root outside the workspace root, invalid IPv4 ranges, empty device-port lists, and active config files that are group- or world-writable. `common.sh` must use `set -euo pipefail`, provide quoted command execution, and normalize tickets only to lowercase letters, digits, and single hyphens.

- [ ] **Step 4: Implement lock-protected JSON state functions**

Implement `labctl_state_init`, `labctl_state_lookup(ticket)`, `labctl_state_reserve_ip(ticket)`, `labctl_state_record(ticket, instance, ip, workspace_type)`, and `labctl_state_remove(ticket)`. Use `flock` on a sibling lock file and atomic `jq` replacement through a temporary file. Store schema version, ticket, normalized instance name, assigned IP, workspace type, mount roots, timestamps, and lifecycle status. Allocation must scan the configured inclusive pool in ascending order and skip every IP currently recorded for another ticket.

- [ ] **Step 5: Implement the CLI skeleton**

`labctl` locates its stowed library directory without relying on the current directory, parses global `--config <path>` and `--dry-run`, prints deterministic usage, loads configuration only for commands that need it, and dispatches unimplemented lifecycle commands to explicit “not implemented” failures until their tasks land.

- [ ] **Step 6: Run unit tests and static checks**

Run:

```bash
bash tests/incus/labctl_test.sh
shellcheck incus/.local/bin/labctl incus/.local/lib/labctl/common.sh incus/.local/lib/labctl/config.sh incus/.local/lib/labctl/state.sh
shfmt -d incus/.local/bin/labctl incus/.local/lib/labctl/common.sh incus/.local/lib/labctl/config.sh incus/.local/lib/labctl/state.sh
```

Expected: all tests and linters pass.

- [ ] **Step 7: Commit**

```bash
git add incus tests/incus
git commit -m "incus: add labctl configuration and state foundation"
```

## Task 2: Add Incus host preflight, managed bridge, and safe profile provisioning

**Files:**
- Create: `incus/.local/lib/labctl/incus.sh`
- Create: `incus/.local/lib/labctl/host-setup.sh`
- Create: `incus/.local/share/labctl/cloud-init.yaml.tmpl`
- Modify: `incus/.local/bin/labctl`
- Modify: `tests/incus/labctl_test.sh`

**Interfaces:**
- Consumes: configuration and `labctl_state_*` from Task 1.
- Produces: `labctl_incus_preflight()`, `labctl_incus_setup_host()`, `labctl_incus_ensure_profile()`, `labctl_incus_launch(ticket, ip)`, and `labctl_incus_inspect(instance)`.
- Produces: `labctl preflight` and `labctl setup-host --yes` CLI commands.

- [ ] **Step 1: Write failing mocked-Incus tests for host setup and profile invariants**

```bash
assert_command_log_contains 'network create agentbr0'
assert_command_log_contains 'profile create agent-dev-env'
assert_command_log_contains 'security.nesting=true'
assert_command_log_not_contains 'security.privileged=true'
assert_command_log_not_contains '/var/run/docker.sock'
assert_fails labctl setup-host
assert_succeeds labctl setup-host --yes --dry-run
```

Add tests that preflight fails if `incus`, `jq`, `flock`, or `docker` is unavailable; if the logged-in user cannot use Incus; if the configured bridge overlaps an existing host, LXD, or Multipass route/bridge; if configured Incus storage, profile, or instance names collide with existing LXD/Multipass resources; or if the active profile resolves to privileged/host-network behavior.

- [ ] **Step 2: Run the test runner to verify host-setup tests fail**

Run: `bash tests/incus/labctl_test.sh`

Expected: FAIL because Incus adapter and host setup functions do not exist.

- [ ] **Step 3: Implement read-only preflight**

Implement `labctl_incus_preflight` to inventory existing LXD/Multipass services, bridges, storage pools, instances, and routes; validate commands, Incus daemon access, idmapped mount capability, available storage, configured agent-subnet non-overlap, the host forwarding setting, and the configured lab route gateway. It must report external-device static-route and firewall work as pending operator prerequisites, reject conflicts, and never modify or manage LXD/Multipass resources or host networking.

- [ ] **Step 4: Implement idempotent, confirmation-gated host setup**

`labctl setup-host --yes` must create or reconcile only the named Incus managed bridge and shared profile. The bridge uses the configured CIDR/gateway, DHCP/DNS, and outbound NAT. The profile uses `security.nesting=true`, configured CPU/memory/process limits, and no privileged mode, host networking, proxy devices, Docker socket, or broad device passthrough. The script must be idempotent and print every sudo-required operation before executing it.

- [ ] **Step 5: Add guest bootstrap template rendering**

Create a cloud-init template that installs Docker/Compose from the configured Ubuntu package source, configures only Docker insecure registries, enables Docker, creates the configured non-root sandbox user, and does not embed credentials, concrete ports, repository names, or application commands. It must not install, configure, start, wait for, or configure registry mirrors for K3s. Render the template to a restrictive temporary file during launch and delete it after successful instance creation.

- [ ] **Step 6: Run tests and static checks**

Run:

```bash
bash tests/incus/labctl_test.sh
shellcheck incus/.local/lib/labctl/incus.sh incus/.local/lib/labctl/host-setup.sh
shfmt -d incus/.local/lib/labctl/incus.sh incus/.local/lib/labctl/host-setup.sh
```

Expected: mocked command assertions and static checks pass.

- [ ] **Step 7: Commit**

```bash
git add incus/.local/bin/labctl incus/.local/lib/labctl incus/.local/share/labctl tests/incus
git commit -m "incus: add sandbox host and profile provisioning"
```

## Task 3: Implement workspace validation and ticket sandbox lifecycle

**Files:**
- Create: `incus/.local/lib/labctl/workspace.sh`
- Modify: `incus/.local/lib/labctl/incus.sh`
- Modify: `incus/.local/lib/labctl/state.sh`
- Modify: `incus/.local/bin/labctl`
- Modify: `tests/incus/labctl_test.sh`

**Interfaces:**
- Consumes: `labctl_incus_launch`, `labctl_state_*`, and active configuration from Tasks 1–2.
- Produces: `labctl_workspace_detect(ticket) -> single-repo|harness`, `labctl_workspace_validate(ticket)`, `labctl_create(ticket)`, `labctl_start(ticket)`, `labctl_stop(ticket)`, `labctl_destroy(ticket, yes)`, and `labctl_cleanup_worktree(ticket, yes)`.

- [ ] **Step 1: Write failing lifecycle tests against fake Incus and hook binaries**

```bash
assert_succeeds labctl create <ticket> --dry-run
assert_command_log_contains 'launch ... <ticket>'
assert_command_log_contains 'config device add <ticket> git-master disk'
assert_command_log_contains 'config device add <ticket> ticket-workspace disk'
assert_command_log_contains 'shift=true'
assert_succeeds labctl status <ticket>
assert_fails labctl destroy <ticket>
assert_succeeds labctl destroy <ticket> --yes --dry-run
assert_command_log_not_contains 'git worktree remove'
assert_command_log_not_contains 'git worktree prune'
assert_succeeds labctl cleanup-worktree <ticket> --yes --dry-run
assert_command_log_contains "$LABCTL_WORKTREE_REMOVE_HOOK <ticket>"
```

Include cases for: ticket root missing; ticket root outside workspace root; bare metadata root missing; an existing matching sandbox; an existing instance with a conflicting assigned IP; a harness root with all configured repositories; and a malformed partial harness root.

- [ ] **Step 2: Run the test runner to verify lifecycle tests fail**

Run: `bash tests/incus/labctl_test.sh`

Expected: FAIL because workspace and lifecycle functions do not exist.

- [ ] **Step 3: Implement workspace detection and safe hook execution**

`workspace.sh` must derive the ticket root only as `${LABCTL_WORKSPACE_ROOT}/${normalized_ticket_in_configured_case}` after verifying it remains under the configured root. A workspace is `harness` only when every configured harness repository directory exists; it is `single-repo` only when the caller supplies a configured repository selector or exactly one valid linked worktree exists. For absent roots, `create --ensure-worktree` may invoke the configured creation hook with a strictly quoted ticket argument; otherwise it must fail with the existing-worktree prerequisite.

- [ ] **Step 4: Implement launch and exact-path disk mounts**

`labctl_create` must reserve/reuse the state IP, launch an unprivileged profile-based instance, wait for cloud-init/Docker readiness, and attach exactly two writable idmapped disk devices:

```text
master root  -> same absolute path inside the instance
ticket root  -> same absolute path inside the instance
```

Before mounting, validate the ticket root contains linked-worktree `.git` files whose `gitdir:` paths begin under the configured master root. Do not rewrite any `.git` file. Configure only the mounted ticket root as the sandbox user’s Git `safe.directory` if Git requires it.

- [ ] **Step 5: Implement start, stop, status, destroy, and separate cleanup**

- `start` starts the existing instance and runs the configured stack-up command only after Docker is healthy.
- `stop` runs the configured stack-down command and stops the instance without touching state or worktrees.
- `status` combines the registry record, Incus status, assigned IP, mount validation, and nested Docker status.
- `destroy --yes` removes the instance and private runtime state, updates the registry lifecycle state, and preserves host worktrees and the IP reservation by default.
- `cleanup-worktree --yes` is a separate command; it requires no running instance and delegates only to the configured host worktree-removal hook.

Every destructive command must support `--dry-run` and print its exact target instance and ticket before execution.

- [ ] **Step 6: Run lifecycle tests and static checks**

Run:

```bash
bash tests/incus/labctl_test.sh
shellcheck incus/.local/bin/labctl incus/.local/lib/labctl/*.sh
shfmt -d incus/.local/bin/labctl incus/.local/lib/labctl/*.sh
```

Expected: all fake-command lifecycle tests and static checks pass.

- [ ] **Step 7: Commit**

```bash
git add incus/.local/bin/labctl incus/.local/lib/labctl tests/incus
git commit -m "incus: add ticket sandbox lifecycle commands"
```

## Task 4: Add stack execution, device-port verification, and two-sandbox isolation checks

**Files:**
- Create: `incus/.local/lib/labctl/network.sh`
- Modify: `incus/.local/bin/labctl`
- Modify: `incus/.local/lib/labctl/incus.sh`
- Modify: `tests/incus/labctl_test.sh`

**Interfaces:**
- Consumes: lifecycle functions from Task 3 and `LABCTL_DEVICE_TCP_PORTS`, `LABCTL_STACK_UP_COMMAND`, `LABCTL_STACK_DOWN_COMMAND`, and `LABCTL_STACK_HEALTH_COMMAND` from configuration.
- Produces: `labctl_stack_up(ticket)`, `labctl_stack_down(ticket)`, `labctl_verify_ports(ticket)`, and `labctl verify ticket`.

- [ ] **Step 1: Write failing tests for port validation and forbidden runtime conditions**

```bash
assert_succeeds labctl verify <ticket> --dry-run
assert_command_log_contains 'nc -z -w 3 SANDBOX_IP PORT_A'
assert_command_log_contains 'nc -z -w 3 SANDBOX_IP PORT_B'
assert_fails labctl_verify_ports_when_closed 'PORT_A'
assert_fails labctl verify <ticket> --host-network-detected
assert_fails labctl verify <ticket> --host-docker-socket-detected
```

Add a mocked two-ticket case in which both sandboxes use the same configured device-port list on different assigned IPs. Assert that no host port proxy device is created and that each check targets its sandbox IP.

- [ ] **Step 2: Run the test runner to verify network tests fail**

Run: `bash tests/incus/labctl_test.sh`

Expected: FAIL because stack and network verification functions do not exist.

- [ ] **Step 3: Implement trusted local stack hooks**

Run configured stack commands only through `incus exec <instance> -- bash -s` after validating instance state and workspace mount paths. Transfer hook text on standard input rather than as an `incus exec` argument so it is absent from controller command logs. Document that the service builder defaults `IMAGE_IMPORT=true` and gates Docker-save/container-runtime import work on it, while direct setup uses Docker; direct-Docker private setup may therefore explicitly prefix its command with `IMAGE_IMPORT=false`. Commands live solely in private active configuration, must use the mounted ticket root, and must not contain credentials, application identifiers, repository names, or ports in the stowed package. K3s is deferred optional scope.

- [ ] **Step 4: Implement device-port and isolation verification**

`labctl verify <ticket>` must:

1. inspect the Incus profile/instance configuration for `security.privileged`, host networking, host Docker socket devices, and proxy devices;
2. verify the nested Docker daemon responds only inside the target instance;
3. execute the configured health hook;
4. probe each configured TCP port at the sandbox’s assigned IP from the host using `nc` with a fixed timeout;
5. report external GNS3/device route verification as a separate manual check until an approved probe path exists.

- [ ] **Step 5: Perform a manual first-lab acceptance run**

Run, with a real non-sensitive ticket workspace and approved local private configuration:

```bash
stow -d "$HOME/.stowed" incus
labctl preflight
labctl setup-host --yes
labctl create <ticket>
labctl verify <ticket>
labctl status <ticket>
```

Expected: Git works from the mounted workspace; nested Docker sees only its own resources; each configured device TCP port answers at the sandbox IP; the host Docker daemon remains inaccessible from the sandbox.

- [ ] **Step 6: Perform a manual two-sandbox port-collision acceptance run**

Create a second non-sensitive ticket sandbox, start the same stack, and verify the same configured TCP ports succeed at both distinct sandbox addresses. Record peak CPU/RAM/Docker-disk usage for both labs and update the default quota only if measurements justify it.

- [ ] **Step 7: Run complete automated checks**

Run:

```bash
bash tests/incus/labctl_test.sh
shellcheck incus/.local/bin/labctl incus/.local/lib/labctl/*.sh
shfmt -d incus/.local/bin/labctl incus/.local/lib/labctl/*.sh
```

Expected: all automated checks pass before considering the five-sandbox rollout.

- [ ] **Step 8: Commit**

```bash
git add incus/.local/bin/labctl incus/.local/lib/labctl tests/incus
git commit -m "incus: verify ticket sandbox network isolation"
```

## Task 5: Document installation, safety boundaries, recovery, and the measured rollout gate

**Files:**
- Create: `incus/README.md`
- Modify: `README.md`
- Modify: `tests/incus/labctl_test.sh`

**Interfaces:**
- Consumes: final `labctl` commands from Tasks 1–4.
- Produces: reproducible operator documentation for stowing/configuring/running `labctl` without committing private topology or credentials.

- [ ] **Step 1: Write a failing documentation-contract test**

Add a test that asserts `incus/README.md` contains all public commands (`preflight`, `setup-host`, `create`, `start`, `stop`, `status`, `verify`, `destroy`, `cleanup-worktree`), calls out `--yes`/`--dry-run`, and contains no concrete host path, ticket ID, repository name, IP address, port number, credential, or private service identifier.

- [ ] **Step 2: Run the test runner to verify the documentation test fails**

Run: `bash tests/incus/labctl_test.sh`

Expected: FAIL because `incus/README.md` and its command/sanitization content do not exist.

- [ ] **Step 3: Write operator documentation**

Document:

- stowing the `incus` package and copying the example configuration to the private active path;
- exact required local dependencies and least-privilege Incus group membership;
- the required manual static route and firewall prerequisites;
- the unprivileged nested-Docker proof before real ticket creation;
- single-repository and harness workspace behavior;
- preservation of existing worktree scripts and shared metadata;
- state-file backup and recovery behavior;
- stop versus destroy versus separate worktree cleanup;
- the five-sandbox limit and resource-measurement gate;
- the deferred K3s/Kubernetes/CI/GitOps scope and the direct-Docker `IMAGE_IMPORT=false` private-hook pattern.

Update the root README’s optional-tools section with a one-line pointer to the Incus package and its README; do not add environment-specific values.

- [ ] **Step 4: Run documentation, test, and static checks**

Run:

```bash
bash tests/incus/labctl_test.sh
shellcheck incus/.local/bin/labctl incus/.local/lib/labctl/*.sh
shfmt -d incus/.local/bin/labctl incus/.local/lib/labctl/*.sh
git diff --check
```

Expected: all checks pass and the documentation contains only generic placeholders.

- [ ] **Step 5: Commit**

```bash
git add incus README.md tests/incus
git commit -m "docs: document ticket Incus development sandboxes"
```

## Self-Review

### Spec coverage

- Ticket-named Incus sandboxes and both worktree forms: Tasks 1 and 3.
- Preservation of existing shared bare repositories and absolute `.git` paths: Task 3.
- Private nested Docker and no host socket/privileged mode: Tasks 2–4.
- Persistent routed addresses, bridge, and unchanged per-IP port behavior: Tasks 1, 2, and 4.
- Resource limits and five-before-ten measurement gate: Tasks 2 and 4.
- Explicit lifecycle preserving source worktrees: Task 3.
- Sanitized committed configuration/documentation: Tasks 1 and 5.

No spec requirement is unowned.

### Type and interface consistency

All lifecycle commands are dispatched by `labctl`, state is owned only by `state.sh`, all Incus CLI calls are confined to `incus.sh`, and workspace inspection/hook handling is confined to `workspace.sh`. Later tasks consume the exact `labctl_*` interfaces defined by earlier tasks.

### Review focus coverage

- Ticket/path traversal: Task 1 tests.
- Shared Git safety: Task 3 tests.
- IP collision/persistence: Task 1 and Task 3 tests.
- Destructive lifecycle: Task 3 tests.
- Network boundary: Task 2 and Task 4 tests.

### Proportion

The plan specifies interfaces, files, tests, commands, and invariants but leaves the shell-function bodies to the implementer. It does not prescribe private topology, service commands, credentials, concrete ports, or repository identities.
