#!/usr/bin/env bash
# Multirepo destroy action; force-remove the monorepo and extra repo worktrees by default.
# Pass --keep-worktrees to destroy only the sandbox; --force is still accepted.
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/private-env.sh"
prefix=$(private_env_name MULTIREPO_TICKET_PREFIX)

usage() {
  printf 'Usage: multirepo-worktree-sandbox-remove.sh <%s-ticket>[-MONO] [--keep-worktrees]\n' "$prefix" >&2
  printf 'Destroys the sandbox and force-removes worktrees by default; --keep-worktrees retains them.\n' >&2
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

[[ $# -ge 1 ]] || usage "missing ticket. Enter a ticket such as ${prefix}-11."
printf -v received '%q ' "$@"
if [[ $# -ge 2 ]]; then
  args=("$@")
else
  read -r -a args <<<"$1"
fi
[[ -n ${args[0]:-} ]] || usage "missing ticket. Enter a ticket such as ${prefix}-11."
[[ ${args[0]:-} =~ ^${prefix}-[0-9]+(-MONO)?$ ]] || usage "invalid ticket input (received: ${received% }). Expected ${prefix}-<number> or ${prefix}-<number>-MONO, e.g. ${prefix}-11-MONO (no spaces around the hyphens)."
keep=false
force=false
for argument in "${args[@]:1}"; do
  case $argument in
  --keep-worktrees) keep=true ;;
  --force) force=true ;;
  *)
    printf -v invalid_argument '%q' "$argument"
    usage "unexpected argument ${invalid_argument} (received: ${received% }). Use ${prefix}-11, optionally followed by --keep-worktrees or --force; no spaces around the ticket hyphen."
    ;;
  esac
done
[[ $keep == false || $force == false ]] || usage '--force and --keep-worktrees cannot be combined. Omit both for force removal, or use --keep-worktrees to retain worktrees.'

if [[ $keep == false && $force == false ]]; then
  args+=(--force)
fi

exec bash "$(dirname "${BASH_SOURCE[0]}")/monorepo-worktree-sandbox-remove.sh" "${args[@]}"
