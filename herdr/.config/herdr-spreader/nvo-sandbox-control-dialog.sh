#!/usr/bin/env bash
# nvo-sandbox-control-dialog — choose and execute a validated sandbox control plan.
set -uo pipefail

usage() {
	printf 'Usage: nvo-sandbox-control-dialog.sh --plan <owner-only-plan-path>\n' >&2
}

die() {
	printf 'Error: %s\n' "$*" >&2
	exit 1
}

[[ $# -eq 2 && $1 == --plan ]] || {
	usage
	exit 1
}

plan_file=$2
plan_dir="${XDG_STATE_HOME:-$HOME/.local/state}/herdr-spreader"
plan_name=${plan_file##*/}
[[ ${plan_file%/*} == "$plan_dir" && $plan_name == nvo-sandbox-control.* ]] || die 'plan path is invalid'
[[ -f $plan_file && ! -L $plan_file && -O $plan_file ]] || die 'plan file is unavailable or unsafe'
[[ $(stat -c '%a' "$plan_file") == 600 ]] || die 'plan file is not owner-only'

cleanup() {
	rm -f -- "$plan_file"
}
open_result_shell() {
	cleanup
	trap - EXIT
	exec bash -i
}
trap cleanup EXIT

mapfile -t plan_lines <"$plan_file" || die 'unable to read plan file'
((${#plan_lines[@]} >= 2)) || die 'plan file has no targets'

case ${plan_lines[0]} in
scope=explicit) scope=explicit ;;
scope=all) scope=all ;;
*) die 'plan scope is invalid' ;;
esac

declare -A seen=()
declare -a tickets=()
for ticket in "${plan_lines[@]:1}"; do
	[[ $ticket =~ ^[A-Z][A-Z0-9]+-[0-9]+$ ]] || die "plan ticket is invalid: $ticket"
	[[ ! ${seen[$ticket]+x} ]] || die "plan ticket is duplicated: $ticket"
	seen[$ticket]=1
	tickets+=("$ticket")
done

state_file="${XDG_STATE_HOME:-$HOME/.local/state}/labctl/sandboxes.json"
validate_target() {
	local ticket=$1 normalized_ticket
	normalized_ticket=${ticket,,}
	[[ -f $state_file ]] && jq -e --arg ticket "$normalized_ticket" \
		'.schema_version == 1 and (.sandboxes | type == "object") and .sandboxes[$ticket] != null and .sandboxes[$ticket].status != "destroyed"' \
		"$state_file" >/dev/null
}

read_response() {
	local prompt=$1
	printf '%s' "$prompt"
	if [[ -t 0 ]] && IFS= read -r response </dev/tty; then
		return 0
	fi
	IFS= read -r response
}

confirm_enter() {
	local message=$1
	printf '%s\n' "$message"
	if ! read_response 'Press Enter to continue or Escape to cancel. '; then
		printf 'Cancelled. Confirmation input was unavailable. No sandbox lifecycle commands were run.\n'
		return 1
	fi
	if [[ $response == $'\e' ]]; then
		printf 'Cancelled. No sandbox lifecycle commands were run.\n'
		return 1
	fi
	if [[ -n $response ]]; then
		printf 'Cancelled. Use Enter to confirm.\n'
		return 1
	fi
	return 0
}

failures=0
run_action() {
	local action=$1 ticket=$2 lifecycle_command
	if ! validate_target "$ticket"; then
		printf '%s %s: FAILED (sandbox is no longer eligible)\n' "$action" "$ticket"
		failures=$((failures + 1))
		return 1
	fi
	printf -v lifecycle_command '%q %q %q' "$HOME/.local/bin/labctl" "$action" "$ticket"
	if sg incus-admin -c "$lifecycle_command"; then
		printf '%s %s: succeeded\n' "$action" "$ticket"
		return 0
	fi
	printf '%s %s: FAILED\n' "$action" "$ticket"
	failures=$((failures + 1))
	return 1
}

project_for_snapshots() {
	local project
	project=$("$HOME/.local/bin/labctl" instance-project) || {
		printf 'Unable to determine the Incus project for snapshots.\n' >&2
		return 1
	}
	[[ $project =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]] || {
		printf 'The configured Incus project is invalid.\n' >&2
		return 1
	}
	printf '%s\n' "$project"
}

run_snapshot_command() {
	local project=$1 action=$2 ticket=$3 snapshot=${4:-} snapshot_command
	case $action in
	create | restore)
		[[ $snapshot =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || return 1
		printf -v snapshot_command '%q %q %q %q %q %q %q' incus --project "$project" snapshot "$action" "$ticket" "$snapshot"
		;;
	*) return 1 ;;
	esac
	sg incus-admin -c "$snapshot_command"
}

require_single_snapshot_target() {
	if ((${#tickets[@]} != 1)); then
		printf 'Snapshot operations require exactly one sandbox target. No sandbox was changed.\n'
		return 1
	fi
	return 0
}

create_snapshot() {
	local ticket=${tickets[0]} snapshot project
	if ! read_response 'Snapshot name: '; then
		printf 'Cancelled. No snapshot was created.\n'
		return
	fi
	if [[ ! $response =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
		printf 'Invalid snapshot name. Use letters, digits, periods, underscores, and hyphens; the first character must be alphanumeric.\n'
		return
	fi
	snapshot=$response
	if ! confirm_enter "Create snapshot '$snapshot' for $ticket?"; then
		return
	fi
	if ! validate_target "$ticket"; then
		printf 'snapshot-create %s: FAILED (sandbox is no longer eligible)\n' "$ticket"
		return
	fi
	project=$(project_for_snapshots) || return
	if run_snapshot_command "$project" create "$ticket" "$snapshot"; then
		printf 'snapshot-create %s/%s: succeeded\n' "$ticket" "$snapshot"
	else
		printf 'snapshot-create %s/%s: FAILED\n' "$ticket" "$snapshot"
	fi
}

restore_snapshot() {
	local ticket=${tickets[0]} project snapshot_json selected_snapshot selected_timestamp selection
	local -a snapshot_rows=()
	if ! validate_target "$ticket"; then
		printf 'snapshot-restore %s: FAILED (sandbox is no longer eligible)\n' "$ticket"
		return
	fi
	project=$(project_for_snapshots) || return
	local snapshot_list_command
	printf -v snapshot_list_command '%q %q %q %q %q %q %q %q' incus --project "$project" snapshot list "$ticket" --format json
	if ! snapshot_json=$(sg incus-admin -c "$snapshot_list_command"); then
		printf 'Unable to list snapshots for %s. No sandbox was changed.\n' "$ticket"
		return
	fi
	if ! jq -e \
		--arg name_pattern '^[A-Za-z0-9][A-Za-z0-9._-]*$' \
		--arg timestamp_pattern '^[0-9][0-9T:.+Z-]*$' \
		'type == "array" and all(.[]; type == "object" and (.name | type == "string" and test($name_pattern)) and (.created_at | type == "string" and test($timestamp_pattern)))' \
		<<<"$snapshot_json" >/dev/null; then
		printf 'Snapshot list was malformed. No sandbox was changed.\n' >&2
		return
	fi
	mapfile -t snapshot_rows < <(jq -r '.[] | [.name, .created_at] | @tsv' <<<"$snapshot_json")
	if ((${#snapshot_rows[@]} == 0)); then
		printf 'No snapshots are available for %s. No sandbox was changed.\n' "$ticket"
		return
	fi

	printf 'Snapshots for %s:\n' "$ticket"
	local index=1 row snapshot_name snapshot_timestamp
	for row in "${snapshot_rows[@]}"; do
		IFS=$'\t' read -r snapshot_name snapshot_timestamp <<<"$row"
		printf '  %d) %s — %s\n' "$index" "$snapshot_name" "$snapshot_timestamp"
		index=$((index + 1))
	done
	if ! read_response 'Select a snapshot number: '; then
		printf 'Cancelled. No snapshot was restored.\n'
		return
	fi
	selection=$response
	if [[ ! $selection =~ ^[1-9][0-9]*$ ]] || ((selection > ${#snapshot_rows[@]})); then
		printf 'Cancelled. Select a listed snapshot number.\n'
		return
	fi
	IFS=$'\t' read -r selected_snapshot selected_timestamp <<<"${snapshot_rows[selection - 1]}"
	if ! confirm_enter "WARNING: Restore snapshot '$selected_snapshot' from $selected_timestamp to $ticket? The sandbox will be stopped and restarted."; then
		return
	fi
	if ! run_action stop "$ticket"; then
		printf 'Snapshot restore was not attempted because stopping %s failed.\n' "$ticket"
		return
	fi
	if ! run_snapshot_command "$project" restore "$ticket" "$selected_snapshot"; then
		printf 'snapshot-restore %s/%s: FAILED; %s was not restarted.\n' "$ticket" "$selected_snapshot" "$ticket"
		return
	fi
	printf 'snapshot-restore %s/%s: succeeded\n' "$ticket" "$selected_snapshot"
	if ! run_action start "$ticket"; then
		printf 'Snapshot restore completed, but restarting %s failed.\n' "$ticket"
	fi
}

printf 'Sandbox targets:\n'
printf '  %s\n' "${tickets[@]}"
printf '%s\n' 'Choose an operation:'
printf '%s\n' '  1) Status — inspect current sandbox state'
printf '%s\n' '  2) Start — start the selected sandbox target(s)'
printf '%s\n' '  3) Stop — stop the selected sandbox target(s)'
printf '%s\n' '  4) Restart — stop then start the selected sandbox target(s)'
printf '%s\n' '  5) Create snapshot — save one sandbox with a typed name'
printf '%s\n' '  6) Restore snapshot — restore one saved snapshot and restart it'
printf '%s\n' '  7) Cancel — make no changes'

if ! read_response 'Selection: '; then
	printf 'Cancelled. Menu input was unavailable. No sandbox lifecycle commands were run.\n'
	open_result_shell
fi

case $response in
1) operation=status ;;
2) operation=start ;;
3) operation=stop ;;
4) operation=restart ;;
5) operation=snapshot-create ;;
6) operation=snapshot-restore ;;
7 | $'\e')
	printf 'Cancelled. No sandbox lifecycle commands were run.\n'
	open_result_shell
	;;
*)
	printf 'Cancelled. Select a numbered operation. No sandbox lifecycle commands were run.\n'
	open_result_shell
	;;
esac

case $operation in
status)
	for ticket in "${tickets[@]}"; do
		run_action status "$ticket"
	done
	;;
start | stop | restart)
	if [[ $scope == all ]]; then
		printf 'WARNING: This action applies to all registered sandboxes shown above.\n'
	fi
	if confirm_enter "Sandbox operation: $operation"; then
		for ticket in "${tickets[@]}"; do
			case $operation in
			start | stop) run_action "$operation" "$ticket" ;;
			restart)
				run_action stop "$ticket"
				run_action start "$ticket"
				;;
			esac
		done
	fi
	;;
snapshot-create)
	if require_single_snapshot_target; then
		create_snapshot
	fi
	;;
snapshot-restore)
	if require_single_snapshot_target; then
		restore_snapshot
	fi
	;;
esac

if [[ $operation == status || $operation == start || $operation == stop || $operation == restart ]]; then
	if ((failures == 0)); then
		printf 'Summary: all selected lifecycle actions completed successfully.\n'
	else
		printf 'Summary: %s lifecycle action(s) failed; remaining lifecycle targets were still attempted.\n' "$failures"
	fi
fi

open_result_shell
