#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=tests/incus/test_helper.sh
source "${REPO_ROOT}/tests/incus/test_helper.sh"

LABCTL_BIN="${REPO_ROOT}/incus/.local/bin/labctl"
LABCTL_LIB="${REPO_ROOT}/incus/.local/lib/labctl"

[[ -x $LABCTL_BIN ]] || {
	printf 'FAIL: labctl executable is missing\n' >&2
	exit 1
}
# shellcheck source=/dev/null
source "${LABCTL_LIB}/common.sh"
# shellcheck source=/dev/null
source "${LABCTL_LIB}/config.sh"
# shellcheck source=/dev/null
source "${LABCTL_LIB}/state.sh"
# shellcheck source=/dev/null
source "${LABCTL_LIB}/incus.sh"
# shellcheck source=/dev/null
source "${LABCTL_LIB}/network.sh"
# shellcheck source=/dev/null
source "${LABCTL_LIB}/host-setup.sh"

export HOME="${TEST_ROOT}/home"
export XDG_CONFIG_HOME="${TEST_ROOT}/config"
export XDG_STATE_HOME="${TEST_ROOT}/state"
mkdir -p "$HOME"

CONFIG_PATH="${TEST_ROOT}/config.env"
cat >"$CONFIG_PATH" <<CONFIG
LABCTL_WORKSPACE_ROOT=${TEST_ROOT}/workspace
LABCTL_MASTER_ROOT=${TEST_ROOT}/workspace/master
LABCTL_AGENT_BRIDGE=agentbr0
LABCTL_AGENT_CIDR=10.42.0.0/24
LABCTL_AGENT_GATEWAY=10.42.0.1
LABCTL_IP_POOL_START=10.42.0.10
LABCTL_IP_POOL_END=10.42.0.11
LABCTL_LAB_ROUTE_GATEWAY=10.1.1.1
LABCTL_INSTANCE_IMAGE=images:ubuntu/24.04
LABCTL_INSTANCE_USER=ubuntu
LABCTL_GO_VERSION=1.25.11
LABCTL_INTERNAL_INSECURE_REGISTRIES=registry-one.example.test:5000,registry-two.example.test:5001
LABCTL_DEVICE_TCP_PORTS=10001,10002
LABCTL_STACK_UP_COMMAND=IMAGE_IMPORT=false ./private-pcm-setup.sh --token=stack-command-secret-not-for-logs
LABCTL_STACK_DOWN_COMMAND=compose down
LABCTL_STACK_HEALTH_COMMAND=compose ps
LABCTL_WORKTREE_CREATE_HOOK=/bin/true
LABCTL_WORKTREE_REMOVE_HOOK=/bin/true
LABCTL_HARNESS_REPO_NAMES=one,two
LABCTL_GIT_HOST=git.example.test
LABCTL_GIT_CREDENTIAL_NAME=git-module-token
CONFIG
chmod 600 "$CONFIG_PATH"

MISSING_GO_VERSION_CONFIG="${TEST_ROOT}/missing-go-version.env"
rg -v '^LABCTL_GO_VERSION=' "$CONFIG_PATH" >"$MISSING_GO_VERSION_CONFIG"
chmod 600 "$MISSING_GO_VERSION_CONFIG"
assert_fails labctl_config_load "$MISSING_GO_VERSION_CONFIG"

for invalid_go_version in v1.25.11 1.25 1.25.11rc1 01.25.11 1.025.11 1.25.011; do
	INVALID_GO_VERSION_CONFIG="${TEST_ROOT}/invalid-go-version-${invalid_go_version}.env"
	sed "s/^LABCTL_GO_VERSION=.*/LABCTL_GO_VERSION=${invalid_go_version}/" "$CONFIG_PATH" >"$INVALID_GO_VERSION_CONFIG"
	chmod 600 "$INVALID_GO_VERSION_CONFIG"
	assert_fails labctl_config_load "$INVALID_GO_VERSION_CONFIG"
done

for invalid_registry_endpoints in 'http://registry.example.test:5000' 'registry.example.test' 'registry.example.test:0' 'registry.example.test:65536' 'registry.example.test:5000,registry.example.test:5000'; do
	INVALID_REGISTRY_CONFIG="${TEST_ROOT}/invalid-registry-${RANDOM}.env"
	sed "s|^LABCTL_INTERNAL_INSECURE_REGISTRIES=.*|LABCTL_INTERNAL_INSECURE_REGISTRIES=${invalid_registry_endpoints}|" "$CONFIG_PATH" >"$INVALID_REGISTRY_CONFIG"
	chmod 600 "$INVALID_REGISTRY_CONFIG"
	assert_fails labctl_config_load "$INVALID_REGISTRY_CONFIG"
done

mkdir -p "${TEST_ROOT}/workspace/master"

assert_fails labctl_normalize_ticket '../JIRA-#'
assert_fails labctl_normalize_ticket 'JIRA-#;rm'
assert_equals 'jira-#' "$(labctl_normalize_ticket 'JIRA-#')"
assert_fails "$LABCTL_BIN" config-load

MALICIOUS_CONFIG="${TEST_ROOT}/malicious.env"
MALICIOUS_MARKER="${TEST_ROOT}/malicious-config-was-evaluated"
printf 'touch %s\n' "$MALICIOUS_MARKER" >"$MALICIOUS_CONFIG"
cat "$CONFIG_PATH" >>"$MALICIOUS_CONFIG"
chmod 600 "$MALICIOUS_CONFIG"
assert_fails labctl_config_load "$MALICIOUS_CONFIG"
[[ ! -e $MALICIOUS_MARKER ]] || fail 'configuration parser evaluated a shell command'

for invalid_port in 0 65536; do
	INVALID_PORT_CONFIG="${TEST_ROOT}/invalid-port-${invalid_port}.env"
	awk -v port="$invalid_port" 'BEGIN { changed = 0 } /^LABCTL_DEVICE_TCP_PORTS=/ { print "LABCTL_DEVICE_TCP_PORTS=" port; changed = 1; next } { print } END { exit !changed }' "$CONFIG_PATH" >"$INVALID_PORT_CONFIG"
	chmod 600 "$INVALID_PORT_CONFIG"
	assert_fails labctl_config_load "$INVALID_PORT_CONFIG"
done

DUPLICATE_PORT_CONFIG="${TEST_ROOT}/duplicate-port.env"
cp "$CONFIG_PATH" "$DUPLICATE_PORT_CONFIG"
printf 'LABCTL_DEVICE_TCP_PORTS=10001\n' >>"$DUPLICATE_PORT_CONFIG"
chmod 600 "$DUPLICATE_PORT_CONFIG"
assert_fails labctl_config_load "$DUPLICATE_PORT_CONFIG"

labctl_config_load "$CONFIG_PATH"

