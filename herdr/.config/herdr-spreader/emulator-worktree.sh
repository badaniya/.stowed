#!/usr/bin/env bash
# Sourced helpers for the extra EMULATOR cloudemu worktree. No sandbox actions.

emulator_worktree_paths_validate() {
  local root=$1 owner=$2 ticket=$3 path
  [[ $root == /* && -d $root && $owner =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ && $ticket =~ ^EMULATOR-[0-9]+$ ]] || {
    printf 'Error: invalid EMULATOR workspace root, owner or ticket\n' >&2
    return 1
  }
  # Refuse symlinked ancestors as well as symlinked checkout/metadata roots.
  for path in "$root" "$root/master" "$root/master/cloudemu" "$root/$ticket" "$root/$ticket/cloudemu"; do
    [[ ! -L $path && $(realpath -m -- "$path") == "$path" && (! -e $path || -d $path) ]] || {
      printf 'Error: cloudemu path is not a physical directory: %s\n' "$path" >&2
      return 1
    }
  done
}

emulator_worktree_shared_validate() {
  local bare=$1 origin
  [[ -d $bare && $(git -C "$bare" rev-parse --is-bare-repository 2>/dev/null) == true ]] || {
    printf 'Error: expected a shared bare cloudemu clone at %s\n' "$bare" >&2
    return 1
  }
  origin=$(git -C "$bare" config --get remote.origin.url) || {
    printf 'Error: shared cloudemu clone has no origin: %s\n' "$bare" >&2
    return 1
  }
  case "$origin" in
  https://github.extremenetworks.com/thomma/cloudemu.git | https://github.extremenetworks.com/thomma/cloudemu | git@github.extremenetworks.com:thomma/cloudemu.git | ssh://git@github.extremenetworks.com/thomma/cloudemu.git) ;;
  *)
    printf 'Error: shared cloudemu origin is not thomma/cloudemu: %s\n' "$bare" >&2
    return 1
    ;;
  esac
}

emulator_worktree_validate() {
  local root=$1 owner=$2 ticket=$3 common top branch
  emulator_worktree_paths_validate "$root" "$owner" "$ticket" || return 1
  emulator_worktree_shared_validate "$root/master/cloudemu" || return 1
  local worktree="$root/$ticket/cloudemu"
  if ! common=$(git -C "$worktree" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) ||
    ! top=$(git -C "$worktree" rev-parse --show-toplevel 2>/dev/null) ||
    ! branch=$(git -C "$worktree" symbolic-ref --quiet HEAD 2>/dev/null); then
    printf 'Error: expected a linked cloudemu worktree on its ticket branch: %s\n' "$worktree" >&2
    return 1
  fi
  [[ -f $worktree/.git && $top == "$worktree" && $(realpath -e -- "$common") == "$root/master/cloudemu" && $branch == "refs/heads/$owner/cloudemu/$ticket" ]] || {
    printf 'Error: cloudemu worktree has an unexpected repository or branch: %s\n' "$worktree" >&2
    return 1
  }
  git -C "$root/master/cloudemu" worktree list --porcelain | rg -Fxq -- "worktree $worktree" || {
    printf 'Error: cloudemu worktree is not registered: %s\n' "$worktree" >&2
    return 1
  }
}

emulator_worktree_prepare() {
  local root=$1 owner=$2 ticket=$3 temporary upstream
  emulator_worktree_paths_validate "$root" "$owner" "$ticket" || return 1
  local bare="$root/master/cloudemu" worktree="$root/$ticket/cloudemu" branch="$owner/cloudemu/$ticket"
  if [[ -e $worktree ]]; then
    emulator_worktree_validate "$root" "$owner" "$ticket" || return 1
    printf '→ Reusing cloudemu worktree at %s (preserving HEAD and local changes).\n' "$worktree"
    return 0
  fi
  if [[ ! -e $bare ]]; then
    mkdir -p -- "$root/master" || return 1
    temporary=$(mktemp -d "$root/master/.cloudemu.clone.XXXXXX") || return 1
    if ! git clone --bare https://github.extremenetworks.com/thomma/cloudemu.git "$temporary/repository"; then
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
  emulator_worktree_shared_validate "$bare" || return 1
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
      printf 'Error: existing cloudemu ticket branch has an unexpected upstream: %s\n' "$branch" >&2
      return 1
    }
    git -C "$bare" worktree add "$worktree" "$branch" || return 1
  else
    git -C "$bare" worktree add --track -b "$branch" "$worktree" refs/remotes/origin/master || return 1
  fi
  emulator_worktree_validate "$root" "$owner" "$ticket"
}

# Called only by the existing destructive sandbox removal lifecycle.
emulator_worktree_remove() {
  local root=$1 owner=$2 ticket=$3 upstream
  emulator_worktree_paths_validate "$root" "$owner" "$ticket" || return 1
  local bare="$root/master/cloudemu" worktree="$root/$ticket/cloudemu" branch="$owner/cloudemu/$ticket"
  [[ -e $bare || -e $worktree ]] || return 0
  emulator_worktree_shared_validate "$bare" || return 1
  if [[ -e $worktree ]]; then
    emulator_worktree_validate "$root" "$owner" "$ticket" || return 1
  fi
  if git -C "$bare" show-ref --verify --quiet "refs/heads/$branch"; then
    upstream=$(git -C "$bare" for-each-ref --format='%(upstream)' "refs/heads/$branch") || return 1
    [[ $upstream == refs/remotes/origin/master ]] || {
      printf 'Error: refusing to delete cloudemu branch with unexpected upstream: %s\n' "$branch" >&2
      return 1
    }
    if [[ -e $worktree ]]; then
      git -C "$bare" worktree remove --force -- "$worktree" || return 1
    fi
    if git -C "$bare" worktree list --porcelain | rg -Fxq -- "branch refs/heads/$branch"; then
      printf 'Error: cloudemu branch is still checked out in another worktree: %s\n' "$branch" >&2
      return 1
    fi
    git -C "$bare" branch -D -- "$branch" || return 1
  fi
}
