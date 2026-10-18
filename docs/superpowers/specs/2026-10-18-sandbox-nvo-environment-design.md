# Sandbox NVO Environment Delivery Design

## Intent

Provide ticket sandbox Bash and future Zsh sessions with the NVO/XIQ development environment currently maintained in the host-private Bash profile, without sourcing host shell configuration, exposing secrets in tracked files, or copying host-only network values into the routed Incus guest.

This design also supplies a sandbox-safe XIQ emulator thread-pool value so the emulator can start within the guest resource limits.

## Constraints

- Do not source, `eval`, or otherwise execute the host private profile.
- Do not commit any environment value, token, credential path/content, registry endpoint, or host address.
- Do not import non-NVO profile sections, shell aliases/functions, tool-manager initialization, host PATH changes, or unrelated credentials.
- Preserve the existing unprivileged, routed Incus sandbox isolation model.
- Use native Incus systemd credentials for sensitive values and files.
- The generated file must work for Bash now and Zsh when Zsh support is added later.

## Approved Variable Policy

`labctl` parses only the `NVO Development` section of the configured owner-only profile source. It accepts a fixed allowlist of exported names; unknown, duplicate, malformed, command-substitution, or unsupported expansion entries fail closed.

### Guest-rewritten values

The sandbox writes its own routed IPv4 address to:

```text
XIQ_HOST_IP
XIQ_MessageBusHost
XIQ_HiveMiddlewareHost
XIQ_GrpcCommonServiceHost
XIQ_GrpcHmwebHost
CapWap_GrpcHost
```

`ApplicationName` is rebuilt in the guest using the sandbox user, sandbox hostname, and routed guest IP. It never retains host identity or host external address data.

### Preserved non-sensitive NVO values

The allowlist covers NVO runtime and service behavior including:

```text
GOPRIVATE
NVO_MessageBusHost
NVO_MessageBusPort
XIQ_MessageBusPort
XIQ_HiveMiddlewarePort
XIQ_GrpcCommonServicePort
XIQ_GrpcHmwebPort
CapWap_GrpcPort
PeriodicDiscoveryInMinutes
XiqGrpcGetDevicesPerPageLimit
DBAUTOMIGRATE
DBLOGLEVEL
EnableWirelessDeviceOnboardingAndKafkaMessaging
IMAGE_IMPORT
```

`IMAGE_IMPORT` remains false in the sandbox, preventing K3s image-import attempts.

### Sensitive values

`NVO_UI_TOKEN` and the contents referenced by `NVO_CREDENTIAL_FILE` are not placed in the normal environment file. They are delivered through separate Incus credentials and installed guest-side as mode-`0600`, sandbox-user-owned private files. The normal environment file contains only a private file path reference where application tooling requires one.

### XIQ thread pool

The normal generated environment contains:

```text
XIQ_THREAD_POOL=100
```

The GoDCApp development Makefile reads this variable through a configurable `XIQ_THREAD_POOL ?= 1000` default and passes it to the emulator command. Existing non-sandbox users retain the default 1000-thread behavior; sandbox stage configuration invokes the target with `XIQ_THREAD_POOL=100` sourced from the generated environment.

## Delivery Architecture

1. `LABCTL_NVO_ENV_SOURCE_PATH` identifies an absolute, owner-only host profile file.
2. `labctl nvo-env sync TICKET` parses the NVO section, validates allowed literal values, rewrites guest-bound hosts, renders a portable `KEY=VALUE` environment file, and delivers it through an Incus systemd credential.
3. The guest installs it at a private path under the configured sandbox user’s home directory with mode `0600`.
4. Guest `.bashrc` sources the file when present. The later Zsh setup sources the same POSIX-compatible file.
5. The sandbox bootstrap syncs NVO environment delivery after instance creation and before shared/application stages, so every stage runs with the same environment.
6. Application stage execution sources the generated environment before running the configured private hook.

## Validation

- Parser tests cover allowed values, rejected unknown/malformed/duplicate entries, and host-value rewriting without reading real private data.
- Rendered environment tests verify no host address or token is emitted.
- Credential tests verify owner/mode/path handling and no credential data appears in command output or `labctl status`.
- GoDCApp Makefile tests verify default compatibility and `XIQ_THREAD_POOL` override propagation.
- Live validation checks the guest environment file permissions, shell visibility of safe variables, private credential file permissions, XIQ container running state, and no host Git ownership warnings.

## Non-goals

- General host Bash/Zsh parity.
- Host aliases/functions, prompt settings, PATH/tool-manager configuration, or arbitrary environment forwarding.
- Broad secret forwarding.
- Installing or configuring Zsh in this change; only the shared file format and source point are prepared.
