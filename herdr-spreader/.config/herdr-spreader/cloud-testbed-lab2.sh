#!/usr/bin/env bash
# cloud-testbed-lab2.sh — herdr workspace for lab2 cloud testbed
# Converted from ~/.private-cloud-testbed-lab2.yml
set -euo pipefail

pane_id() { python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])"; }

echo "Creating Cloud-Testbed-lab2 workspace..."

WS_JSON=$(herdr workspace create --cwd "$HOME/workspace/badaniya" --label Cloud-Testbed-lab2 --focus)
WS_ID=$(echo "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['workspace']['workspace_id'])")
P1=$(echo    "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
T1=$(echo    "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['tab']['tab_id'])")
herdr tab rename "$T1" "1 - lab2-console" > /dev/null

# ── 1 - lab2-console (GDC) ──
T1_R=$(herdr pane split "$P1" --direction right --ratio 0.45 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
herdr pane run "$P1" "ssh_nvo_cloud_testbed lab2 -t 'TERM=xterm-256color sudo -i watch \"kubectl -n commongdc get pods\\; kubectl -n gdc get pods\"'"
herdr pane run "$T1_R" "ssh_nvo_cloud_testbed lab2 -t 'TERM=xterm-256color sudo -i'"

echo "✅ Cloud-Testbed-lab2 ready (workspace $WS_ID)"
