# Sandbox external exposure (Herdr Plus)

**Sandbox: Exposure** gives a named sandbox a DHCP-backed, lab-facing IPv4
address without requiring lab devices to route to its private bridge subnet.
It creates a bridge-mode macvlan `xiqfwdN` on an explicitly selected lab NIC,
then creates an Incus network forward from that address to the supplied sandbox
IPv4 address. Create never adopts pre-existing resources. A separate, confirmed
**Adopt** operation can migrate the narrowly supported legacy setup below.

## Install and launch

On the laptop where this action was developed, the four helper symlinks are
already installed and the quick-action configuration is already visible through
an existing Stow-managed directory. No restow or network mutation is needed.

For a clean installation from the dotfiles checkout:

```bash
stow -d "$HOME/.stowed" -R herdr
```

If Stow reports an unrelated existing-link conflict, do not use `--adopt` or
force-overwrite it. This laptop's dry-run reports such a conflict for the
pre-existing `nvo-review.sh`; it was left alone. Install only the new helper
links if needed, without replacing existing files.

Installation makes the quick action and helpers available; it does **not** create an exposure.
Open Herdr Plus's quick-actions picker and choose **Sandbox: Exposure**. Enter
`list` to show all exposures directly, without supplying an interface name.
Alternatively, enter an interface name such as `xiqfwd1`. A focused sibling pane
offers create, update, delete, status, list, and **6) Adopt existing legacy exposure**.
To skip the menu, enter the interface followed by an operation, for example
`xiqfwd0 update` or `xiqfwd0 status`. Supported operations are `create`, `update`,
`delete`, `status`, `list`, and `adopt`. Update still prompts for target/ports;
backend validation and confirmation are unchanged. The result pane remains open
for inspection. If the picker was already open, close and reopen it to reload actions.

Files:

- `herdr/.config/herdr/plugins/config/cloudmanic.herdr-plus/quick-actions/sandbox-exposure.toml`
- `herdr/.config/herdr-spreader/sandbox-exposure.sh` — validated pane launcher
- `herdr/.config/herdr-spreader/sandbox-exposure-dialog.sh` — interactive menu
- `herdr/.config/herdr-spreader/sandbox-exposure.py` — controller/CLI
- `herdr/.config/herdr-spreader/sandbox-exposure-dhcp.py` — isolated DHCP hook
- `herdr/.config/herdr-spreader/sandbox-exposure-apparmor.conf` — scoped AppArmor extension

Requires Linux, Python 3.10+, `ip`, `sysctl`, ISC `dhclient`, a local Incus daemon
supporting network forwards, and `sudo`. The Herdr launcher also needs `herdr`
and `jq`. DHCP must permit another MAC on the chosen physical NIC; switch port
security, Wi-Fi, or exhausted DHCP pools can prevent this.

The controller uses root privileges for the macvlan, DHCP process, and protected
state. The dialog invokes `sudo -- python3 ...`; normal sudo authentication and
policy apply. No credentials, passwordless sudo rules, or group changes are
installed. Review these scripts as privileged code before granting elevation.
Incus is always `--force-local` with an explicit **network project** (default
`default`), not necessarily the project containing the sandbox instance.

## AppArmor prerequisite on Ubuntu/Debian

If `dhclient` is confined by an enforcing AppArmor profile, its default policy
does not permit the exposure's protected config, PID/lease files or custom hook.
Install the reviewed extension **before create/adopt/delete**; the controller
checks for the matching installed policy and loaded enforcing child profile
before those actions. This detects this integration requirement, not every
possible host-security or network failure.

