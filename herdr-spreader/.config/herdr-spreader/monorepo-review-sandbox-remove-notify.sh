#!/usr/bin/env bash
set -euo pipefail
scripts=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec python3 "$scripts/herdr-action-errors.py" run \
  --name 'Agent Sandbox Workspace: Delete MONOREPO-REVIEW' -- \
  bash "$scripts/monorepo-review-sandbox-remove.sh" "$@"
