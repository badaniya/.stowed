#!/usr/bin/env bash
# Open the exposure dialog in a focused sibling pane, like Sandbox: Control.
set -euo pipefail
usage() {
  printf 'Usage: sandbox-exposure.sh <xiqfwdN> [create|update|delete|status|list|adopt] | list\n' >&2
  exit 1
}
[[ $# -ge 1 && $# -le 2 ]] || usage
input=$1
[[ $# -eq 1 ]] || input+=" $2"
dialog_args=()
if [[ $input == list ]]; then
  dialog_args=(list)
elif [[ $input =~ ^(xiqfwd(0|[1-9][0-9]*))([[:blank:]]+(create|update|delete|status|list|adopt))?$ ]]; then
  name=${BASH_REMATCH[1]}
  operation=${BASH_REMATCH[4]}
  [[ ${#name} -le 15 ]] || usage
  dialog_args=("$name")
  [[ -z $operation ]] || dialog_args+=("$operation")
else
  usage
fi
pane=${HERDR_PLUS_PANE_ID:-}
[[ $pane =~ ^w[A-Za-z0-9]+:p[A-Za-z0-9]+$ ]] || {
  printf 'Error: HERDR_PLUS_PANE_ID is missing or invalid\n' >&2
  exit 1
}
response=$(herdr pane split "$pane" --direction down --focus)
dialog_pane=$(jq -er '.result.pane.pane_id' <<<"$response")
[[ $dialog_pane =~ ^w[A-Za-z0-9]+:p[A-Za-z0-9]+$ ]] || {
  printf 'Error: unsafe pane ID returned by Herdr\n' >&2
  exit 1
}
printf -v command '%q ' bash "$HOME/.config/herdr-spreader/sandbox-exposure-dialog.sh" "${dialog_args[@]}"
command=${command% }
if ! herdr pane run "$dialog_pane" "$command"; then
  herdr pane close -- "$dialog_pane" >/dev/null 2>&1 || true
  printf 'Error: unable to start exposure dialog\n' >&2
  exit 1
fi