```bash
# Review the existing destination first; do not overwrite unrelated local policy.
sudo install -o root -g root -m 0644 \
  "$HOME/.stowed/herdr/.config/herdr-spreader/sandbox-exposure-apparmor.conf" \
  /etc/apparmor.d/local/herdr-sandbox-exposure

# Preserve existing local rules and add this include exactly once using sudoedit:
#   #include <local/herdr-sandbox-exposure>
sudoedit /etc/apparmor.d/local/sbin.dhclient

# Compile without loading, then reload only this policy file (not all AppArmor).
sudo apparmor_parser -Q -K /etc/apparmor.d/sbin.dhclient
sudo apparmor_parser -r -T /etc/apparmor.d/sbin.dhclient
```

AppArmor remains enforcing. The daemon gets file access only for the named
exposure config/PID/leases. Its hook transitions into the separate enforcing
`herdr-exposure-hook-v1` child profile, which permits the system Python/IP tools,
netlink operations and the exposure ACK file, plus standard base/Python read
permissions. There is no unconfined execution transition. Both `/usr/bin/ip`
and `/usr/sbin/ip` locations are supported, including usr-merged symlinks.

If adoption previously stopped with missing PID/ACK files, inspect the kernel
journal for AppArmor denials and the exact running client identity. Do not invent
PID/lease/ACK files or start a duplicate client. Recovery of a partially started
client requires operator-approved, identity-checked stopping without lease
release; take care that its STOP hook does not remove the preserved address.
Then resume the same adopt command and require a genuine DHCP ACK.

## Direct CLI

Before Stowing, substitute the checkout path
`$HOME/.stowed/herdr/.config/herdr-spreader/sandbox-exposure.py` below.

```bash
controller="$HOME/.config/herdr-spreader/sandbox-exposure.py"

# Read-only; list includes unowned xiqfwdN interfaces and their existing forwards.
sudo -- python3 "$controller" list
sudo -- python3 "$controller" status xiqfwd1

# Examples only: choose a FREE interface name, actual lab NIC, and sandbox IP.
# Full exposure is deliberately explicit: --ports is mandatory for create.
sudo -- python3 "$controller" create xiqfwd1 \
  --parent LAB_NIC --network agentbr0 --project default \
  --target 10.77.10.20 --ports all

# Retarget while preserving the previous port policy (asks for confirmation).
sudo -- python3 "$controller" update xiqfwd1 --target 10.77.10.21

# Restrict forwarded traffic, preserving the target (also asks for confirmation).
sudo -- python3 "$controller" update xiqfwd1 --ports tcp:443,udp:5000-5002

# Change target and ports together, or explicitly restore all-port forwarding.
sudo -- python3 "$controller" update xiqfwd1 \
  --target 10.77.10.21 --ports tcp:443,udp:5000-5002
sudo -- python3 "$controller" update xiqfwd1 --ports all

# Deletes the owned forward, releases its DHCP lease, then removes the macvlan.
sudo -- python3 "$controller" delete xiqfwd1
```

**Do not use these mutation examples on a live name without operator approval.**
Unmanaged interfaces, including legacy `xiqfwd0`, are still refused by create,
update and delete. Use explicit adoption below; there is no force-delete option.

Port syntax is `all` or comma-separated `tcp:PORT`, `udp:PORT`,
`tcp:FIRST-LAST`, `udp:FIRST-LAST`. Ports must be 1–65535; overlapping ranges
for the same protocol are rejected. The same port may be listed once for TCP
and once for UDP. Listen and target ports are identical; port remapping is not
supported. Omitting `--ports` during update preserves the existing policy.
Restricted mode removes the default `target_address` entirely and supplies only
explicit protocol/port rules. Full mode forwards all supported IP traffic,
not just TCP/UDP services.

Adoption, delete and any target/port-policy change require typing **yes** on the controlling
TTY after seeing the named resource and planned change. EOF, any other answer,
or no controlling TTY cancels. There is no `--yes` bypass. Repeating an already
applied update performs no network mutation or additional confirmation.

## Adopt an existing legacy exposure

Choose `xiqfwd0` in the quick action, then **6) Adopt**. Supply the existing
parent NIC, bridge/network project, target IP, port policy and verified legacy
DHCP PID. These are expectations to validate, not instructions to retarget.
The CLI equivalent is:

