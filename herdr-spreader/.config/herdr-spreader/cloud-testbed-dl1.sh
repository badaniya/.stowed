#!/usr/bin/env bash
# cloud-testbed-dl1.sh — herdr workspace for dl1 cloud testbed
# Converted from ~/.private-cloud-testbed-dl1.yml
set -euo pipefail

pane_id() { python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])"; }

echo "Creating Cloud-Testbed-dl1 workspace..."

WS_JSON=$(herdr workspace create --cwd "$HOME/workspace/badaniya" --label Cloud-Testbed-dl1 --focus)
WS_ID=$(echo "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['workspace']['workspace_id'])")
P1=$(echo    "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
T1=$(echo    "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['tab']['tab_id'])")
herdr tab rename "$T1" "1 - g1-console" > /dev/null

# ── 1 - g1-console ───────────────────────────────────────────────────
T1_R=$(herdr pane split "$P1" --direction right --ratio 0.45 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
herdr pane run "$P1"   "ssh_nvo_cloud_testbed dl1 -t 'TERM=xterm-256color sudo -i watch \"kubectl -n commongdc get pods\\; kubectl -n gdc get pods\"'"
herdr pane run "$T1_R" "ssh_nvo_cloud_testbed dl1 -t 'TERM=xterm-256color sudo -i'"

# ── 2 - r1-console ──────────────────────────────────────────────────────
T2_ROOT=$(herdr tab create --workspace "$WS_ID" --label "2 - r1-console" --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
T2_R=$(  herdr pane split "$T2_ROOT" --direction right --ratio 0.45 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T2_R2=$( herdr pane split "$T2_R"    --direction down  --ratio 0.25 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T2_R3=$( herdr pane split "$T2_R2"   --direction down  --ratio 0.33 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T2_R4=$( herdr pane split "$T2_R3"   --direction down  --ratio 0.5  --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
herdr pane run "$T2_ROOT" "ssh_nvo_cloud_testbed dl1r1 -t 'TERM=xterm-256color sudo -i watch \"kubectl -n nvo get pods\\; kubectl -n nvo top pods\"'"
herdr pane run "$T2_R"   "ssh_nvo_cloud_testbed dl1r1 -t 'TERM=xterm-256color sudo -i'"
herdr pane run "$T2_R2"  "ssh_nvo_cloud_testbed dl1r1 -t 'TERM=xterm-256color sudo -i'"
herdr pane run "$T2_R3"  "ssh_nvo_cloud_testbed dl1r1 -t 'TERM=xterm-256color sudo -i psql -h aurora-dl1r1.cluster-ciwa6umsjipp.us-east-2.rds.amazonaws.com -U nvouser nvo_db -P pager=off'"
herdr pane run "$T2_R4"  "ssh_nvo_cloud_testbed dl1r1 -t 'TERM=xterm-256color sudo -i PGPASSWORD=aerohive psql -h aurora-dl1r1.cluster-ciwa6umsjipp.us-east-2.rds.amazonaws.com -U postgres platform_common_db -P pager=off'"


echo "✅ Cloud-Testbed-dl1 ready (workspace $WS_ID)"
