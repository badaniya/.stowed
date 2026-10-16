#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=test_helper.sh
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
source "${LABCTL_LIB}/host-setup.sh"

export HOME="${TEST_ROOT}/home"
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
LABCTL_DEVICE_TCP_PORTS=10001,10002
LABCTL_STACK_UP_COMMAND=compose up -d
LABCTL_STACK_DOWN_COMMAND=compose down
LABCTL_STACK_HEALTH_COMMAND=compose ps
LABCTL_WORKTREE_CREATE_HOOK=/bin/true
LABCTL_WORKTREE_REMOVE_HOOK=/bin/true
LABCTL_HARNESS_REPO_NAMES=one,two
CONFIG
chmod 600 "$CONFIG_PATH"
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
case "$*" in
'info --format json') printf '%s\n' '{"environment":{"kernel_features":{"idmapped_mounts":true}}}' ;;
'info') [[ ${LABCTL_INCUS_ACCESS_DENIED:-false} != true ]] ;;
'network show agentbr0') exit 1 ;;
'profile show agent-dev-env --format json')
	if [[ -n ${LABCTL_UNSAFE_PROFILE_JSON:-} ]]; then
		printf '%s\n' "$LABCTL_UNSAFE_PROFILE_JSON"
	else
		exit 1
	fi
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
for fake_command in incus ip sysctl df lxc multipass docker; do chmod +x "${FAKE_BIN}/${fake_command}"; done

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

# These fixtures model every profile shape that would expose host networking or devices.
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
	'{"devices":{"eth0":{"type":"nic","network":"agentbr0","name":"eth0"},"eth1":{"type":"nic","network":"agentbr0","name":"eth1"}}}' \
	'{"devices":{"gpu":{"type":"gpu"}}}'; do
	PATH="${FAKE_BIN}:$PATH" LABCTL_UNSAFE_PROFILE_JSON="$unsafe_profile_json" assert_fails "$LABCTL_BIN" --config "$CONFIG_PATH" preflight
done

finish_tests
