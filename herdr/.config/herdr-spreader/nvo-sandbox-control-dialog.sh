#!/usr/bin/env bash
# nvo-sandbox-control-dialog — confirm and execute a validated sandbox control plan.
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
((${#plan_lines[@]} >= 3)) || die 'plan file has no targets'

case ${plan_lines[0]} in
operation=status) operation=status ;;
operation=start) operation=start ;;
operation=stop) operation=stop ;;
operation=restart) operation=restart ;;
*) die 'plan operation is invalid' ;;
esac

case ${plan_lines[1]} in
scope=explicit) scope=explicit ;;
scope=all) scope=all ;;
*) die 'plan scope is invalid' ;;
esac

declare -A seen=()
declare -a tickets=()
for ticket in "${plan_lines[@]:2}"; do
	[[ $ticket =~ ^[A-Z][A-Z0-9]+-[0-9]+$ ]] || die "plan ticket is invalid: $ticket"
	[[ ! ${seen[$ticket]+x} ]] || die "plan ticket is duplicated: $ticket"
	seen[$ticket]=1
	tickets+=("$ticket")
done

state_file="${XDG_STATE_HOME:-$HOME/.local/state}/labctl/sandboxes.json"
validate_target() {
	local ticket=$1
	[[ -f $state_file ]] && jq -e --arg ticket "$ticket" \
		'.schema_version == 1 and (.sandboxes | type == "object") and .sandboxes[$ticket] != null and .sandboxes[$ticket].status != "destroyed"' \
		"$state_file" >/dev/null
}

printf 'Sandbox operation: %s\nTargets:\n' "$operation"
printf '  %s\n' "${tickets[@]}"

if [[ $operation != status ]]; then
	if [[ $scope == all ]]; then
		printf 'WARNING: This action applies to all registered sandboxes shown above.\n'
	fi
	printf 'Press Enter to continue or Escape to cancel.\n'
	key=''
	if ! IFS= read -r -s -n 1 key 2>/dev/null </dev/tty && ! IFS= read -r -s -n 1 key; then
		printf 'Cancelled. Confirmation input was unavailable. No sandbox lifecycle commands were run.\n'
		open_result_shell
	fi
	if [[ $key == $'\e' ]]; then
		printf 'Cancelled. No sandbox lifecycle commands were run.\n'
		open_result_shell
	fi
	if [[ -n $key ]]; then
		printf 'Cancelled. Use Enter to confirm.\n'
		open_result_shell
	fi
fi

failures=0
run_action() {
	local action=$1 ticket=$2
	if ! validate_target "$ticket"; then
		printf '%s %s: FAILED (sandbox is no longer eligible)\n' "$action" "$ticket"
		failures=$((failures + 1))
		return
	fi
	if sg incus-admin -c "labctl $action $ticket"; then
		printf '%s %s: succeeded\n' "$action" "$ticket"
	else
		printf '%s %s: FAILED\n' "$action" "$ticket"
		failures=$((failures + 1))
	fi
}

for ticket in "${tickets[@]}"; do
	case $operation in
	status | start | stop) run_action "$operation" "$ticket" ;;
	restart)
		run_action stop "$ticket"
		run_action start "$ticket"
		;;
	esac
done

if ((failures == 0)); then
	printf 'Summary: all %s target(s) completed successfully.\n' "${#tickets[@]}"
else
	printf 'Summary: %s action(s) failed; remaining targets were still attempted.\n' "$failures"
fi

open_result_shell
