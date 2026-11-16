#!/usr/bin/env bash
# nvo-mono-worktree-sandbox-remove — destroy a ticket's Incus sandbox, then
# force-remove its xcloud-platform-services worktree (and, for EMULATOR tickets,
# the cloudemu worktree and aggregate context). --keep-worktrees destroys only
# the sandbox and closes the Herdr workspace.
#
# Usage: nvo-mono-worktree-sandbox-remove.sh '<JIRA#> [--keep-worktrees]'
set -euo pipefail

usage() {
	echo "Usage: nvo-mono-worktree-sandbox-remove.sh <JIRA#> [--keep-worktrees]" >&2
	exit 1
}

[[ $# -ge 1 ]] || usage
if [[ $# -ge 2 ]]; then
	args=("$@")
else
	read -r -a args <<<"$1"
fi

ticket=${args[0]:-}
[[ $ticket =~ ^[A-Z][A-Z0-9]+-[0-9]+$ ]] || {
	echo "Error: ticket must use a Jira key such as NVO-123 or CFD-123" >&2
	exit 1
}
keep=false
for argument in "${args[@]:1}"; do
	case $argument in
	--force) ;;
	--keep-worktrees) keep=true ;;
	*) usage ;;
	esac
done

owner=${NVO_WORKSPACE_OWNER:-${USER:?}}
workspace_root=${NVO_WORKSPACE_ROOT:-"${HOME}/workspace/${owner}"}
project_root="${workspace_root}/${ticket}"
bare_repo="${workspace_root}/master/xcloud-platform-services"
branch="${owner}/${ticket}"
labctl="${HOME}/.local/bin/labctl"

[[ -x $labctl ]] || {
	echo "Error: labctl is unavailable at ${labctl}; stow the incus package first" >&2
	exit 1
}

# Layout: the ticket root is itself the worktree, or (EMULATOR) a plain parent.
if [[ -f ${project_root}/.git ]]; then
	mono_dir=$project_root
else
	mono_dir="${project_root}/xcloud-platform-services"
fi
emulator=false
[[ $ticket == EMULATOR-* ]] && emulator=true

if [[ $emulator == true && $keep == false ]]; then
	# shellcheck source=/dev/null
	source "$(dirname "${BASH_SOURCE[0]}")/emulator-worktree.sh"
	emulator_worktree_paths_validate "$workspace_root" "$owner" "$ticket"
	if [[ -e $project_root/cloudemu ]]; then
		emulator_worktree_validate "$workspace_root" "$owner" "$ticket"
	fi
fi

printf -v destroy_command '%q %q %q %q' "$labctl" destroy "$ticket" --yes
printf '→ Destroying Incus sandbox %s…\n' "$ticket"
sg incus-admin -c "$destroy_command"

close_workspaces() {
	# Close matching Herdr views last: this may be running inside one of them.
	local ids id
	ids=$(herdr workspace list | jq -r --arg ticket "$ticket" \
		'.result.workspaces[] | select(.label == $ticket or (.label | startswith($ticket + " "))) | .workspace_id')
	while IFS= read -r id; do
		[[ -n $id ]] || continue
		herdr workspace close "$id" >/dev/null
	done <<<"$ids"
}

if [[ $keep == true ]]; then
	printf '→ Keeping worktrees, local branch and project context at %s.\n' "$project_root"
	close_workspaces
	exit 0
fi

if [[ -d $project_root ]]; then
	# Docker build artifacts can be root-owned inside the idmapped workspace.
	# Repair ownership only inside the ticket root being removed.
	printf '→ Repairing ownership of generated artifacts in %s…\n' "$project_root"
	sudo chown -R "$(id -un):$(id -gn)" "$project_root"
fi

if [[ $emulator == true ]]; then
	emulator_worktree_remove "$workspace_root" "$owner" "$ticket"
fi

registered=false
if git -C "$bare_repo" worktree list --porcelain 2>/dev/null | rg -Fxq -- "worktree ${mono_dir}"; then
	registered=true
fi
if [[ $registered == true ]]; then
	printf '→ Removing worktree %s…\n' "$mono_dir"
	git -C "$bare_repo" worktree remove --force -- "$mono_dir"
elif [[ -d $mono_dir ]]; then
	printf '→ Removing orphaned worktree directory %s…\n' "$mono_dir"
	rm -rf --one-file-system -- "$mono_dir"
	git -C "$bare_repo" worktree prune
fi
if git -C "$bare_repo" show-ref --verify --quiet "refs/heads/${branch}"; then
	printf '→ Deleting local branch %s…\n' "$branch"
	git -C "$bare_repo" branch -D -- "$branch"
fi

# EMULATOR parent: aggregate context is generated state, proven by its marker.
if [[ $emulator == true ]]; then
	for context_dir in .agents .claude; do
		if [[ -f ${project_root}/${context_dir}/.herdr-aggregate-context ]]; then
			printf '→ Removing aggregate context %s/%s…\n' "$project_root" "$context_dir"
			rm -rf --one-file-system -- "${project_root:?}/${context_dir}"
		fi
	done
fi
if [[ -d $project_root && -z $(ls -A "$project_root") ]]; then
	rmdir "$project_root"
	printf '→ Removed empty ticket root %s\n' "$project_root"
elif [[ -d $project_root ]]; then
	printf 'Note: %s left in place (not empty)\n' "$project_root"
fi

close_workspaces
