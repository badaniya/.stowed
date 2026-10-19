#!/usr/bin/env bash
# nvo-sandbox-control — validate registered sandbox targets and open its dialog.
set -euo pipefail

usage() {
	printf 'Usage: nvo-sandbox-control.sh <status|start|stop|restart> <ticket[,ticket...]|all>\n' >&2
}

die() {
	printf 'Error: %s\n' "$*" >&2
	exit 1
}

[[ $# -eq 2 ]] || {
	usage
	exit 1
}

operation=$1
target_input=$2
case $operation in
status | start | stop | restart) ;;
*) die 'operation must be status, start, stop, or restart' ;;
esac

pane_id=${HERDR_PLUS_PANE_ID:-}
[[ $pane_id =~ ^w[A-Za-z0-9]+:p[A-Za-z0-9]+$ ]] || die 'HERDR_PLUS_PANE_ID is missing or invalid'

state_file="${XDG_STATE_HOME:-$HOME/.local/state}/labctl/sandboxes.json"
[[ -f $state_file ]] || die "sandbox registry is unavailable: $state_file"
jq -e '.schema_version == 1 and (.sandboxes | type == "object")' "$state_file" >/dev/null || die 'sandbox registry is invalid'

declare -a tickets=()
declare -A seen=()
if [[ $target_input == all ]]; then
	mapfile -t tickets < <(jq -er '.sandboxes | to_entries[] | select((.key | test("^[A-Z][A-Z0-9]+-[0-9]+$")) and .value.status != "destroyed") | .key' "$state_file") || die 'unable to resolve sandbox targets'
else
	IFS=',' read -r -a tickets <<<"$target_input"
	((${#tickets[@]} > 0)) || die 'at least one sandbox target is required'
	for ticket in "${tickets[@]}"; do
		[[ $ticket =~ ^[A-Z][A-Z0-9]+-[0-9]+$ ]] || die "invalid sandbox ticket: $ticket"
		[[ ! ${seen[$ticket]+x} ]] || die "duplicate sandbox ticket: $ticket"
		seen[$ticket]=1
		jq -e --arg ticket "$ticket" '.sandboxes[$ticket] != null and .sandboxes[$ticket].status != "destroyed"' "$state_file" >/dev/null || die "sandbox is not eligible: $ticket"
	done
fi

((${#tickets[@]} > 0)) || die 'no eligible sandbox targets were found'

plan_dir="${XDG_STATE_HOME:-$HOME/.local/state}/herdr-spreader"
mkdir -p "$plan_dir"
chmod 0700 "$plan_dir"
plan_file=$(mktemp "${plan_dir}/nvo-sandbox-control.XXXXXX")
chmod 0600 "$plan_file"
cleanup_plan=true
cleanup() {
	if [[ $cleanup_plan == true ]]; then
		rm -f -- "$plan_file"
	fi
}
trap cleanup EXIT

{
	printf 'operation=%s\n' "$operation"
	printf '%s\n' "${tickets[@]}"
} >"$plan_file"

dialog_script="$HOME/.config/herdr-spreader/nvo-sandbox-control-dialog.sh"
split_json=$(herdr pane split "$pane_id" --direction down --focus) || die 'unable to open sandbox control pane'
dialog_pane_id=$(jq -er '.result.pane.pane_id' <<<"$split_json") || die 'Herdr returned an invalid sandbox control pane'
[[ $dialog_pane_id =~ ^w[A-Za-z0-9]+:p[A-Za-z0-9]+$ ]] || die 'Herdr returned an unsafe sandbox control pane ID'
printf -v dialog_command '%q %q %q %q' bash "$dialog_script" --plan "$plan_file"
herdr pane run "$dialog_pane_id" "$dialog_command" || die 'unable to start sandbox control dialog'
cleanup_plan=false
