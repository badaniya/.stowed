#!/usr/bin/env bash
# monorepo-worktree-sandbox-base — create/reuse a worktree of the
# monorepo (MONOREPO_NAME, see private-env.sh) for a ticket.
#
# Usage:
#   monorepo-worktree-sandbox-base.sh '<ticket> <branch>'
#
# Layouts (ROOT = ~/workspace/<owner>):
#   regular   ROOT/<ticket>/                       the monorepo worktree itself
#               .agents .claude                    combined skills, symlinked at its root
#   multirepo ROOT/<ticket>/                       plain (non-git) parent
#               <MONOREPO_NAME>/                   monorepo worktree
#               <MULTIREPO_EXTRA_REPO>/            extra repo worktree
#               .agents .claude                    combined skills, symlinked at the parent
#
# Branch <owner>/<ticket> is created from origin/<branch> and its upstream is
# set to origin/main. MULTIREPO_WORKSPACE=true selects the multirepo layout.
set -euo pipefail

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/private-env.sh"
MONO_NAME=$(monorepo_name)
MONO_REMOTE_FETCH='+refs/heads/*:refs/remotes/origin/*'
CONTEXT_DIRS=(.agents .claude)
CONTEXT_MARKER=.herdr-aggregate-context
# Context sources relative to the monorepo (space-separated MONOREPO_CONTEXT_SOURCES
# in ~/.private_work.env); earlier entries win on conflicts.
read -r -a MONO_CONTEXT_SOURCES <<<"$(private_env MONOREPO_CONTEXT_SOURCES)"
for rel in "${MONO_CONTEXT_SOURCES[@]}"; do
	[[ $rel =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ && $rel != *..* ]] || {
		printf 'Error: invalid MONOREPO_CONTEXT_SOURCES entry: %s\n' "$rel" >&2
		exit 1
	}
done

has_non_directory_ancestor() {
	local root=$1 path=$2
	while [[ $path != "$root" ]]; do
		if [[ -L $path || (-e $path && ! -d $path) ]]; then
			return 0
		fi
		path=$(dirname "$path")
	done
	return 1
}