# Regression: lifecycle Git configuration uses `su -` and therefore requires a
# writable configured-user home even when cloud image ownership is incorrect.
CLOUD_INIT_PATH="${TEST_ROOT}/cloud-init.yaml"
LABCTL_INSTANCE_USER='sandbox-user' labctl_incus_render_cloud_init "$CLOUD_INIT_PATH"
assert_succeeds rg -F --quiet 'install -d -o sandbox-user -g sandbox-user /home/sandbox-user' "$CLOUD_INIT_PATH"
# Stack hooks may invoke GNU Make, so every rendered guest bootstrap must install it.
assert_succeeds rg -x --fixed-strings --quiet '  - make' "$CLOUD_INIT_PATH"
# Generic sandbox diagnostics and lifecycle scripts require these utilities before
# the private stack hook runs.
assert_succeeds rg -x --fixed-strings --quiet '  - jq' "$CLOUD_INIT_PATH"
assert_succeeds rg -x --fixed-strings --quiet '  - screen' "$CLOUD_INIT_PATH"
assert_succeeds rg -x --fixed-strings --quiet '  - net-tools' "$CLOUD_INIT_PATH"
# CGO-backed private modules require the generic Ubuntu compiler toolchain.
assert_succeeds rg -x --fixed-strings --quiet '  - build-essential' "$CLOUD_INIT_PATH"
# Ubuntu's apt Go version is not sufficient for all mounted workspaces. The
# rendered generic bootstrap must install the configured official toolchain.
assert_succeeds rg -F --quiet 'https://go.dev/dl/go1.25.11.linux-amd64.tar.gz' "$CLOUD_INIT_PATH"
assert_succeeds rg -F --quiet 'tar -C /usr/local -xzf /tmp/labctl-go.tar.gz' "$CLOUD_INIT_PATH"
assert_succeeds rg -F --quiet "export PATH=\"/usr/local/go/bin:\$PATH\"" "$CLOUD_INIT_PATH"
# /usr/local/bin is on the normal noninteractive shell PATH; the symlink keeps
# the Go command available before an interactive profile is read.
assert_succeeds rg -F --quiet 'ln -sf /usr/local/go/bin/go /usr/local/bin/go' "$CLOUD_INIT_PATH"
assert_fails rg -F --quiet '__LABCTL_GO_VERSION__' "$CLOUD_INIT_PATH"
# Internal registries answer HTTP. Render their exact host:port endpoint semantics
# without emitting any active-config value from the command interface.
assert_succeeds rg -F --quiet '"insecure-registries":["registry-one.example.test:5000","registry-two.example.test:5001"]' "$CLOUD_INIT_PATH"
assert_succeeds rg -F --quiet 'systemctl restart docker' "$CLOUD_INIT_PATH"
assert_succeeds rg -F --quiet '[ -e /root/go/bin ] && [ ! -d /root/go/bin ]' "$CLOUD_INIT_PATH"
assert_succeeds rg -F --quiet 'install -d -m 0755 /root/go/bin' "$CLOUD_INIT_PATH"
assert_fails rg -i --quiet 'k3s|rancher|registries\.yaml|INSTALL_K3S' "$CLOUD_INIT_PATH"
assert_fails rg -F --quiet '__LABCTL_INTERNAL_INSECURE_REGISTRIES__' "$CLOUD_INIT_PATH"
assert_fails rg -F --quiet '__LABCTL_DOCKER_DAEMON_JSON__' "$CLOUD_INIT_PATH"
labctl_config_load "$CONFIG_PATH"

assert_succeeds labctl_incus_cidr_overlaps '10.42.0.0/16' '10.42.1.0/24'
assert_equals '10.42.0.10' "$(labctl_state_reserve_ip 'jira-#')"
assert_equals '10.42.0.10' "$(labctl_state_reserve_ip 'jira-#')"
assert_fails labctl_state_claim_ip '../JIRA-#' '10.42.0.10'
assert_fails labctl_state_reserve_ip '../JIRA-#'
assert_fails labctl_state_lookup '../JIRA-#'
assert_fails labctl_state_remove '../JIRA-#'
assert_fails labctl_state_claim_ip 'jira-#-two' '10.42.0.10'

assert_succeeds "$LABCTL_BIN" help
labctl_state_record 'jira-#' 'JIRA-#' '10.42.0.10' 'harness'
assert_equals 'jira-#' "$(labctl_state_lookup 'jira-#' | jq -r '.instance')"
assert_equals 'created' "$(labctl_state_lookup 'jira-#' | jq -r '.status')"
assert_equals 'jira-#' "$(labctl_state_lookup 'JIRA-#' | jq -r '.ticket')"

RACE_STATE_HOME="${TEST_ROOT}/race-state"
RACE_JQ_DIR="${TEST_ROOT}/race-jq"
mkdir -p "$RACE_JQ_DIR"
cat >"${RACE_JQ_DIR}/jq" <<'JQ'
#!/usr/bin/env bash
sleep 0.1
exec /usr/bin/jq "$@"
JQ
chmod +x "${RACE_JQ_DIR}/jq"
run_race_record() {
	PATH="${RACE_JQ_DIR}:$PATH" XDG_STATE_HOME="$RACE_STATE_HOME" bash -c '
		source "$1/common.sh"
		source "$1/config.sh"
		source "$1/state.sh"
		labctl_config_load "$2"
		labctl_state_record "$3" "$4" "$5" harness
	' bash "$LABCTL_LIB" "$CONFIG_PATH" "$1" "$2" 10.42.0.10
}
run_race_record 'race-one' 'race-one' &
race_one_pid=$!
run_race_record 'race-two' 'race-two' &
race_two_pid=$!
race_successes=0
for race_pid in "$race_one_pid" "$race_two_pid"; do
	if wait "$race_pid"; then
		race_successes=$((race_successes + 1))
	fi
done
assert_equals '1' "$race_successes"
assert_equals '1' "$(jq '[.sandboxes[] | select(.ip == "10.42.0.10")] | length' "${RACE_STATE_HOME}/labctl/sandboxes.json")"

FAKE_BIN="${TEST_ROOT}/fake-bin"
COMMAND_LOG="${TEST_ROOT}/command.log"
mkdir -p "$FAKE_BIN"
export COMMAND_LOG
cat >"${FAKE_BIN}/incus" <<'INCUS'
#!/usr/bin/env bash
printf 'incus %s\n' "$*" >>"$COMMAND_LOG"
fake_instance_exists() {
	[[ ${LABCTL_FAKE_INSTANCE_EXISTS:-false} == true ]] ||
		[[ -n ${LABCTL_FAKE_INSTANCE_DIRECTORY:-} && -f ${LABCTL_FAKE_INSTANCE_DIRECTORY}/$1 ]]
}
case "$*" in
'info '*' --format json' | 'config show '*' --expanded --format json' | 'config show '*' --format json')
	printf '%s\n' 'Error: unknown flag: --format' >&2
	exit 2
	;;
info\ --format*)
	printf '%s\n' 'Error: unknown flag: --format' >&2
	exit 2
	;;
info\ *) fake_instance_exists "$2" ;;
init\ *)
	if [[ -n ${LABCTL_FAKE_INSTANCE_DIRECTORY:-} ]]; then
		mkdir -p "$LABCTL_FAKE_INSTANCE_DIRECTORY"
		touch "${LABCTL_FAKE_INSTANCE_DIRECTORY}/${3:?}"
	fi
	;;
launch\ *\ --no-start*)
	printf '%s\n' 'Error: unknown flag: --no-start' >&2
	exit 2
	;;
config\ device\ set\ *\ eth0\ ipv4.address=*)
	printf '%s\n' 'Error: Cannot update inherited device; use config device override' >&2
	exit 1
	;;
'config get '*' eth0 ipv4.address')
	case ${3:-} in
	jira-#) printf '%s\n' "${LABCTL_FAKE_INSTANCE_IP:-10.42.0.10}" ;;
	jira-two) printf '%s\n' "${LABCTL_FAKE_SECOND_INSTANCE_IP:-10.42.0.11}" ;;
	*) printf '%s\n' "${LABCTL_FAKE_INSTANCE_IP:-10.42.0.10}" ;;
	esac
	;;
