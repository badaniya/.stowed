#!/usr/bin/env bash
# Destroy a monorepo review sandbox and force-remove its worktree.
# The local PR branch (incl. unpushed commits) and the remote branch are retained.
# Usage: nvo-review-mono-remove.sh '<JIRA#|NVO-REVIEW-JIRA#|NVO-REVIEW-PR-#> [--keep-worktrees]'
set -euo pipefail

error() { printf 'Error: %s\n' "$*" >&2; exit 1; }
if (($# == 1)); then read -r -a args <<<"$1"; else args=("$@"); fi
((${#args[@]} >= 1 && ${#args[@]} <= 2)) || error 'Usage: nvo-review-mono-remove.sh <JIRA#|NVO-REVIEW-PR-#> [--keep-worktrees]'
ticket=${args[0]#NVO-REVIEW-}
[[ $ticket =~ ^[A-Z][A-Z0-9]+-[0-9]+$ || $ticket =~ ^PR-[1-9][0-9]*$ ]] || error 'invalid review identity; use a Jira key or NVO-REVIEW-PR-<number>'
keep=false
case ${args[1]:-} in
  '') ;;
  --keep-worktrees) keep=true ;;
  *) error 'Usage: nvo-review-mono-remove.sh <JIRA#|NVO-REVIEW-PR-#> [--keep-worktrees]' ;;
esac
key="NVO-REVIEW-$ticket"
root=${NVO_WORKSPACE_ROOT:-"$HOME/workspace/${NVO_WORKSPACE_OWNER:-${USER:?}}"}
root=$(cd "$root" && pwd -P)
project="$root/$key"
bare="$root/master/xcloud-platform-services"
state="${XDG_STATE_HOME:-$HOME/.local/state}/herdr-spreader"
labctl="$HOME/.local/bin/labctl"
[[ -x $labctl ]] || error "labctl is unavailable at $labctl; stow the incus package first"
[[ ! -L $project && ! -L $state && ! -L $state/$key.lock ]] || error 'review project/state must not be symlinks'
mkdir -p "$state"
exec 9>"$state/$key.lock"
flock -n 9 || error "$key is already preparing/building; retry after bootstrap finishes"

if [[ $keep == false && -e $project ]]; then
  [[ -d $bare && -f $project/.git && ! -L $project/.git ]] || error "not a monorepo review worktree: $project"
  common=$(git -C "$project" rev-parse --path-format=absolute --git-common-dir)
  [[ $(realpath -- "$common") == "$(realpath -- "$bare")" ]] || error "worktree belongs to another repository: $project"
fi
workspace_ids=$(herdr workspace list | jq -r --arg key "$key" \
  '.result.workspaces[] | select(.label == $key or (.label | startswith($key + " "))) | .workspace_id')
printf -v command '%q %q %q %q' "$labctl" destroy "$key" --yes
printf '→ Destroying review sandbox %s…\n' "$key"
sg incus-admin -c "$command"

if [[ $keep == false ]]; then
  if [[ -d $project ]]; then
    sudo chown -R --no-dereference "$(id -un):$(id -gn)" "$project"
    printf '→ Removing review worktree %s (preserving local branch)…\n' "$project"
    git -C "$bare" worktree remove --force "$project"
  fi
  rm -rf --one-file-system -- "$state/$key.stages" "$state/$key.pane-history"
  rm -f -- "$state/$key.log" "$state/$key.log.worker-ready" "$state/$key.log.monitor-pane" "$state/$key.gh-dash.yml"
else
  printf '→ Keeping review worktree, branch and state at %s.\n' "$project"
fi
while IFS= read -r workspace_id; do
  [[ -n $workspace_id ]] || continue
  herdr workspace close "$workspace_id" >/dev/null
done <<<"$workspace_ids"
