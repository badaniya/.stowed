#!/usr/bin/env bash
# Destroy a review sandbox and force-remove its linked worktrees.
# Local PR branches (including unpushed commits) and remote branches are retained.
# Usage: nvo-review-remove.sh '<JIRA#|NVO-REVIEW-JIRA#|NVO-REVIEW-<REPO>-PR-#> [--keep-worktrees]'
set -euo pipefail

error() { printf 'Error: %s\n' "$*" >&2; exit 1; }
if (($# == 1)); then read -r -a args <<<"$1"; else args=("$@"); fi
((${#args[@]} >= 1 && ${#args[@]} <= 2)) || error 'Usage: nvo-review-remove.sh <JIRA#|NVO-REVIEW-<REPO>-PR-#> [--keep-worktrees]'
ticket=${args[0]#NVO-REVIEW-}
[[ $ticket =~ ^[A-Z][A-Z0-9]+-[0-9]+$ || $ticket =~ ^(GODCAPP|PCM|PS|PSC)-PR-[1-9][0-9]*$ ]] || error 'invalid review identity; use a Jira key or NVO-REVIEW-<REPO>-PR-<number>'
keep=false
case ${args[1]:-} in
  '') ;;
  --keep-worktrees) keep=true ;;
  *) error 'Usage: nvo-review-remove.sh <JIRA#|NVO-REVIEW-<REPO>-PR-#> [--keep-worktrees]' ;;
esac
key="NVO-REVIEW-$ticket"
root=${NVO_WORKSPACE_ROOT:-"$HOME/workspace/${NVO_WORKSPACE_OWNER:-${USER:?}}"}
root=$(cd "$root" && pwd -P)
project="$root/$key"
state="${XDG_STATE_HOME:-$HOME/.local/state}/herdr-spreader"
labctl="$HOME/.local/bin/labctl"
repos=(GoDCApp PlatformServices PlatformServicesCommon PlatformCommonModels)
[[ -x $labctl ]] || error "labctl is unavailable at $labctl; stow the incus package first"
[[ ! -L $project && ! -L $project/.nvo-review && ! -L $state && ! -L $state/$key.lock ]] || error 'review project/state must not be symlinks'
mkdir -p "$state"
# Keep the lock file: unlinking a held lock would allow a new launcher to bypass it.
exec 9>"$state/$key.lock"
flock -n 9 || error "$key is already preparing/building; retry after bootstrap finishes"

# Validate every target before destroying the sandbox or changing any worktree.
if [[ $keep == false ]]; then
  for repo in "${repos[@]}"; do
    bare="$root/master/$repo"
    worktree="$project/$repo"
    [[ -d $bare && ! -L $worktree ]] || error "missing shared repository or symlinked worktree: $repo"
    listing=$(git -C "$bare" worktree list --porcelain)
    if [[ -e $worktree ]]; then
      [[ -d $worktree && -f $worktree/.git && ! -L $worktree/.git ]] || error "not a linked review worktree: $worktree"
      common=$(git -C "$worktree" rev-parse --path-format=absolute --git-common-dir)
      [[ $(realpath -- "$common") == "$(realpath -- "$bare")" ]] || error "worktree belongs to another repository: $worktree"
      rg -Fxq -- "worktree $worktree" <<<"$listing" || error "unregistered review worktree: $worktree"
    fi
  done
fi
workspace_ids=$(herdr workspace list | jq -r --arg key "$key" \
  '.result.workspaces[] | select(.label == $key or (.label | startswith($key + " "))) | .workspace_id')
printf -v command '%q %q %q %q' "$labctl" destroy "$key" --yes
printf '→ Destroying review sandbox %s…\n' "$key"
sg incus-admin -c "$command"

if [[ $keep == false ]]; then
  for repo in "${repos[@]}"; do
    bare="$root/master/$repo"
    worktree="$project/$repo"
    if [[ -d $worktree ]]; then
      # Sandbox-generated build artifacts may be root-owned. Do not follow links.
      sudo chown -R --no-dereference "$(id -un):$(id -gn)" "$worktree"
    fi
    listing=$(git -C "$bare" worktree list --porcelain)
    if rg -Fxq -- "worktree $worktree" <<<"$listing"; then
      printf '→ Removing review worktree %s (preserving local branches)…\n' "$worktree"
      if ! git -C "$bare" worktree remove --force "$worktree"; then
        # Git refuses worktrees with initialized submodules. Targets have already
        # been verified against their shared repository; remove only that tree,
        # then deregister the missing worktree without globally pruning others.
        rm -rf --one-file-system -- "$worktree"
        listing=$(git -C "$bare" worktree list --porcelain)
        if rg -Fxq -- "worktree $worktree" <<<"$listing"; then
          git -C "$bare" worktree remove --force "$worktree"
        fi
      fi
    fi
  done
  for context in .agents .claude; do
    if [[ ! -L $project/$context && -f $project/$context/.herdr-aggregate-context ]]; then
      rm -rf --one-file-system -- "${project:?}/$context"
    fi
  done
  rm -rf --one-file-system -- "$project/.nvo-review"
  # Remove only this review's generated state, never neighboring Jira reviews.
  rm -rf --one-file-system -- "$state/$key.stages" "$state/$key.pane-history"
  rm -f -- "$state/$key.log" "$state/$key.log.worker-ready" "$state/$key.log.monitor-pane"
  for repo in "${repos[@]}"; do rm -f -- "$state/$key.$repo.gh-dash.yml"; done
  if [[ -d $project ]]; then
    if [[ -z $(ls -A "$project") ]]; then rmdir -- "$project";
    else printf 'Note: retaining unrecognized files at %s.\n' "$project"; fi
  fi
else
  printf '→ Keeping review worktrees, branches and state at %s.\n' "$project"
fi
# Closing the calling workspace can terminate this process, so do it last.
while IFS= read -r workspace_id; do
  [[ -n $workspace_id ]] || continue
  herdr workspace close "$workspace_id" >/dev/null
done <<<"$workspace_ids"
