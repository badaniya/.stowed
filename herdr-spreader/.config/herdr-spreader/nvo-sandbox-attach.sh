#!/usr/bin/env bash
# Launch the Build-pane repair helper using the installed script location.
set -euo pipefail
exec python3 "$(dirname "${BASH_SOURCE[0]}")/nvo-sandbox-attach.py" "$@"
