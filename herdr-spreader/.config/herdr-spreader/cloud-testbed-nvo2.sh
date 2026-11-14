#!/usr/bin/env bash
# cloud-testbed-nvo2.sh — herdr workspace for nvo2 cloud testbed (single console)
# Converted from ~/.private-cloud-testbed-nvo2.yml
set -euo pipefail

pane_id() { python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])"; }

echo "Creating Cloud-Testbed-nvo2 workspace..."

WS_JSON=$(herdr workspace create --cwd "$HOME/workspace/badaniya" --label Cloud-Testbed-nvo2 --focus)
WS_ID=$(echo "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['workspace']['workspace_id'])")
P1=$(echo    "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
T1=$(echo    "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['tab']['tab_id'])")
herdr tab rename "$T1" "1 - console" > /dev/null

P_R=$(  herdr pane split "$P1"   --direction right --ratio 0.41 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
P_R2=$( herdr pane split "$P_R"  --direction down  --ratio 0.25 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
P_R3=$( herdr pane split "$P_R2" --direction down  --ratio 0.33 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
P_R4=$( herdr pane split "$P_R3" --direction down  --ratio 0.5  --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")

herdr pane run "$P1"   "ssh_nvo_cloud_testbed nvo2 -t 'TERM=xterm-256color sudo -i k9s'"
herdr pane run "$P_R"  "ssh_nvo_cloud_testbed nvo2 -t 'TERM=xterm-256color sudo -i'"
herdr pane run "$P_R2" "ssh_nvo_cloud_testbed nvo2 -t 'TERM=xterm-256color sudo -i'"
herdr pane run "$P_R3" "ssh_nvo_cloud_testbed nvo2 -t 'TERM=xterm-256color sudo -i kubectl -n nvo exec -it postgresql-ha-postgresql-0 -- /bin/bash -c \\\"PGPASSWORD=aerohive123 psql -U nvouser nvo_db -P pager=off\\\"'"
herdr pane run "$P_R4" "ssh_nvo_cloud_testbed nvo2 -t 'TERM=xterm-256color sudo -i PGPASSWORD=aerohive psql -h aurora-nvo2.cluster-cl8aa20q00k0.us-east-2.rds.amazonaws.com -U postgres platform_common_db -P pager=off'"

echo "✅ Cloud-Testbed-nvo2 ready (workspace $WS_ID)"
