#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="${REPO_ROOT}/herdr/.config/herdr-spreader/nvo-sandbox-control.sh"
DIALOG_SCRIPT="${REPO_ROOT}/herdr/.config/herdr-spreader/nvo-sandbox-control-dialog.sh"
QUICK_ACTION="${REPO_ROOT}/herdr/.config/herdr/plugins/config/cloudmanic.herdr-plus/quick-actions/sandbox-control.toml"

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
if [[ $1 == instance-project ]]; then
	printf '%s\n' "${TEST_PROJECT:-test-project}"
	exit 0
fi
if [[ ${TEST_FAIL_STOP_FOR:-} == "$2" && $1 == stop ]]; then
	exit 1
fi
EOF_LABCTL

cat >"$TEST_ROOT/bin/incus" <<'EOF_INCUS'
#!/usr/bin/env bash
set -euo pipefail
printf 'incus %s\n' "$*" >>"${TEST_LOG:?}"
[[ $1 == --project && $2 == "${TEST_PROJECT:-test-project}" && $3 == snapshot ]] || exit 2
action=$4
case $action in
list)
	[[ $# -eq 7 && $6 == --format && $7 == json ]] || exit 2
	printf '%s\n' "${TEST_SNAPSHOT_JSON:-[]}"
	;;
create | restore)
	[[ $# -eq 6 ]] || exit 2
	;;
*) exit 2 ;;
esac
[[ ${TEST_FAIL_INCUS_ACTION:-} != "$action" ]]
EOF_INCUS
chmod +x "$TEST_ROOT/bin/herdr" "$TEST_ROOT/bin/sg" "$TEST_ROOT/bin/incus" "$TEST_ROOT/home/.local/bin/labctl"
run_controller() {
	HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$TEST_ROOT/home/.local/bin:$PATH" XDG_STATE_HOME="$TEST_ROOT/state" TEST_LOG="$LOG" TEST_PLAN_PATH="$PLAN_PATH_FILE" HERDR_PLUS_PANE_ID="${TEST_PANE_ID-w1:p1}" "$SCRIPT" "$@"
}

write_plan() {
	local scope=$1
	shift
	DIALOG_PLAN="$TEST_ROOT/state/herdr-spreader/nvo-sandbox-control.dialog-test"
	mkdir -p "${DIALOG_PLAN%/*}"
	chmod 0700 "${DIALOG_PLAN%/*}"
	{
		printf 'scope=%s\n' "$scope"
		printf '%s\n' "$@"
	} >"$DIALOG_PLAN"
	chmod 0600 "$DIALOG_PLAN"
}
run_dialog() {
	HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$PATH" XDG_STATE_HOME="$TEST_ROOT/state" TEST_LOG="$LOG" "$DIALOG_SCRIPT" --plan "$DIALOG_PLAN"
}

# NVO-20130,NVO-20224 creates one ordered plan and one focused sibling pane.
: >"$LOG"
run_controller NVO-20130,NVO-20224
PLAN_PATH=$(<"$PLAN_PATH_FILE")
[[ -f $PLAN_PATH ]] || fail 'controller did not create the plan file'
[[ $(stat -c '%a' "$PLAN_PATH") == 600 ]] || fail 'plan file is not owner-only'
assert_file_equals $'scope=explicit\nNVO-20130\nNVO-20224' "$PLAN_PATH"
assert_equals 1 "$(rg -c '^herdr pane split ' "$LOG")" 'expected one focused pane split'
assert_equals 1 "$(rg -c '^herdr pane run ' "$LOG")" 'expected one dialog command'

# all omits destroyed records while retaining registry ticket order.
: >"$LOG"
run_controller all
PLAN_PATH=$(<"$PLAN_PATH_FILE")
assert_file_equals $'scope=all\nNVO-20130\nNVO-20224' "$PLAN_PATH"
assert_equals 1 "$(rg -c '^herdr pane split ' "$LOG")" 'expected one focused pane split for all'

# Invalid or duplicate targets fail before any Herdr pane mutation.
: >"$LOG"
if run_controller NVO-20130,NVO-20130,not-a-ticket; then
	fail 'invalid duplicate target list unexpectedly succeeded'
fi
[[ ! -s $LOG ]] || fail 'invalid target list mutated Herdr or invoked a command'

# Empty CSV fields must fail before any Herdr pane split or dialog command.
: >"$LOG"
if run_controller 'NVO-20130,'; then
	fail 'trailing empty CSV field unexpectedly succeeded'
fi
[[ ! -s $LOG ]] || fail 'trailing empty CSV field split or ran a Herdr pane'

: >"$LOG"
if run_controller ',NVO-20130'; then
	fail 'leading empty CSV field unexpectedly succeeded'
fi
[[ ! -s $LOG ]] || fail 'leading empty CSV field split or ran a Herdr pane'

: >"$LOG"
if run_controller 'NVO-20130,,NVO-20224'; then
	fail 'adjacent empty CSV fields unexpectedly succeeded'
fi
[[ ! -s $LOG ]] || fail 'adjacent empty CSV fields split or ran a Herdr pane'

# The removed operation argument is rejected before any Herdr pane mutation.
: >"$LOG"
if run_controller status NVO-20130; then
	fail 'obsolete operation-and-target interface unexpectedly succeeded'
fi
[[ ! -s $LOG ]] || fail 'obsolete operation-and-target interface split or ran a Herdr pane'

# Shell metacharacters remain one literal, invalid target and cannot run another command.
: >"$LOG"
injection_marker="$TEST_ROOT/injection-marker"
injection_target="NVO-20130'; touch $injection_marker; #"
if run_controller "$injection_target"; then
	fail 'shell-metacharacter target unexpectedly succeeded'
fi
[[ ! -e $injection_marker ]] || fail 'shell-metacharacter target executed an injected command'
[[ ! -s $LOG ]] || fail 'shell-metacharacter target split or ran a Herdr pane'

# The invoking pane must be available and valid before a focused sibling can open.
: >"$LOG"
if TEST_PANE_ID='' run_controller NVO-20130; then
	fail 'missing HERDR_PLUS_PANE_ID unexpectedly succeeded'
fi
[[ ! -s $LOG ]] || fail 'missing pane ID mutated Herdr or invoked a command'

# An option-shaped split response is rejected, but rollback treats it as a close target rather than a close option.
: >"$LOG"
plans_before=$(rg --files -g 'nvo-sandbox-control.*' "$TEST_ROOT/state/herdr-spreader" | wc -l)
unsafe_pane_id='--all'
printf -v unsafe_split_response '{"result":{"pane":{"pane_id":"%s"}}}' "$unsafe_pane_id"
if TEST_SPLIT_RESPONSE="$unsafe_split_response" TEST_EXPECT_CLOSED_PANE="$unsafe_pane_id" run_controller NVO-20130; then
	fail 'controller unexpectedly accepted an unsafe sandbox control pane ID'
fi
assert_equals 1 "$(rg -c '^herdr pane split ' "$LOG")" 'expected one focused pane split before response validation failure'
assert_equals 1 "$(rg -F -c "herdr pane close -- $unsafe_pane_id" "$LOG")" 'controller did not guard the option-shaped rollback pane ID'
assert_equals "$plans_before" "$(rg --files -g 'nvo-sandbox-control.*' "$TEST_ROOT/state/herdr-spreader" | wc -l)" 'controller did not remove the response-validation-failed plan file'

# If queuing the dialog fails after a focused split, the controller closes only that new pane and removes its plan.
: >"$LOG"
if TEST_FAIL_PANE_RUN=true run_controller NVO-20130; then
	fail 'controller unexpectedly succeeded when the dialog could not start'
fi
assert_equals 1 "$(rg -c '^herdr pane split ' "$LOG")" 'expected one focused pane split before pane-run failure'
assert_equals 1 "$(rg -c '^herdr pane run ' "$LOG")" 'expected one pane-run attempt'
assert_equals 1 "$(rg -c '^herdr pane close -- w1:p2$' "$LOG")" 'controller did not roll back the newly created pane'
PLAN_PATH=$(<"$PLAN_PATH_FILE")
[[ ! -e $PLAN_PATH ]] || fail 'controller did not remove the rolled-back plan file'

# Menu selection renders operational hints and status acts on every planned target without confirmation.
: >"$LOG"
DIALOG_OUTPUT="$TEST_ROOT/dialog-output"
write_plan explicit NVO-20130 NVO-20224
printf '1\n' | run_dialog >"$DIALOG_OUTPUT"
[[ ! -e $DIALOG_PLAN ]] || fail 'status dialog did not delete its plan'
rg -q '1\).*Status.*inspect' "$DIALOG_OUTPUT" || fail 'menu did not render the status hint'
rg -q '5\).*snapshot' "$DIALOG_OUTPUT" || fail 'menu did not render the snapshot-create hint'
rg -q '6\).*snapshot' "$DIALOG_OUTPUT" || fail 'menu did not render the snapshot-restore hint'
assert_equals 2 "$(rg -c '^labctl status ' "$LOG")" 'status did not run once per target'
assert_equals 2 "$(rg -F -c "sg incus-admin -c $TEST_ROOT/home/.local/bin/labctl status" "$LOG")" 'status did not explicitly invoke the active labctl executable'
if rg -q '^labctl (start|stop) |^incus .*snapshot (create|restore) ' "$LOG"; then
	fail 'status ran a mutating command'
fi

# Start uses the menu and still requires an Enter confirmation before every selected target.
: >"$LOG"
write_plan explicit NVO-20130 NVO-20224
printf '2\n\n' | run_dialog
[[ ! -e $DIALOG_PLAN ]] || fail 'start dialog did not delete its plan'
assert_equals 2 "$(rg -c '^labctl start ' "$LOG")" 'start did not run once per target'

# An all-scope lifecycle mutation visibly warns before its Enter confirmation.
: >"$LOG"
write_plan all NVO-20130
printf '2\n\n' | run_dialog >"$DIALOG_OUTPUT"
[[ ! -e $DIALOG_PLAN ]] || fail 'all-scope dialog did not delete its plan'
warning_line=$(rg -n 'WARNING:.*all registered sandboxes' "$DIALOG_OUTPUT" | cut -d: -f1)
prompt_line=$(rg -n 'Press Enter to continue' "$DIALOG_OUTPUT" | cut -d: -f1)
[[ -n $warning_line && -n $prompt_line && $warning_line -lt $prompt_line ]] || fail 'all-scope warning was not visible before Enter confirmation'
assert_equals 1 "$(rg -c '^labctl start ' "$LOG")" 'all-scope start did not run after Enter confirmation'

# Menu cancellation performs no lifecycle or snapshot mutation and removes the trusted plan.
: >"$LOG"
write_plan explicit NVO-20130
printf '7\n' | run_dialog
[[ ! -e $DIALOG_PLAN ]] || fail 'cancelled dialog did not delete its plan'
if rg -q '^labctl (start|stop) |^incus .*snapshot (create|restore) ' "$LOG"; then
	fail 'menu cancel invoked a mutating command'
fi

# EOF before mutation confirmation is cancellation, rather than permission to proceed.
: >"$LOG"
write_plan explicit NVO-20130
printf '3\n' | run_dialog
[[ ! -e $DIALOG_PLAN ]] || fail 'EOF-cancelled dialog did not delete its plan'
if rg -q '^labctl (start|stop) |^incus .*snapshot (create|restore) ' "$LOG"; then
	fail 'EOF confirmation invoked a mutating command'
fi

# Restart continues independently: an earlier stop failure cannot skip a later ticket.
: >"$LOG"
write_plan explicit NVO-20130 NVO-20224
printf '4\n\n' | TEST_FAIL_STOP_FOR=NVO-20130 run_dialog
[[ ! -e $DIALOG_PLAN ]] || fail 'restart dialog did not delete its plan'
assert_equals 2 "$(rg -c '^labctl stop ' "$LOG")" 'restart did not stop every target'
assert_equals 2 "$(rg -c '^labctl start ' "$LOG")" 'restart did not start every target'

# Snapshot creation accepts a conservative Incus-safe name after explicit confirmation.
: >"$LOG"
write_plan explicit NVO-20130
printf '5\nrelease_2026.10-rc1\n\n' | run_dialog
[[ ! -e $DIALOG_PLAN ]] || fail 'snapshot-create dialog did not delete its plan'
assert_equals 1 "$(rg -c '^incus --project test-project snapshot create NVO-20130 release_2026.10-rc1$' "$LOG")" 'snapshot create did not use the selected safe name'
if rg -q '^labctl (start|stop) ' "$LOG"; then
	fail 'snapshot create changed lifecycle state'
fi

# Snapshot creation rejects unsafe names before constructing an Incus command.
: >"$LOG"
write_plan explicit NVO-20130
printf '5\nbad name; rm -rf /\n' | run_dialog
[[ ! -e $DIALOG_PLAN ]] || fail 'invalid snapshot-name dialog did not delete its plan'
if rg -q '^incus |^labctl (start|stop) ' "$LOG"; then
	fail 'invalid snapshot name ran a state-changing command'
fi

# Snapshot operations reject multi-target plans before prompting or changing a sandbox.
: >"$LOG"
write_plan explicit NVO-20130 NVO-20224
printf '5\n' | run_dialog >"$DIALOG_OUTPUT"
rg -q 'exactly one sandbox target' "$DIALOG_OUTPUT" || fail 'multi-target snapshot request did not explain its restriction'
if rg -q '^incus |^labctl (start|stop) ' "$LOG"; then
	fail 'multi-target snapshot request changed a sandbox'
fi

# Snapshot creation never treats an all-scope plan with one eligible target as a one-target request.
: >"$LOG"
write_plan all NVO-20130
printf '5\ntrue\n\n' | run_dialog >"$DIALOG_OUTPUT"
rg -q 'exactly one sandbox target' "$DIALOG_OUTPUT" || fail 'all-scope snapshot-create did not explain its restriction'
[[ ! -s $LOG ]] || fail 'all-scope snapshot-create invoked a sandbox command'

# Snapshot restore likewise rejects an all-scope plan before looking up its project or listing snapshots.
: >"$LOG"
write_plan all NVO-20130
printf '6\n' | run_dialog >"$DIALOG_OUTPUT"
rg -q 'exactly one sandbox target' "$DIALOG_OUTPUT" || fail 'all-scope snapshot-restore did not explain its restriction'
[[ ! -s $LOG ]] || fail 'all-scope snapshot-restore invoked a sandbox command'

# Restore renders Incus JSON names and timestamps, then stops, restores, and starts in order.
: >"$LOG"
TEST_SNAPSHOT_JSON='[{"name":"before-upgrade","created_at":"2026-10-22T12:30:00Z"},{"name":"after-upgrade","created_at":"2026-10-23T12:30:00Z"}]'
export TEST_SNAPSHOT_JSON
write_plan explicit NVO-20130
printf '6\n2\n\n' | run_dialog >"$DIALOG_OUTPUT"
unset TEST_SNAPSHOT_JSON
[[ ! -e $DIALOG_PLAN ]] || fail 'snapshot-restore dialog did not delete its plan'
rg -q 'before-upgrade.*2026-10-22T12:30:00Z' "$DIALOG_OUTPUT" || fail 'restore menu did not show the first snapshot timestamp'
rg -q 'after-upgrade.*2026-10-23T12:30:00Z' "$DIALOG_OUTPUT" || fail 'restore menu did not show the second snapshot timestamp'
stop_line=$(rg -n '^labctl stop NVO-20130$' "$LOG" | cut -d: -f1)
restore_line=$(rg -n '^incus --project test-project snapshot restore NVO-20130 after-upgrade$' "$LOG" | cut -d: -f1)
start_line=$(rg -n '^labctl start NVO-20130$' "$LOG" | cut -d: -f1)
[[ -n $stop_line && -n $restore_line && -n $start_line && $stop_line -lt $restore_line && $restore_line -lt $start_line ]] || fail 'restore did not run stop, Incus restore, then start in order'

# An overflowing restore selection cancels rather than wrapping to a listed snapshot.
: >"$LOG"
TEST_SNAPSHOT_JSON='[{"name":"before-upgrade","created_at":"2026-10-22T12:30:00Z"},{"name":"after-upgrade","created_at":"2026-10-23T12:30:00Z"}]'
export TEST_SNAPSHOT_JSON
write_plan explicit NVO-20130
printf '6\n18446744073709551617\n\n' | run_dialog >"$DIALOG_OUTPUT"
unset TEST_SNAPSHOT_JSON
[[ ! -e $DIALOG_PLAN ]] || fail 'overflow-selection dialog did not delete its plan'
rg -Fq 'Cancelled. Select a listed snapshot number.' "$DIALOG_OUTPUT" || fail 'overflowing snapshot selection was not cancelled'
if rg -q '^labctl (start|stop) |^incus .*snapshot restore ' "$LOG"; then
	fail 'overflowing snapshot selection changed a sandbox'
fi

# An empty snapshot list clearly declines restore without lifecycle changes.
: >"$LOG"
TEST_SNAPSHOT_JSON='[]'
export TEST_SNAPSHOT_JSON
write_plan explicit NVO-20130
printf '6\n' | run_dialog >"$DIALOG_OUTPUT"
unset TEST_SNAPSHOT_JSON
rg -q 'No snapshots are available' "$DIALOG_OUTPUT" || fail 'empty snapshot list was not reported'
if rg -q '^incus .*snapshot restore |^labctl (start|stop) ' "$LOG"; then
	fail 'empty snapshot list changed a sandbox'
fi

# A malformed snapshot-list response likewise does not offer or run a restore.
: >"$LOG"
TEST_SNAPSHOT_JSON='not-json'
export TEST_SNAPSHOT_JSON
write_plan explicit NVO-20130
printf '6\n' | run_dialog >"$DIALOG_OUTPUT"
unset TEST_SNAPSHOT_JSON
if rg -q '^incus .*snapshot restore |^labctl (start|stop) ' "$LOG"; then
	fail 'malformed snapshot list changed a sandbox'
fi

# A failed stop blocks both Incus restore and start.
: >"$LOG"
TEST_SNAPSHOT_JSON='[{"name":"before-upgrade","created_at":"2026-10-22T12:30:00Z"}]'
export TEST_SNAPSHOT_JSON
write_plan explicit NVO-20130
printf '6\n1\n\n' | TEST_FAIL_STOP_FOR=NVO-20130 run_dialog
unset TEST_SNAPSHOT_JSON
if rg -q '^incus .*snapshot restore |^labctl start ' "$LOG"; then
	fail 'restore continued after labctl stop failed'
fi

# A failed Incus restore must never restart the sandbox.
: >"$LOG"
TEST_SNAPSHOT_JSON='[{"name":"before-upgrade","created_at":"2026-10-22T12:30:00Z"}]'
export TEST_SNAPSHOT_JSON
write_plan explicit NVO-20130
printf '6\n1\n\n' | TEST_FAIL_INCUS_ACTION=restore run_dialog
unset TEST_SNAPSHOT_JSON
assert_equals 1 "$(rg -c '^labctl stop NVO-20130$' "$LOG")" 'restore failure did not first stop the sandbox'
assert_equals 1 "$(rg -c '^incus --project test-project snapshot restore NVO-20130 before-upgrade$' "$LOG")" 'restore failure did not invoke Incus restore'
if rg -q '^labctl start ' "$LOG"; then
	fail 'restore failure restarted the sandbox'
fi
# The unified Herdr-plus action invokes the controller with only the target form value.
assert_file_equals $'name = "Sandbox: Control"\ntype = "form"\ncommand = "bash ~/.config/herdr-spreader/nvo-sandbox-control.sh"\n\n[form]\nprompt = "Sandbox target (ticket, comma-separated tickets, or all; choose lifecycle or snapshot actions next)"\nplaceholder = "NVO-20130,NVO-20224 or all"' "$QUICK_ACTION"

printf '%s\n' 'PASS: nvo-sandbox-control'
