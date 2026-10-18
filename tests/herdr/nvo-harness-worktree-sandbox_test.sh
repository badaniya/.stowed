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

TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/home/.config/herdr-spreader" "$TEST_ROOT/home/.local/bin"
LOG="$TEST_ROOT/commands.log"

cat >"$TEST_ROOT/home/.config/herdr-spreader/nvo-harness-worktree.sh" <<'EOF'
#!/usr/bin/env bash
printf 'worktree deferred=%s args=%s\n' "${NVO_HARNESS_DEFER_WORKSPACE:-}" "$*" >>"${TEST_LOG:?}"
EOF
cat >"$TEST_ROOT/home/.local/bin/labctl" <<'EOF'
#!/usr/bin/env bash
printf 'labctl %s\n' "$*" >>"${TEST_LOG:?}"
if [[ ${1:-} == instance-user ]]; then
	printf '%s\n' "${TEST_INSTANCE_USER:-sandbox-user}"
elif [[ ${1:-} == template && ${TEST_FAIL_TEMPLATE:-false} == true ]]; then
	exit 1
fi
EOF
cat >"$TEST_ROOT/bin/sg" <<'EOF'
#!/usr/bin/env bash
[[ $1 == incus-admin && $2 == -c ]] || exit 2
printf 'sg %s\n' "$3" >>"${TEST_LOG:?}"
bash -c "$3"
EOF
cat >"$TEST_ROOT/bin/herdr" <<'EOF'
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
EOF
chmod +x "$TEST_ROOT/home/.config/herdr-spreader/nvo-harness-worktree.sh" "$TEST_ROOT/home/.local/bin/labctl" "$TEST_ROOT/bin/sg" "$TEST_ROOT/bin/herdr"
printf '2\n' >"$TEST_ROOT/herdr-counter"

HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$PATH" TEST_LOG="$LOG" TEST_HERDR_COUNTER="$TEST_ROOT/herdr-counter" "$SCRIPT" 'NVO-20131 25.16.0 --restore-harness'
assert_contains 'worktree deferred=true args=NVO-20131 25.16.0 --restore-harness' "$LOG"
assert_contains 'labctl credential sync NVO-20131' "$LOG"
assert_contains 'labctl bootstrap NVO-20131' "$LOG"
assert_contains 'labctl template sync NVO-20131' "$LOG"
assert_contains 'labctl instance-user' "$LOG"
assert_ordered 'labctl credential sync NVO-20131' 'labctl bootstrap NVO-20131' "$LOG"
assert_ordered 'labctl bootstrap NVO-20131' 'labctl template sync NVO-20131' "$LOG"
assert_ordered 'labctl template sync NVO-20131' 'herdr workspace create' "$LOG"
assert_contains 'herdr tab rename w1:t1 1 - Agent' "$LOG"
assert_contains 'herdr tab create --workspace w1 --cwd ' "$LOG"
assert_contains '--label 2 - Build --no-focus' "$LOG"
assert_contains 'incus exec nvo-20131 -- su - sandbox-user -c' "$LOG"
for path in /var/log/network/network-server.log /var/log/edge/edge-server.log /var/log/scheduler/scheduler-server.log /var/log/runonce/runonce-server.log /var/log/system/system-server.log; do
	assert_contains "$path" "$LOG"
done
assert_contains 'tail\ -F' "$LOG"
assert_contains 'loggo\ stream\ -t\ ~/.private-nvo-loggo.tpl' "$LOG"
assert_contains 'lazydocker' "$LOG"
for directory in PlatformCommonModels/scripts/development PlatformServices/scripts/development GoDCApp/NVO/scripts/development; do
	assert_contains "$directory" "$LOG"
done
assert_not_contains 'docker.sock' "$LOG"

: >"$LOG"
printf '2\n' >"$TEST_ROOT/herdr-counter"
if HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$PATH" TEST_LOG="$LOG" TEST_HERDR_COUNTER="$TEST_ROOT/herdr-counter" TEST_FAIL_TEMPLATE=true "$SCRIPT" 'NVO-20131 25.16.0'; then
	fail 'template sync failure was accepted'
fi
assert_contains 'labctl template sync NVO-20131' "$LOG"
assert_not_contains 'herdr workspace create' "$LOG"

: >"$LOG"
if HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$PATH" TEST_LOG="$LOG" TEST_HERDR_COUNTER="$TEST_ROOT/herdr-counter" "$SCRIPT" 'NVO-20131; rm -rf / 25.16.0'; then
	fail 'malformed ticket was accepted'
fi
[[ ! -s $LOG ]] || fail 'malformed ticket ran worktree or labctl commands'
