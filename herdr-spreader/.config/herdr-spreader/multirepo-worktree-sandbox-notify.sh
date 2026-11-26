#!/usr/bin/env bash
# Compatibility entrypoint; the shared runner owns error reporting.
set -euo pipefail
scripts=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec python3 "$scripts/herdr-action-errors.py" run \
  --name 'Agent Sandbox Workspace: Create MULTI-REPO-WORKTREE' -- \
  bash "$scripts/multirepo-worktree-sandbox.sh" "$@"
