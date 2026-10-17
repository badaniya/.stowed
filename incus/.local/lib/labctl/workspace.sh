#!/usr/bin/env bash
# Workspace discovery and validation for ticket-scoped source mounts.
set -euo pipefail

labctl_workspace_ticket_root() {
	local ticket=$1 normalized root candidate
	normalized=$(labctl_normalize_ticket "$ticket") || return 1
	root=$(realpath -m -- "$LABCTL_WORKSPACE_ROOT") || return 1
	candidate=$(realpath -m -- "${LABCTL_WORKSPACE_ROOT}/${normalized}") || return 1
	[[ $candidate == "$root"/* ]] || {
		labctl_die "ticket root escapes workspace root: $ticket"
		return 1
	}
	printf '%s\n' "$candidate"
}

labctl_workspace_harness_repos() {
	local IFS=, repo
	read -r -a repos <<<"$LABCTL_HARNESS_REPO_NAMES"
	for repo in "${repos[@]}"; do
		[[ $repo =~ ^[A-Za-z0-9._-]+$ ]] || {
			labctl_die "invalid configured harness repository name: $repo"
			return 1
		}
		printf '%s\n' "$repo"
	done
}

labctl_workspace_gitdir_is_under_master() {
	local git_file=$1 gitdir master
	[[ -f $git_file ]] || return 1
	IFS= read -r gitdir <"$git_file" || return 1
	[[ $gitdir == 'gitdir: '* ]] || return 1
	gitdir=${gitdir#gitdir: }
	master=$(realpath -m -- "$LABCTL_MASTER_ROOT") || return 1
	gitdir=$(realpath -m -- "$gitdir") || return 1
	[[ $gitdir == "$master"/* ]]
}

labctl_workspace_linked_worktrees() {
	local root=$1 git_file
	while IFS= read -r -d '' git_file; do
		labctl_workspace_gitdir_is_under_master "$git_file" || continue
		printf '%s\n' "${git_file%/.git}"
	done < <(find "$root" -mindepth 2 -maxdepth 2 -type f -name .git -print0)
}

labctl_workspace_detect() {
	local ticket=$1 selector=${2:-} root repo valid_count=0 selected
	root=$(labctl_workspace_ticket_root "$ticket") || return 1
	[[ -d $root ]] || {
		labctl_die "existing worktree prerequisite is missing: $root"
		return 1
	}

	local harness=true
	while IFS= read -r repo; do
		[[ -d $root/$repo ]] || harness=false
	done < <(labctl_workspace_harness_repos)
	if [[ $harness == true ]]; then
		printf '%s\n' harness
		return 0
	fi

	if [[ -n $selector ]]; then
		while IFS= read -r repo; do
			[[ $selector == "$repo" ]] || continue
			selected=$root/$repo
		done < <(labctl_workspace_harness_repos)
		[[ -n ${selected:-} && -d $selected ]] || {
			labctl_die "configured repository selector is not an existing worktree: $selector"
			return 1
		}
		labctl_workspace_gitdir_is_under_master "$selected/.git" || {
			labctl_die "linked worktree metadata is invalid: $selected/.git"
			return 1
		}
		printf '%s\n' single-repo
		return 0
	fi

	while IFS= read -r _; do valid_count=$((valid_count + 1)); done < <(labctl_workspace_linked_worktrees "$root")
	[[ $valid_count -eq 1 ]] || {
		labctl_die "workspace is neither a complete harness nor exactly one linked worktree: $root"
		return 1
	}
	printf '%s\n' single-repo
}

labctl_workspace_validate() {
	local ticket=$1 selector=${2:-} root workspace_type git_file
	root=$(labctl_workspace_ticket_root "$ticket") || return 1
	workspace_type=$(labctl_workspace_detect "$ticket" "$selector") || return 1
	[[ -d $LABCTL_MASTER_ROOT ]] || {
		labctl_die "bare metadata root is missing: $LABCTL_MASTER_ROOT"
		return 1
	}
	while IFS= read -r -d '' git_file; do
		labctl_workspace_gitdir_is_under_master "$git_file" || {
			labctl_die "linked worktree gitdir is outside master root: $git_file"
			return 1
		}
	done < <(find "$root" -mindepth 2 -maxdepth 2 -type f -name .git -print0)
	printf '%s\n' "$workspace_type"
}

labctl_workspace_ensure() {
	local ticket=$1 selector=${2:-} root
	root=$(labctl_workspace_ticket_root "$ticket") || return 1
	if [[ ! -d $root ]]; then
		[[ ${LABCTL_ENSURE_WORKTREE:-false} == true ]] || {
			labctl_die "existing worktree prerequisite is missing: $root (use --ensure-worktree)"
			return 1
		}
		labctl_run "$LABCTL_WORKTREE_CREATE_HOOK" "$(labctl_normalize_ticket "$ticket")" || return 1
	fi
	labctl_workspace_validate "$ticket" "$selector"
}
