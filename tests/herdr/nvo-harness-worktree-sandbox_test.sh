#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="${REPO_ROOT}/herdr/.config/herdr-spreader/nvo-harness-worktree-sandbox.sh"

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

assert_contains() {
	local expected=$1 path=$2
	rg -F --quiet -- "$expected" "$path" || fail "expected ${path} to contain: ${expected}"
}

assert_not_contains() {
	local unexpected=$1 path=$2
	if rg -F --quiet -- "$unexpected" "$path"; then
		fail "expected ${path} not to contain: ${unexpected}"
	fi
}

assert_ordered() {
	local first=$1 second=$2 path=$3 first_line second_line
	first_line=$(rg -n -F "$first" "$path" | sed -n '1s/:.*//p' || true)
	second_line=$(rg -n -F "$second" "$path" | sed -n '1s/:.*//p' || true)
	[[ -n $first_line && -n $second_line && $first_line -lt $second_line ]] || fail "expected ${first} before ${second}"
}

wait_for_marker() {
	local marker=$1 path=$2 attempts=50
	while ((attempts > 0)); do
		rg -F --quiet -- "$marker" "$path" 2>/dev/null && return 0
		sleep 0.05
		attempts=$((attempts - 1))
	done
	fail "timed out waiting for ${marker} in ${path}"
}

TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/home/.config/herdr-spreader" "$TEST_ROOT/home/.local/bin"
LOG="$TEST_ROOT/commands.log"
STATE_LOG="$TEST_ROOT/state/herdr-spreader/NVO-20131.log"

cat >"$TEST_ROOT/home/.config/herdr-spreader/nvo-harness-worktree-sandbox-base.sh" <<'EOF_BASE'
#!/usr/bin/env bash
printf 'worktree deferred=%s args=%s\n' "${NVO_HARNESS_DEFER_WORKSPACE:-}" "$*" >>"${TEST_LOG:?}"
EOF_BASE
cat >"$TEST_ROOT/home/.local/bin/labctl" <<'EOF_LABCTL'
#!/usr/bin/env bash
printf 'labctl %s\n' "$*" >>"${TEST_LOG:?}"
if [[ ${1:-} == instance-user ]]; then
	printf '%s\n' "${TEST_INSTANCE_USER:-sandbox-user}"
elif [[ ${1:-} == template && ${TEST_FAIL_TEMPLATE:-false} == true ]]; then
	exit 1
fi
EOF_LABCTL
cat >"$TEST_ROOT/bin/sg" <<'EOF_SG'
#!/usr/bin/env bash
[[ $1 == incus-admin && $2 == -c ]] || exit 2
printf 'sg %s\n' "$3" >>"${TEST_LOG:?}"
bash -c "$3"
EOF_SG
cat >"$TEST_ROOT/bin/jira" <<'EOF_JIRA'
#!/usr/bin/env bash
[[ $1 == issue && $2 == view && $3 == NVO-20131 && $4 == --raw ]] || exit 2
printf '%s\n' '{"fields":{"summary":"Sandbox workspace title"}}'
EOF_JIRA
cat >"$TEST_ROOT/bin/herdr" <<'EOF_HERDR'
#!/usr/bin/env bash
printf 'herdr %s\n' "$*" >>"${TEST_LOG:?}"
case "${1:-} ${2:-}" in
'workspace create') printf '%s\n' '{"result":{"workspace":{"workspace_id":"w1"},"tab":{"tab_id":"w1:t1"},"root_pane":{"pane_id":"w1:p1"}}}' ;;
'pane split')
	counter_file=${TEST_HERDR_COUNTER:?}
	counter=$(cat "$counter_file")
	counter=$((counter + 1))
	printf '%s\n' "$counter" >"$counter_file"
	printf '{"result":{"pane":{"pane_id":"w1:p%s"}}}\n' "$counter"
	;;