# Incus treats --data literally; @file is not expanded as a payload reference.
query\ /1.0/instances/*\ --request\ PATCH\ --data\ @*)
	printf '%s\n' 'Error: literal @file payloads are unsupported; use --data-file' >&2
	exit 2
	;;
query\ /1.0/instances/*\ --request\ PATCH\ --data-file\ *)
	patch_file=${6:?}
	jq -e --arg credential "systemd.credential.${LABCTL_FAKE_CREDENTIAL_NAME:-git-module-token}" '
		(keys == ["config"]) and (.config | keys == [$credential])
	' "$patch_file" >/dev/null
	printf '%s\n' valid >"${LABCTL_FAKE_PATCH_VALIDATION:?}"
	;;
'query /1.0/instances/'*)
	if [[ ${LABCTL_FAKE_INSTANCE_QUERY_FAILURE:-false} == true ]]; then
		printf '%s\n' "${LABCTL_FAKE_INSTANCE_QUERY_FAILURE_OUTPUT:-instance query failed}" >&2
		exit 42
	fi
	status=${LABCTL_FAKE_INSTANCE_STATUS:-Running}
	if [[ -n ${LABCTL_FAKE_INSTANCE_STATE_FILE:-} && -f ${LABCTL_FAKE_INSTANCE_STATE_FILE} ]]; then
		status=$(<"$LABCTL_FAKE_INSTANCE_STATE_FILE")
	fi
	if [[ -n ${LABCTL_FAKE_INSTANCE_CONFIG_JSON+x} ]]; then
		printf '%s\n' "$LABCTL_FAKE_INSTANCE_CONFIG_JSON" | jq --arg status "$status" '. + {status: $status}'
	else
		jq -cn --arg status "$status" '{status: $status, config: {"security.privileged": "false"}, devices: {}}'
	fi
	;;
exec\ *\ --\ bash\ -s\ --\ *)
	if [[ -n ${LABCTL_FAKE_CAPTURE_REMOTE_SCRIPT:-} ]]; then
		cat >"$LABCTL_FAKE_CAPTURE_REMOTE_SCRIPT"
	else
		cat >/dev/null
	fi
	;;
start\ *)
	status=${LABCTL_FAKE_INSTANCE_STATUS:-Running}
	if [[ -n ${LABCTL_FAKE_INSTANCE_STATE_FILE:-} && -f ${LABCTL_FAKE_INSTANCE_STATE_FILE} ]]; then
		status=$(<"$LABCTL_FAKE_INSTANCE_STATE_FILE")
	fi
	if [[ ${LABCTL_FAKE_REJECT_DUPLICATE_START:-false} == true && $status == Running ]]; then
		printf '%s\n' 'Error: The instance is already running' >&2
		exit 1
	fi
	if [[ -n ${LABCTL_FAKE_INSTANCE_STATE_FILE:-} ]]; then
		printf '%s\n' Running >"$LABCTL_FAKE_INSTANCE_STATE_FILE"
	fi
	;;
'query /1.0') printf '%s\n' '{"environment":{"kernel_features":{"idmapped_mounts":true}}}' ;;
'query /1.0/profiles/default')
	if [[ ${LABCTL_DEFAULT_PROFILE_INVENTORY_FAILURE:-false} == true ]]; then
		exit 42
	elif [[ -n ${LABCTL_UNSAFE_DEFAULT_PROFILE_JSON:-} ]]; then
		printf '%s\n' "$LABCTL_UNSAFE_DEFAULT_PROFILE_JSON"
	else
		printf '%s\n' '{}'
	fi
	;;
'query /1.0/profiles/agent-dev-env')
	if [[ -n ${LABCTL_UNSAFE_PROFILE_JSON:-} ]]; then
		printf '%s\n' "$LABCTL_UNSAFE_PROFILE_JSON"
	elif [[ ${LABCTL_FAKE_PROFILE_EXISTS:-false} == true ]]; then
		printf '%s\n' '{}'
	else
		exit 1
	fi
	;;
'info') [[ ${LABCTL_INCUS_ACCESS_DENIED:-false} != true ]] ;;
'network show agentbr0') exit 1 ;;
'profile show '*)
	printf '%s\n' 'Error: unknown flag: --format' >&2
	exit 2
	;;
'network list --format csv -c n' | 'storage list --format csv -c n' | 'profile list --format csv -c n' | 'list --format csv -c n')
	[[ ${LABCTL_EXTERNAL_NAME_CONFLICT:-false} != true ]] || printf 'agentbr0\n'
	;;
*) exit 0 ;;
esac
INCUS
cat >"${FAKE_BIN}/ip" <<'IP'
#!/usr/bin/env bash
printf 'ip %s\n' "$*" >>"$COMMAND_LOG"
case "$*" in
'link show agentbr0') [[ ${LABCTL_HOST_BRIDGE_CONFLICT:-false} == true ]] ;;
'route show')
	if [[ ${LABCTL_ROUTE_INVENTORY_FAILURE:-false} == true ]]; then
		exit 42
	fi
	[[ ${LABCTL_ROUTE_CONFLICT:-false} != true ]] || printf '10.42.0.0/24 dev lxdbr0\n' ;;
'route get 10.1.1.1') printf '10.1.1.1 via 10.1.1.1 dev eth0 src 10.1.1.2\n' ;;
esac
IP
cat >"${FAKE_BIN}/sysctl" <<'SYSCTL'
#!/usr/bin/env bash
printf 'sysctl %s\n' "$*" >>"$COMMAND_LOG"
if [[ ${1:-} == -n ]]; then
	printf '1\n'
else
	printf 'net.ipv4.ip_forward = 1\n'
fi
SYSCTL
cat >"${FAKE_BIN}/df" <<'DF'
#!/usr/bin/env bash
printf 'df %s\n' "$*" >>"$COMMAND_LOG"
printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\n/dev/test 1000 1 999 1%% /\n'
DF
cat >"${FAKE_BIN}/lxc" <<'LXC'
#!/usr/bin/env bash
printf 'lxc %s\n' "$*" >>"$COMMAND_LOG"
[[ ${LABCTL_LXC_INVENTORY_FAILURE:-false} != true ]] || exit 1
[[ ${LABCTL_EXTERNAL_NAME_CONFLICT:-false} != true ]] || printf 'agentbr0\n'
LXC
cat >"${FAKE_BIN}/multipass" <<'MULTIPASS'
#!/usr/bin/env bash
printf 'multipass %s\n' "$*" >>"$COMMAND_LOG"
[[ ${LABCTL_MULTIPASS_INVENTORY_FAILURE:-false} != true ]] || exit 1
if [[ ${LABCTL_MULTIPASS_NAME_CONFLICT:-false} == true ]]; then
	printf '%s\n' 'Name,State,IPv4,Image' 'agentbr0,Running,10.42.0.20,24.04 LTS'
fi
MULTIPASS
cat >"${FAKE_BIN}/docker" <<'DOCKER'
#!/usr/bin/env bash
printf 'docker %s\n' "$*" >>"$COMMAND_LOG"
exit 0
DOCKER
cat >"${FAKE_BIN}/nc" <<'NC'
#!/usr/bin/env bash
printf 'nc %s\n' "$*" >>"$COMMAND_LOG"
[[ ${LABCTL_FAKE_CLOSED_PORT:-} != "${5:-}" ]]
NC
for fake_command in incus ip sysctl df lxc multipass docker nc; do chmod +x "${FAKE_BIN}/${fake_command}"; done

assert_command_log_contains() {
	local expected=$1
	if ! rg -F --quiet "$expected" "$COMMAND_LOG"; then
		fail "expected command log to contain [$expected]"
	fi
}

assert_command_log_not_contains() {
	local unexpected=$1
	if rg -F --quiet "$unexpected" "$COMMAND_LOG"; then
		fail "expected command log not to contain [$unexpected]"
	fi
}

assert_command_log_ordered() {
	local first=$1 second=$2 first_line second_line
	first_line=$(rg -n -F "$first" "$COMMAND_LOG" | sed -n '1s/:.*//p' || true)
	second_line=$(rg -n -F "$second" "$COMMAND_LOG" | sed -n '1s/:.*//p' || true)
	if [[ -z $first_line || -z $second_line || $first_line -ge $second_line ]]; then
		fail "expected command [$first] before [$second]"
	fi
}

# Unsafe profile names must be rejected before they can become API path segments.
: >"$COMMAND_LOG"
PATH="${FAKE_BIN}:$PATH" assert_fails labctl_incus_profile_query 'default/../agent-dev-env'
assert_command_log_not_contains 'incus query /1.0/profiles/'

# Ubuntu Incus 6 rejects `incus info --format json`; capability discovery must use /1.0.
# It also rejects all `profile show --format json` calls; profile inspection must
# use the API endpoint, including the default profile applied at launch.
: >"$COMMAND_LOG"
PATH="${FAKE_BIN}:$PATH" assert_succeeds "$LABCTL_BIN" --config "$CONFIG_PATH" preflight
assert_command_log_contains 'incus query /1.0'
assert_command_log_contains 'incus query /1.0/profiles/default'
assert_command_log_not_contains 'incus info --format json'
assert_command_log_not_contains 'incus profile show '

