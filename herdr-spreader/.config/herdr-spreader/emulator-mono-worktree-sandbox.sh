#!/usr/bin/env bash
# Dedicated EMULATOR action: monorepo worktree plus cloudemu (master) under a non-git parent.
set -euo pipefail

usage() {
  printf 'Usage: emulator-mono-worktree-sandbox.sh <EMULATOR-ticket> <monorepo-branch>\n' >&2
  exit 1
}

[[ $# -ge 1 ]] || usage
if [[ $# -ge 2 ]]; then
  args=("$@")
else
  read -r -a args <<<"$1"
fi
[[ ${#args[@]} -eq 2 ]] || usage
[[ ${args[0]} =~ ^EMULATOR-[0-9]+$ && ${args[1]} != -* ]] || usage
version=${args[1]#origin/}
git check-ref-format --branch "$version" >/dev/null 2>&1 || usage

export EMULATOR_WORKSPACE=true
exec bash "$(dirname "${BASH_SOURCE[0]}")/nvo-mono-worktree-sandbox.sh" "${args[@]}"
