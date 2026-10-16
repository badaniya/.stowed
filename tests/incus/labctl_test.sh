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

finish_tests