PATH="${FAKE_BIN}:$PATH" LABCTL_TEST_FAKE_COMMANDS=true assert_fails "$LABCTL_BIN" --config "$CONFIG_PATH" setup-host
PATH="${FAKE_BIN}:$PATH" assert_succeeds "$LABCTL_BIN" --config "$CONFIG_PATH" --dry-run setup-host --yes
PATH="${FAKE_BIN}:$PATH" assert_succeeds "$LABCTL_BIN" --config "$CONFIG_PATH" setup-host --yes
assert_command_log_contains 'network create agentbr0'
assert_command_log_contains 'profile create agent-dev-env'
assert_command_log_contains 'security.nesting=true'
assert_command_log_contains 'security.privileged=false'
assert_command_log_not_contains 'security.privileged=true'
assert_command_log_not_contains '/var/run/docker.sock'

COMMAND_OVERRIDE="${TEST_ROOT}/command-override.sh"
cat >"$COMMAND_OVERRIDE" <<'COMMAND'
command() {
	if [[ ${1:-} == -v && ${2:-} == "${LABCTL_MISSING_COMMAND:-}" ]]; then
		return 1
	fi
	builtin command "$@"
}
COMMAND
for unavailable in incus jq flock docker lxc multipass; do
	PATH="${FAKE_BIN}:$PATH" BASH_ENV="$COMMAND_OVERRIDE" LABCTL_MISSING_COMMAND="$unavailable" assert_fails "$LABCTL_BIN" --config "$CONFIG_PATH" preflight
done

PATH="${FAKE_BIN}:$PATH" LABCTL_INCUS_ACCESS_DENIED=true assert_fails "$LABCTL_BIN" --config "$CONFIG_PATH" preflight
PATH="${FAKE_BIN}:$PATH" LABCTL_ROUTE_CONFLICT=true assert_fails "$LABCTL_BIN" --config "$CONFIG_PATH" preflight
PATH="${FAKE_BIN}:$PATH" LABCTL_ROUTE_INVENTORY_FAILURE=true assert_fails "$LABCTL_BIN" --config "$CONFIG_PATH" preflight
PATH="${FAKE_BIN}:$PATH" LABCTL_HOST_BRIDGE_CONFLICT=true assert_fails "$LABCTL_BIN" --config "$CONFIG_PATH" preflight
export LABCTL_EXTERNAL_NAME_CONFLICT=true
PATH="${FAKE_BIN}:$PATH" assert_fails "$LABCTL_BIN" --config "$CONFIG_PATH" preflight
unset LABCTL_EXTERNAL_NAME_CONFLICT
PATH="${FAKE_BIN}:$PATH" LABCTL_MULTIPASS_NAME_CONFLICT=true assert_fails "$LABCTL_BIN" --config "$CONFIG_PATH" preflight
PATH="${FAKE_BIN}:$PATH" LABCTL_LXC_INVENTORY_FAILURE=true assert_fails "$LABCTL_BIN" --config "$CONFIG_PATH" preflight
PATH="${FAKE_BIN}:$PATH" LABCTL_MULTIPASS_INVENTORY_FAILURE=true assert_fails "$LABCTL_BIN" --config "$CONFIG_PATH" preflight
PATH="${FAKE_BIN}:$PATH" LABCTL_DEFAULT_PROFILE_INVENTORY_FAILURE=true assert_fails "$LABCTL_BIN" --config "$CONFIG_PATH" preflight

# These fixtures model every profile shape that would expose host networking or devices.
# The default profile is applied at launch, so it follows the managed-profile policy.
for unsafe_default_profile_json in \
	'{"config":{"raw.lxc":"lxc.net.0.type = phys\\nlxc.net.0.link = enp1s0"}}' \
	'{"devices":{"host-data":{"type":"disk","source":"/srv","path":"/mnt/host"}}}' \
	'{"devices":{"vf":{"type":"nic","nictype":"sriov","parent":"enp1s0"}}}'; do
	PATH="${FAKE_BIN}:$PATH" LABCTL_UNSAFE_DEFAULT_PROFILE_JSON="$unsafe_default_profile_json" assert_fails "$LABCTL_BIN" --config "$CONFIG_PATH" preflight
done

# Revalidate profiles at the launch boundary: an unsafe default must prevent launch.
: >"$COMMAND_LOG"
PATH="${FAKE_BIN}:$PATH" LABCTL_UNSAFE_DEFAULT_PROFILE_JSON='{"config":{"raw.lxc":"lxc.net.0.type = phys\\nlxc.net.0.link = enp1s0"}}' assert_fails labctl_incus_launch 'launch-default-profile' '10.42.0.10'
assert_command_log_contains 'query /1.0/profiles/default'
assert_command_log_not_contains 'profile show '
assert_command_log_not_contains 'launch images:ubuntu/24.04 launch-default-profile'

for unsafe_profile_json in \
	'{"config":{"security.privileged":"true"}}' \
	'{"devices":{"eth0":{"type":"nic","network":"host"}}}' \
	'{"devices":{"api":{"type":"proxy","listen":"tcp:0.0.0.0:2375"}}}' \
	'{"devices":{"docker":{"type":"disk","source":"/var/run/docker.sock","path":"/var/run/docker.sock"}}}' \
	'{"devices":{"host-data":{"type":"disk","source":"/srv","path":"/mnt/host"}}}' \
	'{"devices":{"block":{"type":"unix-block","source":"/dev/sdb","path":"/dev/sdb"}}}' \
	'{"devices":{"character":{"type":"unix-char","source":"/dev/ttyS0","path":"/dev/ttyS0"}}}' \
	'{"devices":{"socket":{"type":"unix-char","source":"/run/host.sock","path":"/run/host.sock"}}}' \
	'{"devices":{"vf":{"type":"nic","nictype":"sriov","parent":"enp1s0"}}}' \
	'{"devices":{"host-bridge":{"type":"nic","nictype":"bridged","parent":"br0"}}}' \
	'{"config":{"raw.lxc":"lxc.net.0.type = phys\\nlxc.net.0.link = enp1s0"}}' \
	'{"config":{"raw.lxc":"lxc.mount.entry = /srv host none bind,create=dir 0 0"}}' \
	'{"devices":{"eth0":{"type":"nic","network":"agentbr0","name":"eth0"},"eth1":{"type":"nic","network":"agentbr0","name":"eth1"}}}' \
	'{"devices":{"gpu":{"type":"gpu"}}}'; do
	PATH="${FAKE_BIN}:$PATH" LABCTL_UNSAFE_PROFILE_JSON="$unsafe_profile_json" assert_fails "$LABCTL_BIN" --config "$CONFIG_PATH" preflight
done

# Task 3 lifecycle fixtures: all commands are fake and create uses dry-run.
# shellcheck source=/dev/null
source "${LABCTL_LIB}/workspace.sh"

mkdir -p "${TEST_ROOT}/workspace/master/one/worktrees/jira-#" "${TEST_ROOT}/workspace/master/two/worktrees/jira-#"
mkdir -p "${TEST_ROOT}/workspace/jira-#/one" "${TEST_ROOT}/workspace/jira-#/two"
printf 'gitdir: %s\n' "${TEST_ROOT}/workspace/master/one/worktrees/jira-#" >"${TEST_ROOT}/workspace/jira-#/one/.git"
printf 'gitdir: %s\n' "${TEST_ROOT}/workspace/master/two/worktrees/jira-#" >"${TEST_ROOT}/workspace/jira-#/two/.git"
# Nested repositories are not direct ticket worktrees and must not be trusted.
mkdir -p "${TEST_ROOT}/workspace/jira-#/one/vendor/nested"
printf 'gitdir: %s\n' "${TEST_ROOT}/workspace/master/one/worktrees/jira-#" >"${TEST_ROOT}/workspace/jira-#/one/vendor/nested/.git"

