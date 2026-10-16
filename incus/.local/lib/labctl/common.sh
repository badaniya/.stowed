#!/usr/bin/env bash
# Shared helpers for labctl.
set -euo pipefail

labctl_die() {
	printf 'labctl: %s\n' "$*" >&2
	return 1
}

labctl_run() {
	printf '+ '
	printf '%q ' "$@"
	printf '\n'
	if [[ ${LABCTL_DRY_RUN:-false} == true ]]; then
		return 0
	fi
	"$@"
}

labctl_normalize_ticket() {
	local raw=$1 normalized
	normalized=${raw,,}
	# Ticket identifiers permit # within a segment for the existing workspace layout.
	if [[ ! $normalized =~ ^[a-z0-9#]+(-[a-z0-9#]+)*$ ]]; then
		labctl_die "invalid ticket identifier: $raw"
		return 1
	fi
	printf '%s\n' "$normalized"
}
