#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
root=$(mktemp -d)
trap 'rm -rf -- "$root"' EXIT
export HOME="$root/home"
unset MULTIREPO_TICKET_PREFIX MULTIREPO_EXTRA_REPO MULTIREPO_EXTRA_URL
mkdir -p "$HOME"
printf '%s\n' MULTIREPO_TICKET_PREFIX=MULTI MULTIREPO_EXTRA_REPO=extra-repo >"$HOME/.private_work.env"
# shellcheck source=/dev/null
source "$repo_root/herdr-spreader/.config/herdr-spreader/multirepo-worktree.sh"
mkdir -p "$root/workspace/master/extra-repo"
workspace="$root/workspace"
multirepo_worktree_paths_validate "$workspace" tester MULTI-12
if ! multirepo_worktree_paths_validate "$workspace" tester MULTI-12-MONO; then
  printf 'FAIL: side-by-side MULTI-12-MONO must be a valid physical workspace identity\n' >&2
  exit 1
fi
for ticket in MULTI-12-MONO-extra MULTI-12-mono MULTI-12/../../outside ABC-12; do
  if multirepo_worktree_paths_validate "$workspace" tester "$ticket" >/dev/null 2>&1; then
    printf 'FAIL: accepted invalid identity %s\n' "$ticket" >&2
    exit 1
  fi
done
mkdir "$root/other"
ln -s "$root/other" "$workspace/MULTI-12-MONO"
if multirepo_worktree_paths_validate "$workspace" tester MULTI-12-MONO >/dev/null 2>&1; then
  printf 'FAIL: side-by-side aliases must still reject symlinked ticket roots\n' >&2
  exit 1
fi
printf 'PASS: Multirepo -MONO aliases preserve strict identity and physical-path checks\n'
