#!/usr/bin/env bash
# Forward review-launch failures to the invoking Herdr Plus pane.
set -euo pipefail

log=$(mktemp)
trap 'rm -f -- "$log"' EXIT
error_file=${NVO_REVIEW_ERROR_FILE:-/tmp/nvo-review-last-error}

if bash "${HOME}/.config/herdr-spreader/nvo-review.sh" "$@" >"$log" 2>&1; then
	exit 0
fi

cp -- "$log" "$error_file"
if [[ -n ${HERDR_PLUS_PANE_ID:-} ]]; then
	if herdr pane run "$HERDR_PLUS_PANE_ID" "cat $(printf '%q' "$error_file")"; then
		exit 1
	fi
fi
cat "$error_file" >&2
exit 1