'pane run' | 'pane rename' | 'tab rename') : ;;
'tab create') printf '%s\n' '{"result":{"tab":{"tab_id":"w1:t2"},"root_pane":{"pane_id":"w1:p2"}}}' ;;
*) exit 2 ;;
esac
EOF_HERDR
chmod +x "$TEST_ROOT/home/.config/herdr-spreader/nvo-harness-worktree-sandbox-base.sh" "$TEST_ROOT/home/.local/bin/labctl" "$TEST_ROOT/bin/sg" "$TEST_ROOT/bin/jira" "$TEST_ROOT/bin/herdr"

run_sandbox() {
	HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$PATH" XDG_STATE_HOME="$TEST_ROOT/state" TEST_LOG="$LOG" TEST_HERDR_COUNTER="$TEST_ROOT/herdr-counter" TEST_INSTANCE_USER=nvo-builder "$SCRIPT" 'NVO-20131 25.16.0 --restore-harness'
}

: >"$LOG"
printf '2\n' >"$TEST_ROOT/herdr-counter"
run_sandbox
wait_for_marker 'NVO_SANDBOX_BOOTSTRAP_SUCCESS' "$STATE_LOG"
assert_contains 'worktree deferred=true args=NVO-20131 25.16.0 --restore-harness' "$LOG"
assert_contains 'herdr workspace create' "$LOG"
assert_contains 'NVO-20131 - Sandbox workspace title' "$LOG"
assert_contains 'herdr tab create --workspace w1' "$LOG"
assert_ordered 'herdr workspace create' 'labctl create NVO-20131' "$LOG"
assert_contains '→ Creating sandbox NVO-20131…' "$STATE_LOG"
assert_contains '→ Syncing the host Git credential into sandbox NVO-20131…' "$STATE_LOG"
assert_contains '→ Bootstrapping sandbox NVO-20131…' "$STATE_LOG"
assert_contains '→ Syncing private Loggo template into sandbox NVO-20131…' "$STATE_LOG"
assert_ordered '→ Creating sandbox NVO-20131…' '→ Syncing the host Git credential into sandbox NVO-20131…' "$STATE_LOG"
assert_ordered '→ Syncing the host Git credential into sandbox NVO-20131…' '→ Bootstrapping sandbox NVO-20131…' "$STATE_LOG"
assert_ordered '→ Bootstrapping sandbox NVO-20131…' '→ Syncing private Loggo template into sandbox NVO-20131…' "$STATE_LOG"
assert_contains 'tail -n +1 -F' "$LOG"
assert_contains "$STATE_LOG" "$LOG"
assert_contains 'NVO_SANDBOX_BOOTSTRAP_SUCCESS' "$LOG"
assert_contains 'until sg incus-admin -c' "$LOG"
assert_contains 'incus' "$LOG"
assert_contains 'nvo-20131' "$LOG"
assert_contains 'true' "$LOG"
assert_contains 'lazydocker' "$LOG"
assert_not_contains 'docker.sock' "$LOG"
assert_not_contains 'docker info' "$LOG"

: >"$LOG"
printf '2\n' >"$TEST_ROOT/herdr-counter"
: >"$STATE_LOG"
if HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$PATH" XDG_STATE_HOME="$TEST_ROOT/state" TEST_LOG="$LOG" TEST_HERDR_COUNTER="$TEST_ROOT/herdr-counter" TEST_INSTANCE_USER=nvo-builder TEST_FAIL_TEMPLATE=true "$SCRIPT" 'NVO-20131 25.16.0'; then
	:
else
	fail 'asynchronous bootstrap failure blocked workspace creation'
fi
wait_for_marker 'NVO_SANDBOX_BOOTSTRAP_FAILED' "$STATE_LOG"
assert_contains '→ Syncing private Loggo template into sandbox NVO-20131…' "$STATE_LOG"
assert_contains 'herdr workspace create' "$LOG"
assert_not_contains 'NVO_SANDBOX_BOOTSTRAP_SUCCESS' "$STATE_LOG"
