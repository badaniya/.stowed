#!/usr/bin/env bash
# Surface failures from the NVO worktree sandbox action in its invoking pane.
set -euo pipefail

log=$(mktemp)
trap 'rm -f "$log"' EXIT

if bash "${HOME}/.config/herdr-spreader/nvo-harness-worktree-sandbox.sh" "$@" >"$log" 2>&1; then
	exit 0
fi

error_file=/tmp/nvo-harness-worktree-sandbox-last-error
cp "$log" "$error_file"
if [[ -n ${HERDR_PLUS_PANE_ID:-} ]]; then
	herdr pane run "$HERDR_PLUS_PANE_ID" "cat $(printf '%q' "$error_file")"
else
	cat "$error_file" >&2
fi
exit 1
