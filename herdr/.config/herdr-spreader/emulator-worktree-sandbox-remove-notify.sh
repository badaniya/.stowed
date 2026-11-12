#!/usr/bin/env bash
# Surface failures from the destructive EMULATOR action in the invoking pane.
set -euo pipefail

log=$(mktemp)
trap 'rm -f "$log"' EXIT
if bash "$(dirname "${BASH_SOURCE[0]}")/emulator-worktree-sandbox-remove.sh" "$@" >"$log" 2>&1; then
  exit 0
fi
error_file=/tmp/emulator-worktree-sandbox-remove-last-error
cp "$log" "$error_file"
if [[ -n ${HERDR_PLUS_PANE_ID:-} ]]; then
  herdr pane run "$HERDR_PLUS_PANE_ID" "cat $(printf '%q' "$error_file")"
else
  cat "$error_file" >&2
fi
exit 1