assert_equals 'harness' "$(labctl_workspace_detect 'JIRA-#')"
assert_succeeds labctl_workspace_validate 'JIRA-#'
assert_fails labctl_workspace_validate 'missing-ticket'
mv "${TEST_ROOT}/workspace/master" "${TEST_ROOT}/workspace/master-missing"
assert_fails labctl_workspace_validate 'JIRA-#'
mv "${TEST_ROOT}/workspace/master-missing" "${TEST_ROOT}/workspace/master"
mkdir -p "${TEST_ROOT}/outside/jira-#/one"
ln -s "${TEST_ROOT}/outside" "${TEST_ROOT}/workspace/escaped"
assert_fails labctl_workspace_validate 'escaped'
printf 'gitdir: %s\n' "${TEST_ROOT}/workspace/master/one/worktrees/jira-#" >"${TEST_ROOT}/outside/jira-#/one/.git"

# Ticket roots preserve their on-disk case, while controller/state identifiers normalize.
mkdir -p "${TEST_ROOT}/workspace/master/one/worktrees/nvo-20130" "${TEST_ROOT}/workspace/master/two/worktrees/nvo-20130"
mkdir -p "${TEST_ROOT}/workspace/NVO-20130/one" "${TEST_ROOT}/workspace/NVO-20130/two"
printf 'gitdir: %s\n' "${TEST_ROOT}/workspace/master/one/worktrees/nvo-20130" >"${TEST_ROOT}/workspace/NVO-20130/one/.git"
printf 'gitdir: %s\n' "${TEST_ROOT}/workspace/master/two/worktrees/nvo-20130" >"${TEST_ROOT}/workspace/NVO-20130/two/.git"
assert_equals "${TEST_ROOT}/workspace/NVO-20130" "$(labctl_workspace_ticket_root 'NvO-20130')"
assert_succeeds labctl_workspace_validate 'NvO-20130'
assert_equals '10.42.0.11' "$(labctl_state_reserve_ip 'NvO-20130')"
assert_equals 'nvo-20130' "$(labctl_state_lookup 'NVO-20130' | jq -r '.instance')"
mkdir -p "${TEST_ROOT}/workspace/nVo-20130"
assert_fails labctl_workspace_ticket_root 'NVO-20130'
rmdir "${TEST_ROOT}/workspace/nVo-20130"

: >"$COMMAND_LOG"
if ! PATH="${FAKE_BIN}:$PATH" LABCTL_FAKE_PROFILE_EXISTS=true "$LABCTL_BIN" --config "$CONFIG_PATH" create 'JIRA-#' --dry-run >>"$COMMAND_LOG" 2>&1; then
	fail 'dry-run create failed'
fi
assert_command_log_contains 'init images:ubuntu/24.04 jira-#'
assert_command_log_contains 'config device add jira-# git-master disk'
assert_command_log_contains 'config device add jira-# ticket-workspace disk'
assert_command_log_contains 'shift=true'
assert_command_log_contains 'config set jira-# user.user-data -'
assert_command_log_not_contains 'registry-one.example.test:5000'

# Incus 6 rejects launch --no-start. Init creates the instance stopped, so it
# must retain both profiles and cloud-init configuration before the inherited
# eth0 override, explicit start, and readiness checks.
: >"$COMMAND_LOG"
PATH="${FAKE_BIN}:$PATH" LABCTL_FAKE_PROFILE_EXISTS=true assert_succeeds "$LABCTL_BIN" --config "$CONFIG_PATH" create 'JIRA-#'
assert_command_log_contains 'init images:ubuntu/24.04 jira-# --profile default --profile agent-dev-env'
assert_command_log_contains 'config set jira-# user.user-data -'
assert_command_log_not_contains 'registry-one.example.test:5000'
assert_command_log_not_contains 'registry-two.example.test:5001'
assert_command_log_not_contains 'launch images:ubuntu/24.04 jira-#'
assert_command_log_contains 'config device override jira-# eth0 ipv4.address=10.42.0.10'
assert_command_log_not_contains 'config device set jira-# eth0 ipv4.address='
assert_command_log_ordered 'init images:ubuntu/24.04 jira-# --profile default --profile agent-dev-env' 'config device override jira-# eth0 ipv4.address=10.42.0.10'
assert_command_log_ordered 'config device override jira-# eth0 ipv4.address=10.42.0.10' 'start jira-#'
assert_command_log_ordered 'start jira-#' 'exec jira-# -- cloud-init status --wait'
# After both idmapped mounts and guest readiness, configure only direct ticket
# worktrees in the instance user's global Git configuration.
assert_command_log_ordered 'config device add jira-# ticket-workspace disk' 'exec jira-# -- cloud-init status --wait'
assert_command_log_ordered 'exec jira-# -- docker info' 'git config --global --add safe.directory'
assert_command_log_contains "exec jira-# -- su - ubuntu -c git config --global --add safe.directory ${TEST_ROOT}/workspace/jira-#/one"
assert_command_log_contains "exec jira-# -- su - ubuntu -c git config --global --add safe.directory ${TEST_ROOT}/workspace/jira-#/two"
assert_command_log_not_contains "safe.directory ${TEST_ROOT}/workspace/master"
assert_command_log_not_contains "safe.directory ${TEST_ROOT}/workspace/jira-# "
assert_command_log_not_contains "safe.directory ${TEST_ROOT}/workspace/jira-#/one/vendor/nested"
assert_command_log_not_contains 'safe.directory *'
assert_equals '2' "$(rg -F -c 'git config --global --add safe.directory' "$COMMAND_LOG" || true)"

# A failed historical create could leave an empty IP in its existing record.
# Create must replace that incomplete reservation before launch, then persist and
# use the same valid address for the NIC override.
jq '.sandboxes["nvo-20130"].ip = ""' "${XDG_STATE_HOME}/labctl/sandboxes.json" >"${XDG_STATE_HOME}/labctl/sandboxes.json.tmp"
mv "${XDG_STATE_HOME}/labctl/sandboxes.json.tmp" "${XDG_STATE_HOME}/labctl/sandboxes.json"
: >"$COMMAND_LOG"
PATH="${FAKE_BIN}:$PATH" LABCTL_FAKE_PROFILE_EXISTS=true assert_succeeds "$LABCTL_BIN" --config "$CONFIG_PATH" create 'NVO-20130'
assert_equals '10.42.0.11' "$(labctl_state_lookup 'nvo-20130' | jq -r '.ip')"
assert_command_log_contains 'config device override nvo-20130 eth0 ipv4.address=10.42.0.11'
if rg -x --fixed-strings --quiet 'incus config device override nvo-20130 eth0 ipv4.address=' "$COMMAND_LOG"; then
	fail 'create issued an empty IPv4 device override for nvo-20130'
fi

# Incus 6 rejects JSON formatting on both `info` and `config show`; status and
# isolation checks must query the validated instance API endpoint instead.
LABCTL_FAKE_INSTANCE_CONFIG_JSON=$(jq -cn --arg master "${TEST_ROOT}/workspace/master" --arg ticket "${TEST_ROOT}/workspace/jira-#" '{config:{"security.privileged":"false"},devices:{"git-master":{type:"disk",source:$master,path:$master},"ticket-workspace":{type:"disk",source:$ticket,path:$ticket}}}')
export LABCTL_FAKE_INSTANCE_CONFIG_JSON
# Regression: public instance inspection must never disclose systemd credential
# values. The key remains visible to consumers that need to establish its
# presence, while every systemd.credential.* value is redacted.
INSTANCE_CREDENTIAL_SECRET=$(printf '%s%s' 'instance-credential-secret-' 'not-for-logs')
LABCTL_FAKE_INSTANCE_CONFIG_JSON=$(jq -cn --arg master "${TEST_ROOT}/workspace/master" --arg ticket "${TEST_ROOT}/workspace/jira-#" --arg secret "$INSTANCE_CREDENTIAL_SECRET" '{config:{"security.privileged":"false","systemd.credential.git-module-token":$secret,"systemd.credential.other-token":("other-" + $secret)},devices:{"git-master":{type:"disk",source:$master,path:$master},"ticket-workspace":{type:"disk",source:$ticket,path:$ticket}}}')
export LABCTL_FAKE_INSTANCE_CONFIG_JSON
STATUS_OUTPUT="${TEST_ROOT}/status-output"
: >"$COMMAND_LOG"
if ! PATH="${FAKE_BIN}:$PATH" LABCTL_FAKE_INSTANCE_EXISTS=true "$LABCTL_BIN" --config "$CONFIG_PATH" status 'JIRA-#' >"$STATUS_OUTPUT" 2>&1; then
	fail 'status failed while inspecting a sandbox with systemd credentials'
