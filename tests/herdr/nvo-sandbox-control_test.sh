#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="${REPO_ROOT}/herdr/.config/herdr-spreader/nvo-sandbox-control.sh"
DIALOG_SCRIPT="${REPO_ROOT}/herdr/.config/herdr-spreader/nvo-sandbox-control-dialog.sh"

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
    "nvo-20130": {"status": "running"},
    "nvo-20224": {"status": "stopped"},
    "nvo-20999": {"status": "destroyed"},
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
	split_response=${TEST_SPLIT_RESPONSE:-}
	[[ -n $split_response ]] || split_response='{"result":{"pane":{"pane_id":"w1:p2"}}}'
	printf '%s\n' "$split_response"
	;;
'pane run')
	[[ ${4:-} =~ --plan[[:space:]]([^[:space:]]+) ]] || exit 2
	printf '%s\n' "${BASH_REMATCH[1]}" >"${TEST_PLAN_PATH:?}"
	[[ ${TEST_FAIL_PANE_RUN:-} != true ]]
	;;
'pane close')
	[[ ${3:-} == -- && ${4:-} == "${TEST_EXPECT_CLOSED_PANE:-w1:p2}" && $# -eq 4 ]] || exit 2
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
set -euo pipefail
printf 'labctl %s\n' "$*" >>"${TEST_LOG:?}"
if [[ ${TEST_FAIL_STOP_FOR:-} == "$2" && $1 == stop ]]; then
	exit 1
fi
EOF_LABCTL
chmod +x "$TEST_ROOT/bin/herdr" "$TEST_ROOT/bin/sg" "$TEST_ROOT/home/.local/bin/labctl"

run_controller() {
	HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$TEST_ROOT/home/.local/bin:$PATH" XDG_STATE_HOME="$TEST_ROOT/state" TEST_LOG="$LOG" TEST_PLAN_PATH="$PLAN_PATH_FILE" HERDR_PLUS_PANE_ID="${TEST_PANE_ID-w1:p1}" "$SCRIPT" "$@"
}

write_plan() {
	local operation=$1 scope=$2
	shift 2
	DIALOG_PLAN="$TEST_ROOT/state/herdr-spreader/nvo-sandbox-control.dialog-test"
	mkdir -p "${DIALOG_PLAN%/*}"
	chmod 0700 "${DIALOG_PLAN%/*}"
	{
		printf 'operation=%s\n' "$operation"
		printf 'scope=%s\n' "$scope"
		printf '%s\n' "$@"
	} >"$DIALOG_PLAN"
	chmod 0600 "$DIALOG_PLAN"
}

run_dialog() {
	HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$PATH" XDG_STATE_HOME="$TEST_ROOT/state" TEST_LOG="$LOG" "$DIALOG_SCRIPT" --plan "$DIALOG_PLAN"
}

# status NVO-20130,NVO-20224 creates one ordered plan and one focused sibling pane.
: >"$LOG"
run_controller status NVO-20130,NVO-20224
PLAN_PATH=$(<"$PLAN_PATH_FILE")
[[ -f $PLAN_PATH ]] || fail 'controller did not create the plan file'
[[ $(stat -c '%a' "$PLAN_PATH") == 600 ]] || fail 'plan file is not owner-only'
assert_file_equals $'operation=status\nscope=explicit\nNVO-20130\nNVO-20224' "$PLAN_PATH"
assert_equals 1 "$(rg -c '^herdr pane split ' "$LOG")" 'expected one focused pane split'
assert_equals 1 "$(rg -c '^herdr pane run ' "$LOG")" 'expected one dialog command'

# status all omits destroyed records while retaining registry ticket order.
: >"$LOG"
run_controller status all
PLAN_PATH=$(<"$PLAN_PATH_FILE")
assert_file_equals $'operation=status\nscope=all\nNVO-20130\nNVO-20224' "$PLAN_PATH"
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

# An option-shaped split response is rejected, but rollback treats it as a close target rather than a close option.
: >"$LOG"
plans_before=$(rg --files -g 'nvo-sandbox-control.*' "$TEST_ROOT/state/herdr-spreader" | wc -l)
unsafe_pane_id='--all'
printf -v unsafe_split_response '{"result":{"pane":{"pane_id":"%s"}}}' "$unsafe_pane_id"
if TEST_SPLIT_RESPONSE="$unsafe_split_response" TEST_EXPECT_CLOSED_PANE="$unsafe_pane_id" run_controller status NVO-20130; then
	fail 'controller unexpectedly accepted an unsafe sandbox control pane ID'
fi
assert_equals 1 "$(rg -c '^herdr pane split ' "$LOG")" 'expected one focused pane split before response validation failure'
assert_equals 1 "$(rg -F -c "herdr pane close -- $unsafe_pane_id" "$LOG")" 'controller did not guard the option-shaped rollback pane ID'
assert_equals "$plans_before" "$(rg --files -g 'nvo-sandbox-control.*' "$TEST_ROOT/state/herdr-spreader" | wc -l)" 'controller did not remove the response-validation-failed plan file'

# If queuing the dialog fails after a focused split, the controller closes only that new pane and removes its plan.
: >"$LOG"
if TEST_FAIL_PANE_RUN=true run_controller status NVO-20130; then
	fail 'controller unexpectedly succeeded when the dialog could not start'
fi
assert_equals 1 "$(rg -c '^herdr pane split ' "$LOG")" 'expected one focused pane split before pane-run failure'
assert_equals 1 "$(rg -c '^herdr pane run ' "$LOG")" 'expected one pane-run attempt'
assert_equals 1 "$(rg -c '^herdr pane close -- w1:p2$' "$LOG")" 'controller did not roll back the newly created pane'
PLAN_PATH=$(<"$PLAN_PATH_FILE")
[[ ! -e $PLAN_PATH ]] || fail 'controller did not remove the rolled-back plan file'

# Status acts on every planned target immediately and never reads a confirmation key.
: >"$LOG"
write_plan status explicit NVO-20130 NVO-20224
run_dialog </dev/null
[[ ! -e $DIALOG_PLAN ]] || fail 'status dialog did not delete its plan'
assert_equals 2 "$(rg -c '^labctl status ' "$LOG")" 'status did not run once per target'
assert_equals 2 "$(rg -F -c "sg incus-admin -c $TEST_ROOT/home/.local/bin/labctl status" "$LOG")" 'status did not explicitly invoke the active labctl executable'
if rg -q '^labctl (start|stop|restart) ' "$LOG"; then
	fail 'status ran a mutating lifecycle command'
fi

# Enter confirms start and invokes labctl once per target.
: >"$LOG"
write_plan start explicit NVO-20130 NVO-20224
printf '\n' | run_dialog
[[ ! -e $DIALOG_PLAN ]] || fail 'start dialog did not delete its plan'
assert_equals 2 "$(rg -c '^labctl start ' "$LOG")" 'start did not run once per target'

# An all-scope mutation visibly warns before presenting the Enter confirmation.
: >"$LOG"
DIALOG_OUTPUT="$TEST_ROOT/dialog-output"
write_plan start all NVO-20130
printf '\n' | run_dialog >"$DIALOG_OUTPUT"
[[ ! -e $DIALOG_PLAN ]] || fail 'all-scope dialog did not delete its plan'
warning_line=$(rg -n 'WARNING:.*all registered sandboxes' "$DIALOG_OUTPUT" | cut -d: -f1)
prompt_line=$(rg -n 'Press Enter to continue' "$DIALOG_OUTPUT" | cut -d: -f1)
[[ -n $warning_line && -n $prompt_line && $warning_line -lt $prompt_line ]] || fail 'all-scope warning was not visible before Enter confirmation'
assert_equals 1 "$(rg -c '^labctl start ' "$LOG")" 'all-scope start did not run after Enter confirmation'

# Escape cancels a mutation, invokes no lifecycle action, and still deletes the plan.
: >"$LOG"
write_plan stop explicit NVO-20130
printf '\e' | run_dialog
[[ ! -e $DIALOG_PLAN ]] || fail 'cancelled dialog did not delete its plan'
if rg -q '^labctl (start|stop|restart) ' "$LOG"; then
	fail 'escape invoked a lifecycle command'
fi

# Closed stdin with no usable controlling TTY cancels a mutation and deletes its trusted plan.
: >"$LOG"
write_plan stop explicit NVO-20130
run_dialog </dev/null
[[ ! -e $DIALOG_PLAN ]] || fail 'EOF-cancelled dialog did not delete its plan'
if rg -q '^labctl (start|stop|restart) ' "$LOG"; then
	fail 'EOF invoked a lifecycle command'
fi

# Restart continues independently: an earlier stop failure cannot skip a later ticket.
: >"$LOG"
write_plan restart explicit NVO-20130 NVO-20224
printf '\n' | TEST_FAIL_STOP_FOR=NVO-20130 run_dialog
[[ ! -e $DIALOG_PLAN ]] || fail 'restart dialog did not delete its plan'
assert_equals 2 "$(rg -c '^labctl stop ' "$LOG")" 'restart did not stop every target'
assert_equals 2 "$(rg -c '^labctl start ' "$LOG")" 'restart did not start every target'

printf '%s\n' 'PASS: nvo-sandbox-control'
