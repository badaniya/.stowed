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

force=false
for argument in "${args[@]:1}"; do
	[[ $argument == --force ]] || {
		echo "Usage: nvo-harness-worktree-sandbox-remove.sh <JIRA#> [--force]" >&2
		exit 1
	}
	force=true
done

spreader_dir="${HOME}/.config/herdr-spreader"
project_root="${HOME}/workspace/badaniya/${ticket}"
labctl="${HOME}/.local/bin/labctl"

[[ -x $labctl ]] || {
	echo "Error: labctl is unavailable at ${labctl}; stow the incus package first" >&2
	exit 1
}

printf -v destroy_command '%q %q %q %q' "$labctl" destroy "$ticket" --yes
printf '→ Destroying Incus sandbox %s…\n' "$ticket"
sg incus-admin -c "$destroy_command"

if [[ $force == true ]]; then
	if [[ -d $project_root ]]; then
		# Docker build artifacts can be root-owned inside the idmapped workspace.
		# Ownership repair is restricted to the explicitly force-removed ticket root.
		printf '→ Repairing ownership of generated artifacts in %s…\n' "$project_root"
		sudo chown -R "$(id -un):$(id -gn)" "$project_root"
	fi

	# A failed `git worktree remove` can deregister a worktree before failing to
	# delete root-owned build artifacts. Remove only those now-unregistered,
	# known harness repository directories and their matching ticket branches.
	for repo in GoDCApp PlatformCommonModels PlatformServices PlatformServicesCommon; do
		worktree_path="${project_root}/${repo}"
		bare_repo="${HOME}/workspace/badaniya/master/${repo}"
		registered=false
		if git -C "$bare_repo" worktree list --porcelain 2>/dev/null | rg -Fx -- "worktree ${worktree_path}" >/dev/null; then
			registered=true
		fi
		if [[ -d $worktree_path && $registered == false ]]; then
			printf '→ Removing orphaned worktree directory %s…\n' "$worktree_path"
			rm -rf --one-file-system -- "$worktree_path"
		fi
		if [[ $registered == false ]]; then
			branch="badaniya/${repo}/${ticket}"
			if git -C "$bare_repo" show-ref --verify --quiet "refs/heads/${branch}"; then
				printf '→ Deleting orphaned worktree branch %s…\n' "$branch"
				git -C "$bare_repo" branch -D "$branch"
			fi
		fi
	done
fi

if [[ -d $project_root ]]; then
	printf '→ Removing harness worktrees for %s…\n' "$ticket"
	bash "${spreader_dir}/nvo-harness-worktree-remove.sh" "${args[@]}"
else
	printf '→ Ticket root %s is already removed; skipping worktree removal.\n' "$project_root"
fi

if [[ $force == true && -f $project_root/.agents/.herdr-aggregate-context ]]; then
	# The harness creator builds .agents as an aggregate context tree. Its marker
	# proves it is generated action state rather than an arbitrary user directory.
	printf '→ Removing aggregate harness context %s/.agents…\n' "$project_root"
	rm -rf --one-file-system -- "$project_root/.agents"
fi
if [[ -d $project_root && -z $(ls -A "$project_root") ]]; then
	rmdir "$project_root"
	printf '→ Removed empty ticket root %s…\n' "$project_root"
fi
