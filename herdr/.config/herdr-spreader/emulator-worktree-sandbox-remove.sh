#!/usr/bin/env bash
# Dedicated EMULATOR destroy action; reuse the five-repository cleanup lifecycle.
set -euo pipefail

usage() {
  printf 'Usage: emulator-worktree-sandbox-remove.sh <EMULATOR-ticket> [--keep-worktrees | --force]\n' >&2
  exit 1
}

[[ $# -ge 1 ]] || usage
if [[ $# -ge 2 ]]; then
  args=("$@")
else
  read -r -a args <<<"$1"
fi
[[ ${args[0]:-} =~ ^EMULATOR-[0-9]+$ ]] || usage
keep=false
force=false
for argument in "${args[@]:1}"; do
  case $argument in
  --keep-worktrees) keep=true ;;
  --force) force=true ;;
  *) usage ;;
  esac
done
[[ $keep == false || $force == false ]] || usage

exec bash "$(dirname "${BASH_SOURCE[0]}")/nvo-harness-worktree-sandbox-remove.sh" "${args[@]}"