```bash
# Replace each placeholder with verified live values; the PID is not permanent.
sudo -- python3 "$controller" adopt xiqfwd0 \
  --parent LAB_NIC --network agentbr0 --project default \
  --target SANDBOX_IP --ports all --legacy-dhcp-pid VERIFIED_PID
```

Adoption currently supports only an unmarked bridge-mode macvlan with exactly
one IPv4 address and one unmarked forward matching the supplied target/ports.
Its single legacy client must be root-owned system `dhclient` in the host's
network namespace, using `-lf /run/xiqfwd/lease -pf /run/xiqfwd/pid -sf /bin/true`
with optional `-v` and only the selected interface. Other DHCP clients, custom
forward descriptions/options, foreign aliases, or duplicate clients are refused.
Linux pidfd support is required to stop only the verified process identity.

After confirmation, the controller records recovery expectations, marks the
existing interface and forward, and stops the legacy client **without releasing
its lease**. It preserves the interface/MAC, address, connected route, target and
ports. A dedicated client requests the same address; the protected hook must
acknowledge that exact lease before the record becomes `ready`. No old lease
file is required. A different offer or changed subnet mask is refused, not
installed. The adopted client's address stays pinned to prevent silent migration.
Adoption does not change IPv6 settings on the existing interface.

**A DHCP handoff is not a guarantee of uninterrupted service.** The server must
acknowledge the requested lease. Failure retains `adopting` state and the original
address/forward where possible; after the legacy client stops, renewal may be
unavailable until recovery succeeds. Repeat the exact adopt command to resume
safe stages. A running managed client without a valid ACK requires inspection
rather than starting another client. Create, update and delete refuse incomplete
adoption. Do not remove the record or invent ownership markers to bypass this.

## Ownership, state, and recovery

State is under `/var/lib/herdr-sandbox-exposure`, root-owned and not
user-writable. Each record contains a random ownership token shared by the
interface alias and Incus forward description, plus the expected MAC, parent,
address, network project, and applied/pending forward payloads. Symlinks and
unsafe permissions are rejected. A nonblocking lock serializes mutations;
read-only status uses atomically replaced records. Root is required for
list/status after protected records exist.

- **Repeat create with identical arguments:** no-op when healthy; completes a
  partially created owned exposure. Different arguments require update or
  delete/recreate. Create never silently retargets an existing exposure.
- **Interrupted/failed create:** retains the record and any owned partial
  resources for inspection. Repeat the same create, or delete that owned name
  with confirmation. Failure is not a reason to remove unrelated resources.
- **Interrupted update:** the pending payload is recorded before the atomic
  Incus edit. Repeat the same update to finish reconciliation, or explicitly
  choose another policy. Status shows a pending operation as degraded.
- **Interrupted delete:** retains ownership state. Repeat delete to finish.
  A forward-delete failure stops before DHCP/interface cleanup; a DHCP-release
  failure keeps the macvlan and record. A missing owned interface does not
  prevent removing its still-owned forward or releasing a recorded lease.
- **Outside modifications:** unexpected interface identity or forward payload
  changes cause a refusal, even if the name matches. Inspect manually; do not
  erase ownership state or edit markers to force adoption.
- **DHCP:** uses dedicated per-name PID, lease, config, and copied hook files.
  PID reuse by an unrelated process blocks DHCP signaling. A live dedicated
  client blocks duplicate acquisition. The hook changes only addresses on the
  token-marked interface; it does not run distro hooks, change host DNS, add
  default/connected-subnet routes, or flush unrelated addresses. Adoption preserves
  an existing address/route on matching renewals. IPv6 is disabled on newly created
  macvlans before bringing them up; adopted interfaces and other interfaces are untouched.
