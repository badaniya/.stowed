# Task 4 Report

## Status

Implemented Task 4 with fake/dry-run coverage only. No Incus resources, host setup, stacks, ports, routing/firewall, sudo, LXD, or Multipass were touched.

## Commit

`269b7aec incus: verify ticket sandbox network isolation`

## Verification

Passed after the commit:

```text
bash tests/incus/labctl_test.sh
shellcheck incus/.local/bin/labctl incus/.local/lib/labctl/*.sh
shfmt -d incus/.local/bin/labctl incus/.local/lib/labctl/*.sh
```

The test suite uses fake `incus`, `docker`, and `nc` commands. It covers trusted in-instance stack hooks, configured TCP-port checks at each assigned sandbox IP, a closed-port failure, profile/instance isolation rejection for privileged mode, host networking, host Docker socket, and proxy devices, and two-ticket same-port checks on distinct IPs.

## Concerns

- The required real-lab and two-sandbox acceptance runs were intentionally not performed per task constraints.
- External GNS3/device-route verification remains explicitly reported as a manual check until an approved probe path exists.
- Stack hook values remain generic trusted private configuration; no concrete repository, port, credential, or stack command details were added to the stowed package.

## Incus 6 runtime-isolation inspection compatibility follow-up

### Changes

- Runtime state, workspace-mount, and isolation inspection now share the validated `incus query /1.0/instances/<name>` helper rather than formatted `incus info` or `incus config show` commands.
- The successful isolation regression runs `labctl verify` against a fake that rejects every affected formatted inspection command. It verifies the required idmapped disk mounts and profile policy from the API response, preserving fail-closed behavior when the query or validation fails.

### Red-green regression

**Red:** the Incus 6 fake rejected the previous formatted inspection command, causing verification to fail before workspace/isolation checks and leaving no instance API query in the command log.

**Green:** `labctl verify` obtains running state, mount configuration, and isolation configuration from `/1.0/instances/jira-%23`; it succeeds while the test rejects the legacy format commands.

No real Incus command, instance, profile, mount, network, route, firewall, Docker service, or stack was accessed or changed.
