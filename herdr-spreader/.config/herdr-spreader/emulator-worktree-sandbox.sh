#!/usr/bin/env bash
# Dedicated EMULATOR action: the NVO release and cloudemu's master are distinct.
set -euo pipefail

usage() {
  printf 'Usage: emulator-worktree-sandbox.sh <EMULATOR-ticket> <NVO-upstream-version> [--restore-harness]\n' >&2
  exit 1
}

[[ $# -ge 1 ]] || usage
if [[ $# -ge 2 ]]; then
  args=("$@")
else
  read -r -a args <<<"$1"
fi
[[ ${#args[@]} -ge 2 && ${#args[@]} -le 3 ]] || usage
[[ ${args[0]} =~ ^EMULATOR-[0-9]+$ && ${args[1]} != -* ]] || usage
[[ ${#args[@]} -eq 2 || ${args[2]} == --restore-harness ]] || usage
version=${args[1]#origin/}
git check-ref-format --branch "$version" >/dev/null 2>&1 || usage

export EMULATOR_WORKSPACE=true
exec bash "$(dirname "${BASH_SOURCE[0]}")/nvo-harness-worktree-sandbox.sh" "${args[@]}"
