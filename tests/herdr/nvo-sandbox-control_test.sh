#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="${REPO_ROOT}/herdr/.config/herdr-spreader/nvo-sandbox-control.sh"

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

assert_equals() {
	local expected=$1 actual=$2 message=${3:-}
	[[ $actual == "$expected" ]] || fail "${message:-expected ${expected@Q}, got ${actual@Q}}"
}

assert_file_equals() {
	local expected=$1 path=$2 actual
	actual=$(<"$path")
	assert_equals "$expected" "$actual" "unexpected contents in $path"
}

TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/home/.local/bin" "$TEST_ROOT/state/labctl"
LOG="$TEST_ROOT/commands.log"
PLAN_PATH_FILE="$TEST_ROOT/plan-path"

cat >"$TEST_ROOT/state/labctl/sandboxes.json" <<'EOF_REGISTRY'
{
  "schema_version": 1,
  "sandboxes": {
    "NVO-20130": {"status": "running"},
    "NVO-20224": {"status": "stopped"},
    "NVO-20999": {"status": "destroyed"},
    "not-a-ticket": {"status": "running"}
  }
}
EOF_REGISTRY

cat >"$TEST_ROOT/bin/herdr" <<'EOF_HERDR'
#!/usr/bin/env bash
set -euo pipefail
printf 'herdr %s\n' "$*" >>"${TEST_LOG:?}"
case "${1:-} ${2:-}" in
'pane split')
	[[ ${3:-} == "w1:p1" && ${4:-} == --direction && ${5:-} == down && ${6:-} == --focus ]] || exit 2
	printf '%s\n' '{"result":{"pane":{"pane_id":"w1:p2"}}}'
	;;
'pane run')
	[[ ${4:-} =~ --plan[[:space:]]([^[:space:]]+) ]] || exit 2
	printf '%s\n' "${BASH_REMATCH[1]}" >"${TEST_PLAN_PATH:?}"
	;;
*) exit 2 ;;
esac
EOF_HERDR

cat >"$TEST_ROOT/bin/sg" <<'EOF_SG'
#!/usr/bin/env bash
set -euo pipefail
printf 'sg %s\n' "$*" >>"${TEST_LOG:?}"
[[ $1 == incus-admin && $2 == -c ]] || exit 2
bash -c "$3"
EOF_SG

cat >"$TEST_ROOT/home/.local/bin/labctl" <<'EOF_LABCTL'
#!/usr/bin/env bash
printf 'labctl %s\n' "$*" >>"${TEST_LOG:?}"
EOF_LABCTL
chmod +x "$TEST_ROOT/bin/herdr" "$TEST_ROOT/bin/sg" "$TEST_ROOT/home/.local/bin/labctl"

run_controller() {
	HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$PATH" XDG_STATE_HOME="$TEST_ROOT/state" TEST_LOG="$LOG" TEST_PLAN_PATH="$PLAN_PATH_FILE" HERDR_PLUS_PANE_ID="${TEST_PANE_ID-w1:p1}" "$SCRIPT" "$@"
}

# status NVO-20130,NVO-20224 creates one ordered plan and one focused sibling pane.
: >"$LOG"
run_controller status NVO-20130,NVO-20224
PLAN_PATH=$(<"$PLAN_PATH_FILE")
[[ -f $PLAN_PATH ]] || fail 'controller did not create the plan file'
[[ $(stat -c '%a' "$PLAN_PATH") == 600 ]] || fail 'plan file is not owner-only'
assert_file_equals $'operation=status\nNVO-20130\nNVO-20224' "$PLAN_PATH"
assert_equals 1 "$(rg -c '^herdr pane split ' "$LOG")" 'expected one focused pane split'
assert_equals 1 "$(rg -c '^herdr pane run ' "$LOG")" 'expected one dialog command'

# status all omits destroyed records while retaining registry ticket order.
: >"$LOG"
run_controller status all
PLAN_PATH=$(<"$PLAN_PATH_FILE")
assert_file_equals $'operation=status\nNVO-20130\nNVO-20224' "$PLAN_PATH"
assert_equals 1 "$(rg -c '^herdr pane split ' "$LOG")" 'expected one focused pane split for all'

# Invalid or duplicate targets fail before any Herdr pane mutation.
: >"$LOG"
if run_controller start NVO-20130,NVO-20130,not-a-ticket; then
	fail 'invalid duplicate target list unexpectedly succeeded'
fi
[[ ! -s $LOG ]] || fail 'invalid target list mutated Herdr or invoked a command'

# Empty CSV fields must fail before any Herdr pane split or dialog command.
: >"$LOG"
if run_controller status 'NVO-20130,'; then
	fail 'trailing empty CSV field unexpectedly succeeded'
fi
[[ ! -s $LOG ]] || fail 'trailing empty CSV field split or ran a Herdr pane'

: >"$LOG"
if run_controller status ',NVO-20130'; then
	fail 'leading empty CSV field unexpectedly succeeded'
fi
[[ ! -s $LOG ]] || fail 'leading empty CSV field split or ran a Herdr pane'

: >"$LOG"
if run_controller status 'NVO-20130,,NVO-20224'; then
	fail 'adjacent empty CSV fields unexpectedly succeeded'
fi
[[ ! -s $LOG ]] || fail 'adjacent empty CSV fields split or ran a Herdr pane'

# The invoking pane must be available and valid before a focused sibling can open.
: >"$LOG"
if TEST_PANE_ID='' run_controller status NVO-20130; then
	fail 'missing HERDR_PLUS_PANE_ID unexpectedly succeeded'
fi
[[ ! -s $LOG ]] || fail 'missing pane ID mutated Herdr or invoked a command'

printf '%s\n' 'PASS: nvo-sandbox-control'
