#!/usr/bin/env bash
# Multirepo action: monorepo worktree plus the extra repo (master) under a non-git
# parent. The ticket prefix and extra repo come from ~/.private_work.env.
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/private-env.sh"
prefix=$(private_env_name MULTIREPO_TICKET_PREFIX)

usage() {
  printf 'Usage: multirepo-worktree-sandbox.sh <%s-ticket> <monorepo-branch>\n' "$prefix" >&2
  exit 1
}

[[ $# -ge 1 ]] || usage
if [[ $# -ge 2 ]]; then
  args=("$@")
else
  read -r -a args <<<"$1"
fi
[[ ${#args[@]} -eq 2 ]] || usage
[[ ${args[0]} =~ ^${prefix}-[0-9]+$ && ${args[1]} != -* ]] || usage
version=${args[1]#origin/}
git check-ref-format --branch "$version" >/dev/null 2>&1 || usage

export MULTIREPO_WORKSPACE=true
exec bash "$(dirname "${BASH_SOURCE[0]}")/monorepo-worktree-sandbox.sh" "${args[@]}"