fi
assert_succeeds rg -F --quiet '"systemd.credential.git-module-token": "[REDACTED]"' "$STATUS_OUTPUT"
assert_succeeds rg -F --quiet '"systemd.credential.other-token": "[REDACTED]"' "$STATUS_OUTPUT"
assert_fails rg -F --quiet "$INSTANCE_CREDENTIAL_SECRET" "$STATUS_OUTPUT"
assert_command_log_contains 'query /1.0/instances/jira-%23'
assert_command_log_not_contains "$INSTANCE_CREDENTIAL_SECRET"
assert_command_log_not_contains 'info jira-# --format json'
assert_command_log_not_contains 'config show jira-# --expanded --format json'

# A failed instance query must not relay Incus diagnostics containing a
# credential value either.
QUERY_FAILURE_OUTPUT="${TEST_ROOT}/query-failure-output"
: >"$COMMAND_LOG"
if PATH="${FAKE_BIN}:$PATH" LABCTL_FAKE_INSTANCE_EXISTS=true LABCTL_FAKE_INSTANCE_QUERY_FAILURE=true LABCTL_FAKE_INSTANCE_QUERY_FAILURE_OUTPUT="$INSTANCE_CREDENTIAL_SECRET" "$LABCTL_BIN" --config "$CONFIG_PATH" status 'JIRA-#' >"$QUERY_FAILURE_OUTPUT" 2>&1; then
	fail 'status succeeded after a failed instance query'
fi
assert_fails rg -F --quiet "$INSTANCE_CREDENTIAL_SECRET" "$QUERY_FAILURE_OUTPUT"
assert_command_log_not_contains "$INSTANCE_CREDENTIAL_SECRET"

: >"$COMMAND_LOG"
PATH="${FAKE_BIN}:$PATH" LABCTL_FAKE_INSTANCE_EXISTS=true LABCTL_FAKE_PROFILE_EXISTS=true assert_succeeds "$LABCTL_BIN" --config "$CONFIG_PATH" verify 'JIRA-#'
assert_command_log_contains 'query /1.0/instances/jira-%23'
assert_command_log_not_contains 'info jira-# --format json'
assert_command_log_not_contains 'config show jira-# --expanded --format json'

PATH="${FAKE_BIN}:$PATH" assert_fails "$LABCTL_BIN" --config "$CONFIG_PATH" destroy 'JIRA-#'
PATH="${FAKE_BIN}:$PATH" assert_succeeds "$LABCTL_BIN" --config "$CONFIG_PATH" destroy 'JIRA-#' --yes --dry-run
assert_command_log_not_contains 'git worktree remove'
assert_command_log_not_contains 'git worktree prune'
if ! PATH="${FAKE_BIN}:$PATH" "$LABCTL_BIN" --config "$CONFIG_PATH" cleanup-worktree 'JIRA-#' --yes --dry-run >>"$COMMAND_LOG" 2>&1; then
	fail 'dry-run cleanup-worktree failed'
fi
assert_command_log_contains "/bin/true jira-#"

# Existing instances must match the registry reservation before reuse.
PATH="${FAKE_BIN}:$PATH" LABCTL_FAKE_INSTANCE_EXISTS=true LABCTL_FAKE_INSTANCE_IP=10.42.0.10 assert_succeeds "$LABCTL_BIN" --config "$CONFIG_PATH" create 'JIRA-#' --dry-run
PATH="${FAKE_BIN}:$PATH" LABCTL_FAKE_INSTANCE_EXISTS=true LABCTL_FAKE_INSTANCE_IP=10.42.0.11 assert_fails "$LABCTL_BIN" --config "$CONFIG_PATH" create 'JIRA-#' --dry-run

# A malformed harness root must fail linked-worktree validation.
printf 'gitdir: /outside/master/two\n' >"${TEST_ROOT}/workspace/jira-#/two/.git"
assert_fails labctl_workspace_validate 'JIRA-#'
printf 'gitdir: %s\n' "${TEST_ROOT}/workspace/master/two/worktrees/jira-#" >"${TEST_ROOT}/workspace/jira-#/two/.git"

# Task 4 network fixtures: stack hooks run only in a running sandbox with both
# expected workspace mounts, and ports are probed at each sandbox IP.
export LABCTL_FAKE_INSTANCE_EXISTS=true
export LABCTL_FAKE_PROFILE_EXISTS=true
export LABCTL_FAKE_INSTANCE_IP=10.42.0.10
export LABCTL_FAKE_SECOND_INSTANCE_IP=10.42.0.11
LABCTL_FAKE_INSTANCE_CONFIG_JSON=$(jq -cn --arg master "${TEST_ROOT}/workspace/master" --arg ticket "${TEST_ROOT}/workspace/jira-#" '{config:{"security.privileged":"false"},devices:{"git-master":{type:"disk",source:$master,path:$master},"ticket-workspace":{type:"disk",source:$ticket,path:$ticket}}}')
export LABCTL_FAKE_INSTANCE_CONFIG_JSON

# Regression: create leaves the sandbox running. Starting it again must skip
# Incus start (which rejects a duplicate start) and still execute stack-up once.
LABCTL_FAKE_INSTANCE_STATE_FILE="${TEST_ROOT}/instance-status"
export LABCTL_FAKE_INSTANCE_STATE_FILE
printf '%s\n' Running >"$LABCTL_FAKE_INSTANCE_STATE_FILE"
: >"$COMMAND_LOG"
PATH="${FAKE_BIN}:$PATH" LABCTL_FAKE_REJECT_DUPLICATE_START=true assert_succeeds "$LABCTL_BIN" --config "$CONFIG_PATH" start 'JIRA-#'
assert_command_log_not_contains 'start jira-#'
assert_equals '1' "$(rg -F -c 'exec jira-# -- bash -s --' "$COMMAND_LOG" || true)"

# A stopped sandbox still needs an Incus start before readiness and stack-up.
printf '%s\n' Stopped >"$LABCTL_FAKE_INSTANCE_STATE_FILE"
: >"$COMMAND_LOG"
PATH="${FAKE_BIN}:$PATH" LABCTL_FAKE_REJECT_DUPLICATE_START=true assert_succeeds "$LABCTL_BIN" --config "$CONFIG_PATH" start 'JIRA-#'
assert_command_log_contains 'start jira-#'
assert_command_log_ordered 'start jira-#' 'exec jira-# -- cloud-init status --wait'
assert_equals '1' "$(rg -F -c 'exec jira-# -- bash -s --' "$COMMAND_LOG" || true)"
unset LABCTL_FAKE_INSTANCE_STATE_FILE

# Bootstrap is the idempotent lifecycle entry point: it reuses an already-running
# sandbox without a duplicate Incus start, then executes the private stack hook once.
: >"$COMMAND_LOG"
BOOTSTRAP_REUSE_OUTPUT="${TEST_ROOT}/bootstrap-reuse-output"
PATH="${FAKE_BIN}:$PATH" LABCTL_FAKE_REJECT_DUPLICATE_START=true assert_succeeds "$LABCTL_BIN" --config "$CONFIG_PATH" bootstrap 'JIRA-#' >"$BOOTSTRAP_REUSE_OUTPUT"
assert_command_log_not_contains 'start jira-#'
assert_equals '1' "$(rg -F -c 'exec jira-# -- bash -s --' "$COMMAND_LOG" || true)"
assert_succeeds rg -F --quiet 'bootstrap: validate/create ticket=jira-#' "$BOOTSTRAP_REUSE_OUTPUT"
assert_succeeds rg -F --quiet 'bootstrap: running/ready ticket=jira-#' "$BOOTSTRAP_REUSE_OUTPUT"
assert_succeeds rg -F --quiet 'bootstrap: stack-up ticket=jira-#' "$BOOTSTRAP_REUSE_OUTPUT"

