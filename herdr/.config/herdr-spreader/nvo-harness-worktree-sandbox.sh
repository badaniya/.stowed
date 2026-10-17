#!/usr/bin/env bash
# nvo-harness-worktree-sandbox — create/reuse an NVO harness worktree, open its
# Herdr workspace, then create and bootstrap its ticket-scoped Incus sandbox.
#
# Usage:
#   nvo-harness-worktree-sandbox.sh '<JIRA#> <upstream-version> [--restore-harness]'
#   nvo-harness-worktree-sandbox.sh NVO-20131 25.16.0 --restore-harness
set -euo pipefail

if [[ $# -lt 1 ]]; then
	echo "Usage: nvo-harness-worktree-sandbox.sh <JIRA#> <upstream-version> [--restore-harness]" >&2
	exit 1
fi

if [[ $# -ge 2 ]]; then
	args=("$@")
else
	read -r -a args <<<"$1"
fi

ticket=${args[0]:-}
[[ $ticket =~ ^NVO-[0-9]+$ ]] || {
	echo "Error: ticket must use the NVO-<number> format" >&2
	exit 1
}

spreader_dir="${HOME}/.config/herdr-spreader"
labctl="${HOME}/.local/bin/labctl"

[[ -x $labctl ]] || {
	echo "Error: labctl is unavailable at ${labctl}; stow the incus package first" >&2
	exit 1
}

bash "${spreader_dir}/nvo-harness-worktree.sh" "${args[@]}"

run_labctl() {
	local command
	printf -v command '%q ' "$labctl" "$@" "$ticket"
	sg incus-admin -c "$command"
}

printf '→ Syncing the host Git credential into sandbox %s…\n' "$ticket"
run_labctl credential sync
printf '→ Creating and bootstrapping sandbox %s…\n' "$ticket"
run_labctl bootstrap