- **Lease changes/expiry/reboot:** no automatic forward migration or restoration.
  Expired lease addresses are removed by the DHCP hook. A new lease address or
  missing interface is reported as degraded, and update refuses. Inspect status,
  delete the owned exposure, then recreate explicitly. Interfaces are ephemeral;
  Incus forwards and ownership records survive reboot. No boot service is added.

Status is JSON, not an end-to-end reachability probe. It reports live interface
addresses, ownership, expected target/ports, missing resources, pending changes,
and forward drift. It does not prove DHCP renewal health, remote device routing,
firewall acceptance, or that a sandbox service is listening. Confirm reachability
from the intended external/proxy device after an approved live operation.

**Port restriction is a forwarding policy, not a host firewall.** Unmatched
traffic is not forwarded to the sandbox, but host services bound to wildcard
addresses may still be reachable on the leased host address. This action does
not change firewall rules or globally enable forwarding. Review host firewall
policy and sandbox authentication before exposing services. Traffic routing,
DHCP, and host/bridge forwarding must already be approved and functional.

## Sandbox-keyed desired config and HOST-side CONNECT proxy

The guest proxy workaround is superseded; no proxy is installed in the guest.
The tracked desired config is `herdr/.config/herdr-spreader/sandbox-exposures.json`,
linked at `~/.config/herdr-spreader/sandbox-exposures.json`.

```json
{
  "schema_version": 1,
  "id": "lab-sandbox-exposures",
  "sandboxes": {
    "emulator-11": {
      "interface": "xiqfwd0",
      "parent": "enp0s31f6",
      "network": "agentbr0",
      "project": "default",
      "target": "10.77.10.14",
      "ports": "all",
      "expected_address": "134.141.48.97",
      "proxy": {
        "enabled": true,
        "listen_port": 3128,
        "client_cidrs": ["10.64.195.0/24"],
        "target_ports": [443],
        "allow_host_probe": true
      }
    }
  }
}
```

`id` is a stable ownership namespace, **not** the filename. Sandbox keys must
be lowercase names containing letters, digits and hyphens. Interfaces, private
targets and supplied expected lab addresses must be unique. Each interface has
its own MAC/DHCP lease, forwarding target, systemd proxy and owned nft table.
Duplicate live interface addresses/MACs are refused, including collisions with
parent/shared host addresses. Switch port-security/MAC limits can still prevent
adding a second macvlan.

```bash
controller="$HOME/.config/herdr-spreader/sandbox-exposure.py"
config="$HOME/.config/herdr-spreader/sandbox-exposures.json"

# Create or reconcile the named sandbox, adopting its existing managed interface
# and matching owned proxy if present. Identical repeats do not restart it.
sudo python3 "$controller" apply --config "$config" --sandbox emulator-11
sudo python3 "$controller" status emulator-11

# Prefer editing target/ports/proxy settings in the desired config and reapplying.
# Direct updates also reconcile an enabled proxy's target automatically:
sudo python3 "$controller" update emulator-11 --target NEW_PRIVATE_IPV4

# Explicit deletion removes only this sandbox's owned proxy, NAT exception,
# Incus forward, DHCP state and interface (normal TTY yes confirmation applies).
sudo python3 "$controller" delete emulator-11

# After removing an entry from this file, explicitly prune this config id's
# omitted sandboxes. Another config id's resources are never pruned.
sudo python3 "$controller" apply --config "$config" --prune
```

Create/update/delete/adopt converge through the existing network manager. A
matching already-managed interface is adopted into the sandbox/config namespace
without replacing it; a different owner is refused. For an unmanaged legacy
interface, add `legacy_dhcp_pid` with the verified PID and matching target/ports
and run apply: this uses the existing confirmed adoption checks. Keep the saved
legacy PID until adoption finishes; it is historical afterward. Parent/network/
project changes require explicit delete/recreate. Network target/port changes
and removals retain their existing controlling-TTY confirmation.

