#!/usr/bin/env bash
# cloud-testbed-st2.sh — herdr workspace for st2 cloud testbed
# Converted from ~/.private-cloud-testbed-st2.yml
set -euo pipefail

pane_id() { python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])"; }

echo "Creating Cloud-Testbed-st2 workspace..."

WS_JSON=$(herdr workspace create --cwd "$HOME/workspace/badaniya" --label Cloud-Testbed-st2 --focus)
WS_ID=$(echo "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['workspace']['workspace_id'])")
P1=$(echo    "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
T1=$(echo    "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['tab']['tab_id'])")
herdr tab rename "$T1" "1 - st2-us-console" > /dev/null

# ── 1 - st2-us-console (GDC) ──
T1_R=$(herdr pane split "$P1" --direction right --ratio 0.45 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
herdr pane run "$P1" "ssh_nvo_cloud_testbed st2-us -t 'TERM=xterm-256color sudo -i k9s'"
herdr pane run "$T1_R" "ssh_nvo_cloud_testbed st2-us -t 'TERM=xterm-256color sudo -i'"

# ── 2 - st2-eu-console (GDC) ──
T2_ROOT=$(herdr tab create --workspace "$WS_ID" --label "2 - st2-eu-console" --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
T2_R=$(herdr pane split "$T2_ROOT" --direction right --ratio 0.45 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
herdr pane run "$T2_ROOT" "ssh_nvo_cloud_testbed st2-eu -t 'TERM=xterm-256color sudo -i k9s'"
herdr pane run "$T2_R" "ssh_nvo_cloud_testbed st2-eu -t 'TERM=xterm-256color sudo -i'"

# ── 3 - st2r1-console (RDC) ──
T3_ROOT=$(herdr tab create --workspace "$WS_ID" --label "3 - st2r1-console" --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
T3_R=$(herdr pane split "$T3_ROOT" --direction right --ratio 0.45 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T3_R2=$(herdr pane split "$T3_R" --direction down --ratio 0.25 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T3_R3=$(herdr pane split "$T3_R2" --direction down --ratio 0.33 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T3_R4=$(herdr pane split "$T3_R3" --direction down --ratio 0.5 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
herdr pane run "$T3_ROOT" "ssh_nvo_cloud_testbed st2r1 -t 'TERM=xterm-256color sudo -i k9s'"
herdr pane run "$T3_R" "ssh_nvo_cloud_testbed st2r1 -t 'TERM=xterm-256color sudo -i'"
herdr pane run "$T3_R2" "ssh_nvo_cloud_testbed st2r1 -t 'TERM=xterm-256color sudo -i'"
herdr pane run "$T3_R3" "ssh_nvo_cloud_testbed st2r1 -t 'TERM=xterm-256color sudo -i kubectl -n nvo exec -it postgresql-ha-postgresql-0 -- /bin/bash -c \\\"PGPASSWORD=aerohive123 psql -U nvouser nvo_db -P pager=off\\\"'"
herdr pane run "$T3_R4" "ssh_nvo_cloud_testbed st2r1 -t 'TERM=xterm-256color sudo -i PGPASSWORD=aerohive psql -h aurora-st2r1.cluster-crg8mk08o8lx.us-west-2.rds.amazonaws.com -U postgres platform_common_db -P pager=off'"

# ── 4 - st2r2-console (RDC) ──
T4_ROOT=$(herdr tab create --workspace "$WS_ID" --label "4 - st2r2-console" --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
T4_R=$(herdr pane split "$T4_ROOT" --direction right --ratio 0.45 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T4_R2=$(herdr pane split "$T4_R" --direction down --ratio 0.25 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T4_R3=$(herdr pane split "$T4_R2" --direction down --ratio 0.33 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T4_R4=$(herdr pane split "$T4_R3" --direction down --ratio 0.5 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
herdr pane run "$T4_ROOT" "ssh_nvo_cloud_testbed st2r2 -t 'TERM=xterm-256color sudo -i k9s'"
herdr pane run "$T4_R" "ssh_nvo_cloud_testbed st2r2 -t 'TERM=xterm-256color sudo -i'"
herdr pane run "$T4_R2" "ssh_nvo_cloud_testbed st2r2 -t 'TERM=xterm-256color sudo -i'"
herdr pane run "$T4_R3" "ssh_nvo_cloud_testbed st2r2 -t 'TERM=xterm-256color sudo -i kubectl -n nvo exec -it postgresql-ha-postgresql-0 -- /bin/bash -c \\\"PGPASSWORD=aerohive123 psql -U nvouser nvo_db -P pager=off\\\"'"
herdr pane run "$T4_R4" "ssh_nvo_cloud_testbed st2r2 -t 'TERM=xterm-256color sudo -i PGPASSWORD=aerohive psql -h aurora-st2r2.cluster-cb0s8ose8cyx.us-east-2.rds.amazonaws.com -U postgres platform_common_db -P pager=off'"

echo "✅ Cloud-Testbed-st2 ready (workspace $WS_ID)"
