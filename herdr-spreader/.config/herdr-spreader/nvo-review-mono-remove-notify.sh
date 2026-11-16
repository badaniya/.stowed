#!/usr/bin/env bash
set -euo pipefail
scripts=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec python3 "$scripts/herdr-action-errors.py" run \
  --name 'Destroy sandbox & remove workspace: NVO-REVIEW (mono)' -- \
  bash "$scripts/nvo-review-mono-remove.sh" "$@"
