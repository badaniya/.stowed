#!/usr/bin/env bash
# Dedicated EMULATOR destroy action; force-remove all five worktrees by default.
# Pass --keep-worktrees to destroy only the sandbox; --force is still accepted.
set -euo pipefail

usage() {
  printf 'Usage: emulator-worktree-sandbox-remove.sh <EMULATOR-ticket> [--keep-worktrees]\n' >&2
  printf 'Destroys the sandbox and force-removes worktrees by default; --keep-worktrees retains them.\n' >&2
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

[[ $# -ge 1 ]] || usage 'missing ticket. Enter a ticket such as EMULATOR-11.'
printf -v received '%q ' "$@"
if [[ $# -ge 2 ]]; then
  args=("$@")
else
  read -r -a args <<<"$1"
fi
[[ -n ${args[0]:-} ]] || usage 'missing ticket. Enter a ticket such as EMULATOR-11.'
[[ ${args[0]:-} =~ ^EMULATOR-[0-9]+$ ]] || usage "invalid ticket input (received: ${received% }). Expected EMULATOR-<number>, e.g. EMULATOR-11 (no spaces around the hyphen)."
keep=false
force=false
for argument in "${args[@]:1}"; do
  case $argument in
  --keep-worktrees) keep=true ;;
  --force) force=true ;;
  *)
    printf -v invalid_argument '%q' "$argument"
    usage "unexpected argument ${invalid_argument} (received: ${received% }). Use EMULATOR-11, optionally followed by --keep-worktrees or --force; no spaces around the ticket hyphen."
    ;;
  esac
done
[[ $keep == false || $force == false ]] || usage '--force and --keep-worktrees cannot be combined. Omit both for force removal, or use --keep-worktrees to retain worktrees.'

if [[ $keep == false && $force == false ]]; then
  args+=(--force)
fi

exec bash "$(dirname "${BASH_SOURCE[0]}")/nvo-harness-worktree-sandbox-remove.sh" "${args[@]}"
