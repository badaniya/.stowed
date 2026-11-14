#!/usr/bin/env bash
# cloud-testbed-st3.sh — herdr workspace for st3 cloud testbed
# Converted from ~/.private-cloud-testbed-st3.yml
set -euo pipefail

pane_id() { python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])"; }

echo "Creating Cloud-Testbed-st3 workspace..."

WS_JSON=$(herdr workspace create --cwd "$HOME/workspace/badaniya" --label Cloud-Testbed-st3 --focus)
WS_ID=$(echo "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['workspace']['workspace_id'])")
P1=$(echo    "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
T1=$(echo    "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['tab']['tab_id'])")
herdr tab rename "$T1" "1 - st3-us-console" > /dev/null

# ── 1 - st3-us-console (GDC) ──
T1_R=$(herdr pane split "$P1" --direction right --ratio 0.45 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
herdr pane run "$P1" "ssh_nvo_cloud_testbed st3-us -t 'TERM=xterm-256color sudo -i k9s'"
herdr pane run "$T1_R" "ssh_nvo_cloud_testbed st3-us -t 'TERM=xterm-256color sudo -i'"

# ── 2 - st3-eu-console (GDC) ──
T2_ROOT=$(herdr tab create --workspace "$WS_ID" --label "2 - st3-eu-console" --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
T2_R=$(herdr pane split "$T2_ROOT" --direction right --ratio 0.45 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
herdr pane run "$T2_ROOT" "ssh_nvo_cloud_testbed st3-eu -t 'TERM=xterm-256color sudo -i k9s'"
herdr pane run "$T2_R" "ssh_nvo_cloud_testbed st3-eu -t 'TERM=xterm-256color sudo -i'"

# ── 3 - st3r1-console (RDC) ──
T3_ROOT=$(herdr tab create --workspace "$WS_ID" --label "3 - st3r1-console" --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
T3_R=$(herdr pane split "$T3_ROOT" --direction right --ratio 0.45 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T3_R2=$(herdr pane split "$T3_R" --direction down --ratio 0.25 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T3_R3=$(herdr pane split "$T3_R2" --direction down --ratio 0.33 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T3_R4=$(herdr pane split "$T3_R3" --direction down --ratio 0.5 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
herdr pane run "$T3_ROOT" "ssh_nvo_cloud_testbed st3r1 -t 'TERM=xterm-256color sudo -i k9s'"
herdr pane run "$T3_R" "ssh_nvo_cloud_testbed st3r1 -t 'TERM=xterm-256color sudo -i'"
herdr pane run "$T3_R2" "ssh_nvo_cloud_testbed st3r1 -t 'TERM=xterm-256color sudo -i'"
herdr pane run "$T3_R3" "ssh_nvo_cloud_testbed st3r1 -t 'TERM=xterm-256color sudo -i kubectl -n nvo exec -it postgresql-ha-postgresql-0 -- /bin/bash -c \\\"PGPASSWORD=aerohive123 psql -U nvouser nvo_db -P pager=off\\\"'"
herdr pane run "$T3_R4" "ssh_nvo_cloud_testbed st3r1 -t 'TERM=xterm-256color sudo -i PGPASSWORD=aerohive psql -h aurora-st3r1.cluster-cdo6qi48mmok.eu-west-1.rds.amazonaws.com -U postgres platform_common_db -P pager=off'"

# ── 4 - st3r2-console (RDC) ──
T4_ROOT=$(herdr tab create --workspace "$WS_ID" --label "4 - st3r2-console" --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
T4_R=$(herdr pane split "$T4_ROOT" --direction right --ratio 0.45 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T4_R2=$(herdr pane split "$T4_R" --direction down --ratio 0.25 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T4_R3=$(herdr pane split "$T4_R2" --direction down --ratio 0.33 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T4_R4=$(herdr pane split "$T4_R3" --direction down --ratio 0.5 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
herdr pane run "$T4_ROOT" "ssh_nvo_cloud_testbed st3r2 -t 'TERM=xterm-256color sudo -i k9s'"
herdr pane run "$T4_R" "ssh_nvo_cloud_testbed st3r2 -t 'TERM=xterm-256color sudo -i'"
herdr pane run "$T4_R2" "ssh_nvo_cloud_testbed st3r2 -t 'TERM=xterm-256color sudo -i'"
herdr pane run "$T4_R3" "ssh_nvo_cloud_testbed st3r2 -t 'TERM=xterm-256color sudo -i kubectl -n nvo exec -it postgresql-ha-postgresql-0 -- /bin/bash -c \\\"PGPASSWORD=aerohive123 psql -U nvouser nvo_db -P pager=off\\\"'"
herdr pane run "$T4_R4" "ssh_nvo_cloud_testbed st3r2 -t 'TERM=xterm-256color sudo -i PGPASSWORD=aerohive psql -h aurora-st3r2.cluster-cb0s8ose8cyx.us-east-2.rds.amazonaws.com -U postgres platform_common_db -P pager=off'"

# ── 5 - st3r3-console (RDC) ──
T5_ROOT=$(herdr tab create --workspace "$WS_ID" --label "5 - st3r3-console" --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
T5_R=$(herdr pane split "$T5_ROOT" --direction right --ratio 0.45 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T5_R2=$(herdr pane split "$T5_R" --direction down --ratio 0.25 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T5_R3=$(herdr pane split "$T5_R2" --direction down --ratio 0.33 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T5_R4=$(herdr pane split "$T5_R3" --direction down --ratio 0.5 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
herdr pane run "$T5_ROOT" "ssh_nvo_cloud_testbed st3r3 -t 'TERM=xterm-256color sudo -i watch \"kubectl -n nvo get pods\\; kubectl -n nvo top pods\"'"
herdr pane run "$T5_R" "ssh_nvo_cloud_testbed st3r3 -t 'TERM=xterm-256color sudo -i'"
herdr pane run "$T5_R2" "ssh_nvo_cloud_testbed st3r3 -t 'TERM=xterm-256color sudo -i'"
herdr pane run "$T5_R3" "ssh_nvo_cloud_testbed st3r3 -t 'TERM=xterm-256color sudo -i kubectl -n nvo exec -it postgresql-ha-postgresql-0 -- /bin/bash -c \\\"PGPASSWORD=aerohive123 psql -U nvouser nvo_db -P pager=off\\\"'"
herdr pane run "$T5_R4" "ssh_nvo_cloud_testbed st3r3 -t 'TERM=xterm-256color sudo -i PGPASSWORD=aerohive psql -h aurora-st3r3.cluster-cb0s8ose8cyx.us-east-2.rds.amazonaws.com -U postgres platform_common_db -P pager=off'"

# ── 6 - st3r4-console (RDC) ──
T6_ROOT=$(herdr tab create --workspace "$WS_ID" --label "6 - st3r4-console" --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
T6_R=$(herdr pane split "$T6_ROOT" --direction right --ratio 0.45 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T6_R2=$(herdr pane split "$T6_R" --direction down --ratio 0.25 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T6_R3=$(herdr pane split "$T6_R2" --direction down --ratio 0.33 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T6_R4=$(herdr pane split "$T6_R3" --direction down --ratio 0.5 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
herdr pane run "$T6_ROOT" "ssh_nvo_cloud_testbed st3r4 -t 'TERM=xterm-256color sudo -i watch \"kubectl -n nvo get pods\\; kubectl -n nvo top pods\"'"
herdr pane run "$T6_R" "ssh_nvo_cloud_testbed st3r4 -t 'TERM=xterm-256color sudo -i'"
herdr pane run "$T6_R2" "ssh_nvo_cloud_testbed st3r4 -t 'TERM=xterm-256color sudo -i'"
herdr pane run "$T6_R3" "ssh_nvo_cloud_testbed st3r4 -t 'TERM=xterm-256color sudo -i kubectl -n nvo exec -it postgresql-ha-postgresql-0 -- /bin/bash -c \\\"PGPASSWORD=aerohive123 psql -U nvouser nvo_db -P pager=off\\\"'"
herdr pane run "$T6_R4" "ssh_nvo_cloud_testbed st3r4 -t 'TERM=xterm-256color sudo -i PGPASSWORD=aerohive psql -h aurora-st3r4.cluster-cb0s8ose8cyx.us-east-2.rds.amazonaws.com -U postgres platform_common_db -P pager=off'"

echo "✅ Cloud-Testbed-st3 ready (workspace $WS_ID)"
