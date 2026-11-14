#!/usr/bin/env bash
# Compatibility entrypoint; the shared runner owns error reporting.
set -euo pipefail
scripts=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec python3 "$scripts/herdr-action-errors.py" run \
  --name 'Open workspace & bootstrap sandbox: EMULATOR-WORKTREE-SANDBOX' -- \
  bash "$scripts/emulator-worktree-sandbox.sh" "$@"