# A new valid ticket creates its sandbox, then follows the same start path exactly once.
mkdir -p "${TEST_ROOT}/workspace/bootstrap-new/one" "${TEST_ROOT}/workspace/bootstrap-new/two"
printf 'gitdir: %s\n' "${TEST_ROOT}/workspace/master/one/worktrees/bootstrap-new" >"${TEST_ROOT}/workspace/bootstrap-new/one/.git"
printf 'gitdir: %s\n' "${TEST_ROOT}/workspace/master/two/worktrees/bootstrap-new" >"${TEST_ROOT}/workspace/bootstrap-new/two/.git"
BOOTSTRAP_CONFIG="${TEST_ROOT}/bootstrap-config.env"
sed 's/^LABCTL_IP_POOL_END=.*/LABCTL_IP_POOL_END=10.42.0.12/' "$CONFIG_PATH" >"$BOOTSTRAP_CONFIG"
chmod 600 "$BOOTSTRAP_CONFIG"
LABCTL_FAKE_INSTANCE_DIRECTORY="${TEST_ROOT}/fake-instances"
export LABCTL_FAKE_INSTANCE_DIRECTORY
BOOTSTRAP_INSTANCE_CONFIG_JSON=$(jq -cn --arg master "${TEST_ROOT}/workspace/master" --arg ticket "${TEST_ROOT}/workspace/bootstrap-new" '{config:{"security.privileged":"false"},devices:{"git-master":{type:"disk",source:$master,path:$master},"ticket-workspace":{type:"disk",source:$ticket,path:$ticket}}}')
: >"$COMMAND_LOG"
PATH="${FAKE_BIN}:$PATH" LABCTL_FAKE_INSTANCE_EXISTS=false LABCTL_FAKE_INSTANCE_CONFIG_JSON="$BOOTSTRAP_INSTANCE_CONFIG_JSON" assert_succeeds "$LABCTL_BIN" --config "$BOOTSTRAP_CONFIG" bootstrap bootstrap-new
assert_command_log_contains 'init images:ubuntu/24.04 bootstrap-new'
assert_equals '1' "$(rg -F -c 'start bootstrap-new' "$COMMAND_LOG" || true)"
assert_equals '1' "$(rg -F -c 'exec bootstrap-new -- bash -s --' "$COMMAND_LOG" || true)"
assert_equals 'running' "$(labctl_state_lookup 'bootstrap-new' | jq -r '.status')"
unset LABCTL_FAKE_INSTANCE_DIRECTORY

# Bad tickets are rejected before any Incus command can touch the host.
: >"$COMMAND_LOG"
PATH="${FAKE_BIN}:$PATH" assert_fails "$LABCTL_BIN" --config "$CONFIG_PATH" bootstrap '../bad-ticket'
assert_command_log_not_contains 'incus '

: >"$COMMAND_LOG"
if ! PATH="${FAKE_BIN}:$PATH" "$LABCTL_BIN" --config "$CONFIG_PATH" --dry-run verify 'JIRA-#' >>"$COMMAND_LOG" 2>&1; then
	fail 'dry-run verify failed'
fi
assert_command_log_contains 'nc -z -w 3 10.42.0.10 10001'
assert_command_log_contains 'nc -z -w 3 10.42.0.10 10002'
assert_command_log_contains 'exec jira-# -- bash -s --'
assert_command_log_not_contains 'config device add jira-# proxy'

: >"$COMMAND_LOG"
PATH="${FAKE_BIN}:$PATH" assert_succeeds labctl_stack_up 'JIRA-#'
PATH="${FAKE_BIN}:$PATH" assert_succeeds labctl_stack_down 'JIRA-#'
assert_command_log_contains 'exec jira-# -- bash -s --'
STACK_REMOTE_SCRIPT="${TEST_ROOT}/stack-remote-script"
: >"$COMMAND_LOG"
PATH="${FAKE_BIN}:$PATH" LABCTL_FAKE_CAPTURE_REMOTE_SCRIPT="$STACK_REMOTE_SCRIPT" assert_succeeds labctl_stack_up 'JIRA-#'
assert_succeeds rg -F --quiet 'stack_command=IMAGE_IMPORT=false\ ./private-pcm-setup.sh\ --token=stack-command-secret-not-for-logs' "$STACK_REMOTE_SCRIPT"
assert_command_log_not_contains 'IMAGE_IMPORT=false'
assert_command_log_not_contains 'stack-command-secret-not-for-logs'
assert_fails rg -F --quiet 'stack-command-secret-not-for-logs' "$COMMAND_LOG"

labctl_verify_ports_when_closed() {
	LABCTL_FAKE_CLOSED_PORT=$1 labctl_verify_ports 'JIRA-#'
}
PATH="${FAKE_BIN}:$PATH" assert_fails labctl_verify_ports_when_closed 10001
labctl_fake_instance_config() {
	jq -cn --arg master "${TEST_ROOT}/workspace/master" --arg ticket "${TEST_ROOT}/workspace/jira-#" --argjson policy "$1" '
		$policy | .devices = ((.devices // {}) + {
			"git-master": {type: "disk", source: $master, path: $master},
			"ticket-workspace": {type: "disk", source: $ticket, path: $ticket}
		})
	'
}

export LABCTL_FAKE_INSTANCE_CONFIG_JSON
LABCTL_FAKE_INSTANCE_CONFIG_JSON=$(labctl_fake_instance_config '{"config":{"security.privileged":"true"}}')
PATH="${FAKE_BIN}:$PATH" assert_fails "$LABCTL_BIN" --config "$CONFIG_PATH" verify 'JIRA-#'
LABCTL_FAKE_INSTANCE_CONFIG_JSON=$(labctl_fake_instance_config '{"config":{},"devices":{"hostnic":{"type":"nic","network":"host"}}}')
PATH="${FAKE_BIN}:$PATH" assert_fails "$LABCTL_BIN" --config "$CONFIG_PATH" verify 'JIRA-#'
LABCTL_FAKE_INSTANCE_CONFIG_JSON=$(labctl_fake_instance_config '{"config":{},"devices":{"docker":{"type":"disk","source":"/var/run/docker.sock","path":"/var/run/docker.sock"}}}')
PATH="${FAKE_BIN}:$PATH" assert_fails "$LABCTL_BIN" --config "$CONFIG_PATH" verify 'JIRA-#'
LABCTL_FAKE_INSTANCE_CONFIG_JSON=$(labctl_fake_instance_config '{"config":{},"devices":{"proxy":{"type":"proxy","listen":"tcp:0.0.0.0:10001"}}}')
PATH="${FAKE_BIN}:$PATH" assert_fails "$LABCTL_BIN" --config "$CONFIG_PATH" verify 'JIRA-#'
LABCTL_FAKE_INSTANCE_CONFIG_JSON=$(labctl_fake_instance_config '{"config":{"security.privileged":"false"}}')

: >"$COMMAND_LOG"
PATH="${FAKE_BIN}:$PATH" assert_succeeds labctl_verify_ports 'JIRA-#'
PATH="${FAKE_BIN}:$PATH" assert_succeeds labctl_verify_ports 'jira-two'
assert_command_log_contains 'nc -z -w 3 10.42.0.10 10001'
assert_command_log_contains 'nc -z -w 3 10.42.0.11 10001'
assert_command_log_not_contains ' proxy '

# Task 5 documentation contract: the committed guide must remain runnable yet sanitized.
DOC_README="${REPO_ROOT}/incus/README.md"
[[ -f $DOC_README ]] || fail 'Incus operator README is missing'

