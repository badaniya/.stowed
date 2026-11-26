#!/usr/bin/env bash
# monorepo-worktree-sandbox-remove — destroy a ticket's Incus sandbox, then
# force-remove its monorepo (MONOREPO_NAME) worktree (and, for multirepo tickets,
# the extra repo worktree and aggregate context). --keep-worktrees destroys only
# the sandbox and closes the Herdr workspace.
#
# Usage: monorepo-worktree-sandbox-remove.sh '<JIRA#> [--keep-worktrees]'
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/private-env.sh"
# Multirepo tickets are optional; without MULTIREPO_TICKET_PREFIX none match.
multirepo_prefix=$(private_env_name MULTIREPO_TICKET_PREFIX 2>/dev/null) || multirepo_prefix=

usage() {
	echo "Usage: monorepo-worktree-sandbox-remove.sh <JIRA#> [--keep-worktrees]" >&2
	exit 1
}

[[ $# -ge 1 ]] || usage
if [[ $# -ge 2 ]]; then
	args=("$@")
else
	read -r -a args <<<"$1"
fi

ticket=${args[0]:-}
# Preserve side-by-side multirepo aliases as distinct sandbox/worktree identities.
[[ $ticket =~ ^[A-Z][A-Z0-9]+-[0-9]+$ || (-n $multirepo_prefix && $ticket =~ ^${multirepo_prefix}-[0-9]+-MONO$) ]] || {
	echo "Error: ticket must use a Jira key such as ABC-123, or a <multirepo-prefix>-123-MONO alias" >&2
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

owner=${WS_OWNER:-${USER:?}}
workspace_root=${WS_ROOT:-"${HOME}/workspace/${owner}"}
project_root="${workspace_root}/${ticket}"
mono_repo=$(monorepo_name)
bare_repo="${workspace_root}/master/${mono_repo}"
branch="${owner}/${ticket}"
labctl="${HOME}/.local/bin/labctl"

[[ -x $labctl ]] || {
	echo "Error: labctl is unavailable at ${labctl}; stow the incus package first" >&2
	exit 1
}

# Layout: the ticket root is itself the worktree, or (multirepo) a plain parent.
if [[ -f ${project_root}/.git ]]; then
	mono_dir=$project_root
else
	mono_dir="${project_root}/${mono_repo}"
fi
multirepo=false
[[ -n $multirepo_prefix && $ticket == "${multirepo_prefix}"-* ]] && multirepo=true

if [[ $multirepo == true && $keep == false ]]; then
	# shellcheck source=/dev/null
	source "$(dirname "${BASH_SOURCE[0]}")/multirepo-worktree.sh"
	multirepo_worktree_paths_validate "$workspace_root" "$owner" "$ticket"
	if [[ -e $project_root/$(multirepo_extra) ]]; then
		multirepo_worktree_validate "$workspace_root" "$owner" "$ticket"
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

if [[ $multirepo == true ]]; then
	multirepo_worktree_remove "$workspace_root" "$owner" "$ticket"
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
	# Another worktree (e.g. a scratch rebase) may still have the branch; the
	# sandbox and its worktree are gone, so keep the branch instead of failing.
	if git -C "$bare_repo" worktree list --porcelain | rg -Fxq -- "branch refs/heads/${branch}"; then
		printf 'Note: keeping local branch %s (still checked out in another worktree)\n' "$branch"
	else
		printf '→ Deleting local branch %s…\n' "$branch"
		git -C "$bare_repo" branch -D -- "$branch"
	fi
fi

# Multirepo parent: aggregate context is generated state, proven by its marker.
if [[ $multirepo == true ]]; then
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
