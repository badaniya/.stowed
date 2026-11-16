#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=/dev/null
source "$repo_root/herdr-spreader/.config/herdr-spreader/emulator-worktree.sh"
root=$(mktemp -d)
trap 'rm -rf -- "$root"' EXIT
mkdir -p "$root/workspace/master/cloudemu"
workspace="$root/workspace"
emulator_worktree_paths_validate "$workspace" tester EMULATOR-12
if ! emulator_worktree_paths_validate "$workspace" tester EMULATOR-12-MONO; then
  printf 'FAIL: side-by-side EMULATOR-12-MONO must be a valid physical workspace identity\n' >&2
  exit 1
fi
for ticket in EMULATOR-12-MONO-extra EMULATOR-12-mono EMULATOR-12/../../outside NVO-12; do
  if emulator_worktree_paths_validate "$workspace" tester "$ticket" >/dev/null 2>&1; then
    printf 'FAIL: accepted invalid identity %s\n' "$ticket" >&2
    exit 1
  fi
done
mkdir "$root/other"
ln -s "$root/other" "$workspace/EMULATOR-12-MONO"
if emulator_worktree_paths_validate "$workspace" tester EMULATOR-12-MONO >/dev/null 2>&1; then
  printf 'FAIL: side-by-side aliases must still reject symlinked ticket roots\n' >&2
  exit 1
fi
printf 'PASS: EMULATOR mono aliases preserve strict identity and physical-path checks\n'