# build_context_tree <context_dir> <destination> <source_root>...
build_context_tree() {
	local context_dir=$1 destination=$2 source_root source relative target destination_path
	shift 2
	mkdir -p "$destination"
	: >"$destination/$CONTEXT_MARKER"
	for source_root in "$@"; do
		source="$source_root/$context_dir"
		[[ -d $source ]] || continue
		while IFS= read -r -d '' target; do
			relative=${target#"$source/"}
			destination_path="$destination/$relative"
			[[ -e $destination_path || -L $destination_path ]] && continue
			has_non_directory_ancestor "$destination" "$(dirname "$destination_path")" && continue
			mkdir -p "$destination_path"
		done < <(find -H "$source" -mindepth 1 -type d -print0)
		while IFS= read -r -d '' target; do
			relative=${target#"$source/"}
			[[ $relative == "$CONTEXT_MARKER" ]] && continue
			destination_path="$destination/$relative"
			[[ -e $destination_path || -L $destination_path ]] && continue
			has_non_directory_ancestor "$destination" "$(dirname "$destination_path")" && continue
			mkdir -p "$(dirname "$destination_path")"
			ln -s "$target" "$destination_path"
		done < <(find -H "$source" -mindepth 1 \( -type f -o -type l \) -print0)
	done
}

# aggregate_context_trees <destination_parent> <source_root>...
aggregate_context_trees() {
	local parent=$1 context_dir root temp source_root
	local -a skill_sources=()
	shift
	# Some sources use .agents/skills and others .claude/skills.
	# Preserve source precedence across both layouts.
	for source_root in "$@"; do
		skill_sources+=("$source_root/.agents" "$source_root/.claude")
	done
	for context_dir in "${CONTEXT_DIRS[@]}"; do
		root="$parent/$context_dir"
		if [[ -e $root || -L $root ]]; then
			[[ ! -L $root && -d $root && -f $root/$CONTEXT_MARKER ]] || {
				printf 'Error: refusing to replace unmanaged aggregate root: %s\n' "$root" >&2
				return 1
			}
		fi
		temp=$(mktemp -d "$parent/.${context_dir#.}.tmp.XXXXXX")
		build_context_tree "$context_dir" "$temp" "$@"
		# Replace only the generated temporary skills subtree; never follow a
		# source's whole-directory symlink and write back into its repository.
		rm -rf -- "$temp/skills"
		if [[ $context_dir == .agents ]]; then
			build_context_tree skills "$temp/skills" "${skill_sources[@]}"
			rm -f -- "$temp/skills/$CONTEXT_MARKER"
		else
			ln -s ../.agents/skills "$temp/skills"
		fi
		rm -rf "$root"
		mv "$temp" "$root"
	done
}

# Keep generated aggregate trees out of `git status` in the monorepo worktree.
exclude_context_trees() {
	local worktree=$1 exclude context_dir
	exclude=$(git -C "$worktree" rev-parse --path-format=absolute --git-path info/exclude)
	mkdir -p "$(dirname "$exclude")"
	touch "$exclude"
	for context_dir in "${CONTEXT_DIRS[@]}"; do
		rg -Fxq -- "/$context_dir" "$exclude" || printf '/%s\n' "$context_dir" >>"$exclude"
	done
}

if [[ $# -lt 1 ]]; then
	echo "Usage: monorepo-worktree-sandbox-base.sh <ticket> <branch>" >&2
	exit 1
fi
if [[ $# -ge 2 ]]; then
	RAW_ARGS=("$@")
else
	read -r -a RAW_ARGS <<<"$1"
fi
TICKET=${RAW_ARGS[0]:-}
BASE_BRANCH=${RAW_ARGS[1]:-}
BASE_BRANCH=${BASE_BRANCH#origin/}
if [[ -z $TICKET || -z $BASE_BRANCH || ${#RAW_ARGS[@]} -gt 2 ]]; then
	echo "Usage: monorepo-worktree-sandbox-base.sh <ticket> <branch>" >&2
	exit 1
fi
git check-ref-format --branch "$BASE_BRANCH" >/dev/null 2>&1 || {
	printf 'Error: invalid branch name: %s\n' "$BASE_BRANCH" >&2
	exit 1
}

WORKSPACE_OWNER=${WS_OWNER:-${USER:?}}
WORKSPACE_ROOT=${WS_ROOT:-"${HOME}/workspace/${WORKSPACE_OWNER}"}
PROJECT_DIR="${WORKSPACE_ROOT}/${TICKET}"
BARE_REPO="${WORKSPACE_ROOT}/master/${MONO_NAME}"
NEW_BRANCH="${WORKSPACE_OWNER}/${TICKET}"
MULTIREPO=${MULTIREPO_WORKSPACE:-false}

if [[ $MULTIREPO == true ]]; then
	MONO_DIR="${PROJECT_DIR}/${MONO_NAME}"
	# shellcheck source=/dev/null
	source "$(dirname "${BASH_SOURCE[0]}")/multirepo-worktree.sh"
else
	MONO_DIR="$PROJECT_DIR"
fi

[[ $(git -C "$BARE_REPO" rev-parse --is-bare-repository 2>/dev/null) == true ]] || {
	echo "Error: bare repo not found at ${BARE_REPO}" >&2
	exit 1
}

# The bare clone needs a fetch mapping so origin/<branch> refs exist.
if ! git -C "$BARE_REPO" config --get-all remote.origin.fetch | rg -Fxq -- "$MONO_REMOTE_FETCH"; then
	git -C "$BARE_REPO" config --replace-all remote.origin.fetch "$MONO_REMOTE_FETCH"
fi

# Fetch and LFS checkout use pass-backed command-scoped credentials, not native
# gh storage or exported token-bearing HTTP headers. Clear inherited overrides.
unset GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN
export GIT_CONFIG_COUNT=4
export GIT_CONFIG_KEY_0=http.extraheader GIT_CONFIG_VALUE_0=''
export GIT_CONFIG_KEY_1=http.https://github.com/.extraheader GIT_CONFIG_VALUE_1=''
export GIT_CONFIG_KEY_2=credential.helper GIT_CONFIG_VALUE_2=''
export GIT_CONFIG_KEY_3=credential.helper
GIT_CONFIG_VALUE_3="!\"$HOME/.local/bin/gh-work\" auth git-credential"
export GIT_CONFIG_VALUE_3
mono_fetch() { git -C "$BARE_REPO" fetch --quiet origin; }

if [[ -e "${MONO_DIR}/.git" ]]; then
	echo "→ Worktree already exists at ${MONO_DIR}, reusing it…"
else
	if [[ $MULTIREPO != true && -e $PROJECT_DIR ]]; then
		printf 'Error: %s exists but is not a monorepo worktree\n' "$PROJECT_DIR" >&2
		exit 1
	fi
	echo "→ Fetching ${BARE_REPO}…"
	mono_fetch
	git -C "$BARE_REPO" show-ref --verify --quiet "refs/remotes/origin/${BASE_BRANCH}" || {
		printf 'Error: origin/%s does not exist in %s\n' "$BASE_BRANCH" "$MONO_NAME" >&2
		exit 1
	}
	git -C "$BARE_REPO" show-ref --verify --quiet refs/remotes/origin/main || {
		echo "Error: origin/main does not exist in ${MONO_NAME}" >&2
		exit 1
	}
	mkdir -p -- "$(dirname "$MONO_DIR")"
	if [[ ${MONO_REVIEW_MODE:-false} == true ]]; then
		# Review: check out the PR branch itself (tracking origin/<branch>); no private branch.
		echo "→ Creating review worktree for '${BASE_BRANCH}' at ${MONO_DIR}…"
		if git -C "$BARE_REPO" worktree list --porcelain | rg -Fxq -- "branch refs/heads/${BASE_BRANCH}"; then
			# A developer may already be using this branch. Review the remote PR
			# snapshot detached; never force a second checkout or alter their files.
			git -C "$BARE_REPO" worktree add --detach "$MONO_DIR" "refs/remotes/origin/${BASE_BRANCH}"
		elif git -C "$BARE_REPO" show-ref --verify --quiet "refs/heads/${BASE_BRANCH}"; then
			git -C "$BARE_REPO" merge-base --is-ancestor "refs/heads/${BASE_BRANCH}" "refs/remotes/origin/${BASE_BRANCH}" || {
				printf 'Error: local branch %s has commits not in the PR; refusing to replace it\n' "$BASE_BRANCH" >&2
				exit 1
			}
			git -C "$BARE_REPO" worktree add "$MONO_DIR" "$BASE_BRANCH"
			git -C "$MONO_DIR" merge --ff-only "refs/remotes/origin/${BASE_BRANCH}"
		else
			git -C "$BARE_REPO" worktree add --track -b "$BASE_BRANCH" "$MONO_DIR" "refs/remotes/origin/${BASE_BRANCH}"
		fi
	else
		echo "→ Creating worktree '${NEW_BRANCH}' (from 'origin/${BASE_BRANCH}', tracking origin/main) at ${MONO_DIR}…"
		git -C "$BARE_REPO" worktree add --no-track -b "$NEW_BRANCH" "$MONO_DIR" "refs/remotes/origin/${BASE_BRANCH}"
		git -C "$MONO_DIR" branch --set-upstream-to=origin/main "$NEW_BRANCH"
	fi
fi

if [[ $MULTIREPO == true ]]; then
	multirepo_worktree_prepare "$WORKSPACE_ROOT" "$WORKSPACE_OWNER" "$TICKET"
fi

sources=()
for rel in "${MONO_CONTEXT_SOURCES[@]}"; do
	sources+=("${MONO_DIR}/${rel}")
done
if [[ $MULTIREPO == true ]]; then
	sources+=("${PROJECT_DIR}/$(multirepo_extra)")
	aggregate_context_trees "$PROJECT_DIR" "${sources[@]}"
else
	aggregate_context_trees "$PROJECT_DIR" "${sources[@]}"
	exclude_context_trees "$MONO_DIR"
fi
echo "→ Created aggregate .agents and .claude context trees."

export PROJECT_DIR MONO_DIR
