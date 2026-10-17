#!/usr/bin/env bash
# nvo-harness-worktree-sandbox-remove — destroy a ticket's Incus sandbox, then
# remove the associated NVO harness worktrees using their existing safeguards.
#
# Usage:
#   nvo-harness-worktree-sandbox-remove.sh '<JIRA#> [--force]'
#   nvo-harness-worktree-sandbox-remove.sh NVO-20131 --force
set -euo pipefail

if [[ $# -lt 1 ]]; then
	echo "Usage: nvo-harness-worktree-sandbox-remove.sh <JIRA#> [--force]" >&2
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

for argument in "${args[@]:1}"; do
	[[ $argument == --force ]] || {
		echo "Usage: nvo-harness-worktree-sandbox-remove.sh <JIRA#> [--force]" >&2
		exit 1
	}
done

spreader_dir="${HOME}/.config/herdr-spreader"
labctl="${HOME}/.local/bin/labctl"

[[ -x $labctl ]] || {
	echo "Error: labctl is unavailable at ${labctl}; stow the incus package first" >&2
	exit 1
}

printf -v destroy_command '%q %q %q %q' "$labctl" destroy "$ticket" --yes
printf '→ Destroying Incus sandbox %s…\n' "$ticket"
sg incus-admin -c "$destroy_command"

printf '→ Removing harness worktrees for %s…\n' "$ticket"
bash "${spreader_dir}/nvo-harness-worktree-remove.sh" "${args[@]}"