To add a **second** sandbox, add a second `sandboxes` member (for example
`emulator-12`) with an unused `interface: xiqfwd1`, the actual private target IP,
`parent`, `network`, `project`, `ports` and the same proxy object. Do not copy
`.97` as its expected address. Omit `expected_address` to accept a DHCP-assigned
unique lab IP, or supply its known DHCP-reserved address as an assertion. It is
not a static-IP assignment setting. Then run:

```bash
sudo python3 "$controller" apply --config "$config" --sandbox emulator-12
sudo python3 "$controller" status emulator-12
```

The proxy binds **only that exposure's lab IPv4:3128**, never a wildcard. Its
CONNECT destination is only that exposure's private target on 443; optional
`target_ports: [80,443]` permits CONNECT to port 80 too, but this is not a plain
HTTP GET proxy. Other methods/destinations/ports are denied. Client access is
limited to `client_cidrs`; the optional `allow_host_probe` permits only the
listener's own source IP for local verification, not arbitrary local clients.
It does not log TLS data, credentials, request headers or bodies. The unit runs
as a dedicated systemd dynamic user with no capabilities and system/home
protection. Existing tunnels are disconnected on a proxy update/restart.

An exact-public-IP **TCP3128** identity-DNAT at priority -110 establishes the
host-local NAT binding before Incus priority -100. Its separate owned table does
not alter Incus-managed rules, shared Docker proxies, other destination IPs,
UDP3128, or other service ports. Incus continues to manage each sandbox's normal
forwarding and target-specific hairpin masquerade. This is necessary because an
accept/return in a separate earlier chain would not stop a later DNAT hook.
Kernel-network-namespace tests verify the precedence and two-instance isolation.

For emulator-11 the owned resources are:
- `herdr-sandbox-exposure-proxy-emulator-11.service` on the **host**;
- `/var/lib/herdr-sandbox-exposure/xiqfwd0.proxy/{owner.json,config.json,server.py}`;
- nft table `ip herdr_sandbox_exposure_emulator_11_proxy`, with the same ownership
  marker as the macvlan and Incus forward.

```bash
systemctl status herdr-sandbox-exposure-proxy-emulator-11.service
journalctl -u herdr-sandbox-exposure-proxy-emulator-11.service
sudo nft list table ip herdr_sandbox_exposure_emulator_11_proxy
```

Omit the proxy object (or set `enabled: false`) and apply to remove only its
owned service/files/NAT exception while retaining the sandbox exposure. A
partial reconcile leaves `proxy_pending` and status `degraded`; retry apply
rather than changing ownership markers. No unrelated listener is adopted.
An unmanaged reserved service/unit/table is a hard conflict, not a reason to
force-delete it. Keep the desired config in sync after a direct CLI update;
otherwise the next apply requests reverting to the config's target.

No new boot network-recreation service is installed: macvlans remain ephemeral,
so after a host reboot follow the existing exposure recovery procedure and
reapply to restore the optional nft exception. systemd units are enabled but
skip startup when their macvlan is absent. Status is not proof of end-to-end DT
or Kafka health. The legacy EMULATOR-10 helpers are neither managed nor changed
by this config.

## Tests

All exposure lifecycle tests use mocked commands; they never create, retarget,
or delete live networking:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 tests/herdr/sandbox_exposure_test.py
PYTHONDONTWRITEBYTECODE=1 python3 tests/herdr/sandbox_exposure_apparmor_test.py
PYTHONDONTWRITEBYTECODE=1 python3 tests/herdr/sandbox_host_proxy_test.py
PYTHONDONTWRITEBYTECODE=1 python3 tests/herdr/sandbox_exposure_config_test.py
# Root is only for a NEW isolated netns; never edits host nft/network state:
sudo python3 -B tests/herdr/sandbox_proxy_nat_test.py
bash tests/herdr/sandbox-exposure_test.sh
shellcheck herdr/.config/herdr-spreader/sandbox-exposure{,-dialog}.sh \
  tests/herdr/sandbox-exposure_test.sh
```
