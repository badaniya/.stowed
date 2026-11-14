#!/usr/bin/env bash
# nvo-harness-worktree-sandbox-remove — destroy a ticket's Incus sandbox, then
# force-remove the associated NVO harness worktrees by default. Pass
# --keep-worktrees to destroy only the sandbox and close its Herdr workspace.
# Explicit --force remains supported for compatibility.
#
# Usage:
#   nvo-harness-worktree-sandbox-remove.sh '<JIRA#> [--keep-worktrees]'
#   nvo-harness-worktree-sandbox-remove.sh NVO-20131 --keep-worktrees
set -euo pipefail

if [[ $# -lt 1 ]]; then
	echo "Usage: nvo-harness-worktree-sandbox-remove.sh <JIRA#> [--keep-worktrees]" >&2
	exit 1
fi

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

force=true
explicit_force=false
for argument in "${args[@]:1}"; do
	case $argument in
	--force) explicit_force=true ;;
	--keep-worktrees) force=false ;;
	*)
		echo "Usage: nvo-harness-worktree-sandbox-remove.sh <JIRA#> [--keep-worktrees]" >&2
		exit 1
		;;
	esac
done
if [[ $explicit_force == true && $force == false ]]; then
	echo 'Error: --force and --keep-worktrees cannot be combined' >&2
	exit 1
fi

spreader_dir="${HOME}/.config/herdr-spreader"
project_root="${HOME}/workspace/badaniya/${ticket}"
labctl="${HOME}/.local/bin/labctl"

[[ -x $labctl ]] || {
	echo "Error: labctl is unavailable at ${labctl}; stow the incus package first" >&2
	exit 1
}

# The legacy four-repository remover uses this fixed root/owner convention.
# Refuse custom EMULATOR roots rather than accidentally cleaning another ticket.
if [[ $ticket == EMULATOR-* && $force == true ]]; then
	if [[ ${NVO_WORKSPACE_OWNER:-badaniya} != badaniya || ${NVO_WORKSPACE_ROOT:-$HOME/workspace/badaniya} != "$HOME/workspace/badaniya" ]]; then
		printf 'Error: legacy sandbox removal supports only ~/workspace/badaniya; use --keep-worktrees and remove custom worktrees explicitly\n' >&2
		exit 1
	fi
	# Validate before sandbox destruction or ownership repair of ticket contents.
	# shellcheck source=/dev/null
	source "$(dirname "${BASH_SOURCE[0]}")/emulator-worktree.sh"
	emulator_worktree_paths_validate "$HOME/workspace/badaniya" badaniya "$ticket"
	if [[ -e $project_root/cloudemu ]]; then
		emulator_worktree_validate "$HOME/workspace/badaniya" badaniya "$ticket"
	fi
fi

printf -v destroy_command '%q %q %q %q' "$labctl" destroy "$ticket" --yes
printf '→ Destroying Incus sandbox %s…\n' "$ticket"
sg incus-admin -c "$destroy_command"

if [[ $force == false ]]; then
	printf '→ Keeping all worktrees, local branches and project context at %s.\n' "$project_root"
	# Close matching Herdr views last, just as the normal worktree remover does;
	# this action may itself be running inside one of those workspaces.
	workspace_ids=$(herdr workspace list | jq -r --arg ticket "$ticket" \
		'.result.workspaces[] | select(.label == $ticket or (.label | startswith($ticket + " "))) | .workspace_id')
	while IFS= read -r workspace_id; do
		[[ -n $workspace_id ]] || continue
		herdr workspace close "$workspace_id" >/dev/null
	done <<<"$workspace_ids"
	exit 0
fi

if [[ $force == true ]]; then
	if [[ -d $project_root ]]; then
		# Docker build artifacts can be root-owned inside the idmapped workspace.
		# Ownership repair is restricted to the ticket root being force-removed.
		printf '→ Repairing ownership of generated artifacts in %s…\n' "$project_root"
		sudo chown -R "$(id -un):$(id -gn)" "$project_root"
	fi

	# Remove cloudemu through Git, never through the generic orphan-directory
	# sweep. Unknown/unregistered directories fail validation and are retained.
	if [[ $ticket == EMULATOR-* ]]; then
		emulator_worktree_remove "$HOME/workspace/badaniya" badaniya "$ticket"
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
	bash "${spreader_dir}/nvo-harness-worktree-remove.sh" "$ticket" --force
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
