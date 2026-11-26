#!/usr/bin/env bash
# Sourced helpers for the multirepo layout's extra worktree. No sandbox actions.
#
# The extra repository, its clone URL and the ticket prefix that selects this
# layout are internal, so they live in ~/.private_work.env (see private-env.sh):
#   MULTIREPO_TICKET_PREFIX  MULTIREPO_EXTRA_REPO  MULTIREPO_EXTRA_URL

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/private-env.sh"

multirepo_extra() { private_env_name MULTIREPO_EXTRA_REPO; }
multirepo_prefix() { private_env_name MULTIREPO_TICKET_PREFIX; }
multirepo_extra_url() { private_env MULTIREPO_EXTRA_URL; }

# Reduce a git remote URL to host/path so https and ssh forms compare equal.
multirepo_remote_key() {
  local url=${1%.git}
  url=${url#*://}
  url=${url#*@}
  printf '%s\n' "${url/://}"
}

multirepo_worktree_paths_validate() {
  local extra prefix
  extra=$(multirepo_extra) || return 1
  prefix=$(multirepo_prefix) || return 1
  local root=$1 owner=$2 ticket=$3 path
  # A -MONO alias keeps live monorepo tests beside the original ticket workspace.
  [[ $root == /* && -d $root && $owner =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ && $ticket =~ ^${prefix}-[0-9]+(-MONO)?$ ]] || {
    printf 'Error: invalid multirepo workspace root, owner or ticket\n' >&2
    return 1
  }
  # Refuse symlinked ancestors as well as symlinked checkout/metadata roots.
  for path in "$root" "$root/master" "$root/master/$extra" "$root/$ticket" "$root/$ticket/$extra"; do
    [[ ! -L $path && $(realpath -m -- "$path") == "$path" && (! -e $path || -d $path) ]] || {
      printf 'Error: extra repo path is not a physical directory: %s\n' "$path" >&2
      return 1
    }
  done
}

multirepo_worktree_shared_validate() {
  local bare=$1 origin expected
  [[ -d $bare && $(git -C "$bare" rev-parse --is-bare-repository 2>/dev/null) == true ]] || {
    printf 'Error: expected a shared bare extra repo clone at %s\n' "$bare" >&2
    return 1
  }
  origin=$(git -C "$bare" config --get remote.origin.url) || {
    printf 'Error: shared extra repo clone has no origin: %s\n' "$bare" >&2
    return 1
  }
  expected=$(multirepo_extra_url) || return 1
  [[ $(multirepo_remote_key "$origin") == "$(multirepo_remote_key "$expected")" ]] || {
    printf 'Error: shared extra repo origin is not %s: %s\n' "$expected" "$bare" >&2
    return 1
  }
}

multirepo_worktree_validate() {
  local extra prefix
  extra=$(multirepo_extra) || return 1
  local root=$1 owner=$2 ticket=$3 common top branch
  multirepo_worktree_paths_validate "$root" "$owner" "$ticket" || return 1
  multirepo_worktree_shared_validate "$root/master/$extra" || return 1
  local worktree="$root/$ticket/$extra"
  if ! common=$(git -C "$worktree" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) ||
    ! top=$(git -C "$worktree" rev-parse --show-toplevel 2>/dev/null) ||
    ! branch=$(git -C "$worktree" symbolic-ref --quiet HEAD 2>/dev/null); then
    printf 'Error: expected a linked extra repo worktree on its ticket branch: %s\n' "$worktree" >&2
    return 1
  fi
  [[ -f $worktree/.git && $top == "$worktree" && $(realpath -e -- "$common") == "$root/master/$extra" && $branch == "refs/heads/$owner/$extra/$ticket" ]] || {
    printf 'Error: extra repo worktree has an unexpected repository or branch: %s\n' "$worktree" >&2
    return 1
  }
  git -C "$root/master/$extra" worktree list --porcelain | rg -Fxq -- "worktree $worktree" || {
    printf 'Error: extra repo worktree is not registered: %s\n' "$worktree" >&2
    return 1
  }
}

multirepo_worktree_prepare() {
  local extra prefix
  extra=$(multirepo_extra) || return 1
  local root=$1 owner=$2 ticket=$3 temporary upstream url
  multirepo_worktree_paths_validate "$root" "$owner" "$ticket" || return 1
  local bare="$root/master/$extra" worktree="$root/$ticket/$extra" branch="$owner/$extra/$ticket"
  if [[ -e $worktree ]]; then
    multirepo_worktree_validate "$root" "$owner" "$ticket" || return 1
    printf '→ Reusing extra repo worktree at %s (preserving HEAD and local changes).\n' "$worktree"
    return 0
  fi
  if [[ ! -e $bare ]]; then
    mkdir -p -- "$root/master" || return 1
    url=$(multirepo_extra_url) || return 1
    temporary=$(mktemp -d "$root/master/.${extra}.clone.XXXXXX") || return 1
    if ! git clone --bare "$url" "$temporary/repository"; then
      rm -rf -- "$temporary"
      return 1
    fi
    if ! git -C "$temporary/repository" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*' ||
      ! mv -T -- "$temporary/repository" "$bare"; then
      rm -rf -- "$temporary"
      return 1
    fi
    rmdir -- "$temporary" || return 1
  fi
  multirepo_worktree_shared_validate "$bare" || return 1
  # Existing clone --bare repositories may have no fetch mapping. Git needs
  # one to recognize origin/master as a remote branch for --track.
  if ! git -C "$bare" config --get-all remote.origin.fetch | rg -Fxq -e '+refs/heads/*:refs/remotes/origin/*' -e '+refs/heads/master:refs/remotes/origin/master'; then
    git -C "$bare" config --add remote.origin.fetch '+refs/heads/master:refs/remotes/origin/master' || return 1
  fi
  git -C "$bare" fetch --quiet origin '+refs/heads/master:refs/remotes/origin/master' || return 1
  mkdir -p -- "$root/$ticket" || return 1
  if git -C "$bare" show-ref --verify --quiet "refs/heads/$branch"; then
    upstream=$(git -C "$bare" for-each-ref --format='%(upstream)' "refs/heads/$branch") || return 1
    [[ $upstream == refs/remotes/origin/master ]] || {
      printf 'Error: existing extra repo ticket branch has an unexpected upstream: %s\n' "$branch" >&2
      return 1
    }
    git -C "$bare" worktree add "$worktree" "$branch" || return 1
  else
    git -C "$bare" worktree add --track -b "$branch" "$worktree" refs/remotes/origin/master || return 1
  fi
  multirepo_worktree_validate "$root" "$owner" "$ticket"
}

# Called only by the existing destructive sandbox removal lifecycle.
multirepo_worktree_remove() {
  local extra prefix
  extra=$(multirepo_extra) || return 1
  local root=$1 owner=$2 ticket=$3 upstream
  multirepo_worktree_paths_validate "$root" "$owner" "$ticket" || return 1
  local bare="$root/master/$extra" worktree="$root/$ticket/$extra" branch="$owner/$extra/$ticket"
  [[ -e $bare || -e $worktree ]] || return 0
  multirepo_worktree_shared_validate "$bare" || return 1
  if [[ -e $worktree ]]; then
    multirepo_worktree_validate "$root" "$owner" "$ticket" || return 1
  fi
  if git -C "$bare" show-ref --verify --quiet "refs/heads/$branch"; then
    upstream=$(git -C "$bare" for-each-ref --format='%(upstream)' "refs/heads/$branch") || return 1
    # Publishing with push -u switches tracking from master to this ticket.
    # Neither state prevents destructive cleanup, including untracked files.
    [[ $upstream == refs/remotes/origin/master || $upstream == "refs/remotes/origin/$branch" ]] || {
      printf 'Error: refusing to delete extra repo branch with unexpected upstream: %s\n' "$branch" >&2
      return 1
    }
    if [[ -e $worktree ]]; then
      git -C "$bare" worktree remove --force -- "$worktree" || return 1
    fi
    if git -C "$bare" worktree list --porcelain | rg -Fxq -- "branch refs/heads/$branch"; then
      printf 'Error: extra repo branch is still checked out in another worktree: %s\n' "$branch" >&2
      return 1
    fi
    git -C "$bare" branch -D -- "$branch" || return 1
  fi
}