if [[ -f $DOC_README ]]; then
	for public_command in preflight setup-host create bootstrap start stop status verify destroy cleanup-worktree; do
		rg -F --quiet "labctl ${public_command}" "$DOC_README" || fail "README does not document labctl ${public_command}"
	done
	for required_option in --yes --dry-run; do
		rg -F --quiet -- "$required_option" "$DOC_README" || fail "README does not document ${required_option}"
	done

	# Reject values that would disclose a private topology or credentials. Generic
	# placeholders and shell variables are intentionally permitted.
	if rg -n --pcre2 '/(home|Users)/[[:alnum:]_.-]+' "$DOC_README"; then
		fail 'README contains a concrete user path'
	fi
	if rg -n --pcre2 '\b[A-Z][A-Z0-9]+-[0-9]+\b' "$DOC_README"; then
		fail 'README contains a concrete ticket identifier'
	fi
	if rg -n --pcre2 '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b' "$DOC_README"; then
		fail 'README contains a concrete IP address'
	fi
	if rg -n --pcre2 '(?i)\b(?:tcp[[:space:]]+)?port(?:[[:space:]]+number)?[[:space:]]*[:=]?[[:space:]]*[0-9]{2,5}\b' "$DOC_README"; then
		fail 'README contains a concrete port number'
	fi
	if rg -n --pcre2 -- '--repo[[:space:]]+(?!<repo>)[^[:space:]]+' "$DOC_README"; then
		fail 'README contains a concrete repository name'
	fi
	if rg -n --pcre2 '(?i)\b(?:service|stack)[[:space:]]*(?:name|identifier)?[[:space:]]*[:=][[:space:]]*[[:alnum:]_.-]+' "$DOC_README"; then
		fail 'README contains a private service identifier'
	fi
	if rg -n --pcre2 '(?i)(password|token|secret|credential)[[:space:]]*[:=][[:space:]]*[^ <]' "$DOC_README"; then
		fail 'README contains a credential value'
	fi
fi

# Credential delivery: sync reads host Git credentials through stdin/stdout only,
# sends a restrictive temporary API payload, and never prints the secret.
CREDENTIAL_SECRET=$(printf '%s%s' 'credential-test-token-' 'not-for-logs')
CREDENTIAL_NAME='git-module-token'
PATCH_VALIDATION="${TEST_ROOT}/patch-validation"
cat >"${FAKE_BIN}/git" <<'GIT'
#!/usr/bin/env bash
printf 'git %s\n' "$*" >>"$COMMAND_LOG"
if [[ ${1:-} == credential && ${2:-} == fill ]]; then
  cat >/dev/null
  printf 'protocol=https\nhost=git.example.test\nusername=credential-user\npassword=%s\n\n' "$LABCTL_FAKE_GIT_PASSWORD"
fi
GIT
cat >"${FAKE_BIN}/systemd-creds" <<'CREDS'
#!/usr/bin/env bash
printf 'systemd-creds %s\n' "$*" >>"$COMMAND_LOG"
[[ ${1:-} == cat ]] || exit 2
printf '%s\n%s\n' credential-user "$LABCTL_FAKE_GIT_PASSWORD"
CREDS
cat >"${FAKE_BIN}/askpass-probe" <<'PROBE'
#!/usr/bin/env bash
username=$("$GIT_ASKPASS" 'Username for https://git.example.test:')
password=$("$GIT_ASKPASS" 'Password for https://git.example.test:')
printf '%s:%s\n' "$username" "$password" | sha256sum | cut -d' ' -f1 >"$LABCTL_ASKPASS_PROBE_HASH"
exit 17
PROBE
chmod +x "${FAKE_BIN}/git" "${FAKE_BIN}/systemd-creds" "${FAKE_BIN}/askpass-probe"

# Capture API payloads without writing their content to the command log. Incus
# must receive the JSON from a temporary file through --data-file, not a
# literal @temporary-file value passed through --data.
: >"$COMMAND_LOG"
PATH="${FAKE_BIN}:$PATH" LABCTL_FAKE_GIT_PASSWORD="$CREDENTIAL_SECRET" LABCTL_FAKE_PATCH_VALIDATION="$PATCH_VALIDATION" assert_succeeds "$LABCTL_BIN" --config "$CONFIG_PATH" credential sync 'JIRA-#'
assert_equals 'valid' "$(cat "$PATCH_VALIDATION")"
assert_command_log_contains 'git credential fill'
assert_command_log_contains 'incus query /1.0/instances/jira-%23 --request PATCH --data-file '
assert_command_log_not_contains ' --data @'
assert_command_log_not_contains "$CREDENTIAL_SECRET"
assert_command_log_not_contains 'username=credential-user'
assert_command_log_not_contains 'password='
assert_fails rg -F --quiet "$CREDENTIAL_SECRET" "${REPO_ROOT}/incus" "${REPO_ROOT}/tests/incus" "$CONFIG_PATH" "${XDG_STATE_HOME}"

# Names must map to exactly one safe systemd credential key and no other
# instance configuration.  Invalid configured names fail before Git runs.
INVALID_CREDENTIAL_CONFIG="${TEST_ROOT}/invalid-credential-name.env"
sed 's/^LABCTL_GIT_CREDENTIAL_NAME=.*/LABCTL_GIT_CREDENTIAL_NAME=bad name/' "$CONFIG_PATH" >"$INVALID_CREDENTIAL_CONFIG"
chmod 600 "$INVALID_CREDENTIAL_CONFIG"
: >"$COMMAND_LOG"
PATH="${FAKE_BIN}:$PATH" assert_fails "$LABCTL_BIN" --config "$INVALID_CREDENTIAL_CONFIG" credential sync 'JIRA-#'
assert_command_log_not_contains 'git credential fill'

: >"$COMMAND_LOG"
rm -f "$PATCH_VALIDATION"
PATH="${FAKE_BIN}:$PATH" LABCTL_FAKE_PATCH_VALIDATION="$PATCH_VALIDATION" assert_succeeds "$LABCTL_BIN" --config "$CONFIG_PATH" credential unset 'JIRA-#'
assert_equals 'valid' "$(cat "$PATCH_VALIDATION")"
assert_command_log_contains 'incus query /1.0/instances/jira-%23 --request PATCH --data-file '
assert_command_log_not_contains ' --data @'
assert_command_log_not_contains "$CREDENTIAL_SECRET"

# The guest wrapper creates a root-only temporary askpass helper, obtains its
# values only at runtime through systemd-creds, and removes the helper directory
# even when the wrapped stack command fails.
REMOTE_SCRIPT="${TEST_ROOT}/remote-stack.sh"
REMOTE_RUNTIME="${TEST_ROOT}/remote-run"
REMOTE_PROBE_HASH="${TEST_ROOT}/askpass-hash"
mkdir -p "$REMOTE_RUNTIME"
: >"$COMMAND_LOG"
PATH="${FAKE_BIN}:$PATH" LABCTL_FAKE_CAPTURE_REMOTE_SCRIPT="$REMOTE_SCRIPT" LABCTL_FAKE_GIT_PASSWORD="$CREDENTIAL_SECRET" assert_succeeds labctl_incus_stack_command 'jira-#' "${TEST_ROOT}/workspace/jira-#" 'askpass-probe'
# shellcheck disable=SC2016 # Inspect the generated helper's literal variable expansion.
assert_succeeds rg -F --quiet 'systemd-creds cat "$credential_name"' "$REMOTE_SCRIPT"
assert_succeeds rg -F --quiet 'trap cleanup EXIT HUP INT TERM' "$REMOTE_SCRIPT"
# shellcheck disable=SC2016 # Inspect the generated cleanup command literally.
assert_succeeds rg -F --quiet 'rm -rf -- "$runtime_dir"' "$REMOTE_SCRIPT"
assert_fails rg -F --quiet "$CREDENTIAL_SECRET" "$REMOTE_SCRIPT"

set +e
PATH="${FAKE_BIN}:$PATH" LABCTL_GIT_ASKPASS_RUNTIME_DIR="$REMOTE_RUNTIME" LABCTL_ASKPASS_PROBE_HASH="$REMOTE_PROBE_HASH" LABCTL_FAKE_GIT_PASSWORD="$CREDENTIAL_SECRET" bash "$REMOTE_SCRIPT" "${TEST_ROOT}/workspace/jira-#" "$CREDENTIAL_NAME" git.example.test 'askpass-probe'
remote_status=$?
set -e
assert_equals '17' "$remote_status"
assert_equals "$(printf 'credential-user:%s\n' "$CREDENTIAL_SECRET" | sha256sum | cut -d' ' -f1)" "$(cat "$REMOTE_PROBE_HASH")"
assert_equals '0' "$(find "$REMOTE_RUNTIME" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')"
assert_command_log_not_contains "$CREDENTIAL_SECRET"

finish_tests
