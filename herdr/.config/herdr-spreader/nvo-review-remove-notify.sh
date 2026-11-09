#!/usr/bin/env bash
# Show destructive review cleanup failures instead of losing the picker output.
set -euo pipefail
log=$(mktemp)
trap 'rm -f "$log"' EXIT
if bash "$HOME/.config/herdr-spreader/nvo-review-remove.sh" "$@" >"$log" 2>&1; then
  exit 0
fi
error_file=$(mktemp /tmp/nvo-review-remove-error.XXXXXX)
cp -- "$log" "$error_file"
if [[ -n ${HERDR_PLUS_PANE_ID:-} ]]; then
  herdr pane run "$HERDR_PLUS_PANE_ID" "cat $(printf '%q' "$error_file")"
else
  cat "$error_file" >&2
fi
exit 1
