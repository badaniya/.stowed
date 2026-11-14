#!/usr/bin/env bash
# cloud-testbed-cit.sh — herdr workspace for cit cloud testbed
# Converted from ~/.private-cloud-testbed-cit.yml
set -euo pipefail

pane_id() { python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])"; }

echo "Creating Cloud-Testbed-cit workspace..."

WS_JSON=$(herdr workspace create --cwd "$HOME/workspace/badaniya" --label Cloud-Testbed-cit --focus)
WS_ID=$(echo "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['workspace']['workspace_id'])")
P1=$(echo    "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
T1=$(echo    "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['tab']['tab_id'])")
herdr tab rename "$T1" "1 - cit-console" > /dev/null

# ── 1 - cit-console (GDC) ──
T1_R=$(herdr pane split "$P1" --direction right --ratio 0.45 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
herdr pane run "$P1" "ssh_nvo_cloud_testbed cit -t 'TERM=xterm-256color sudo -i k9s'"
herdr pane run "$T1_R" "ssh_nvo_cloud_testbed cit -t 'TERM=xterm-256color sudo -i'"

# ── 2 - cit-us0-console (GDC) ──
T2_ROOT=$(herdr tab create --workspace "$WS_ID" --label "2 - cit-us0-console" --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
T2_R=$(herdr pane split "$T2_ROOT" --direction right --ratio 0.45 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
herdr pane run "$T2_ROOT" "ssh_nvo_cloud_testbed cit-us0 -t 'TERM=xterm-256color sudo -i watch \"kubectl -n common get pods\\; kubectl -n cit-us0 get pods\"'"
herdr pane run "$T2_R" "ssh_nvo_cloud_testbed cit-us0 -t 'TERM=xterm-256color sudo -i'"

# ── 3 - citr1-console (RDC) ──
T3_ROOT=$(herdr tab create --workspace "$WS_ID" --label "3 - citr1-console" --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
T3_R=$(herdr pane split "$T3_ROOT" --direction right --ratio 0.45 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T3_R2=$(herdr pane split "$T3_R" --direction down --ratio 0.25 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T3_R3=$(herdr pane split "$T3_R2" --direction down --ratio 0.33 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T3_R4=$(herdr pane split "$T3_R3" --direction down --ratio 0.5 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
herdr pane run "$T3_ROOT" "ssh_nvo_cloud_testbed citr1 -t 'TERM=xterm-256color sudo -i k9s'"
herdr pane run "$T3_R" "ssh_nvo_cloud_testbed citr1 -t 'TERM=xterm-256color sudo -i'"
herdr pane run "$T3_R2" "ssh_nvo_cloud_testbed citr1 -t 'TERM=xterm-256color sudo -i'"
herdr pane run "$T3_R3" "ssh_nvo_cloud_testbed citr1 -t 'TERM=xterm-256color sudo -i psql -h aurora-citr1.cluster-cbayk0yeyfjc.us-east-2.rds.amazonaws.com -U nvouser nvo_db -P pager=off'"
herdr pane run "$T3_R4" "ssh_nvo_cloud_testbed citr1 -t 'TERM=xterm-256color sudo -i PGPASSWORD=aerohive psql -h aurora-citr1.cluster-cbayk0yeyfjc.us-east-2.rds.amazonaws.com -U postgres platform_common_db -P pager=off'"

# ── 4 - citr2-console (RDC) ──
T4_ROOT=$(herdr tab create --workspace "$WS_ID" --label "4 - citr2-console" --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
T4_R=$(herdr pane split "$T4_ROOT" --direction right --ratio 0.45 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T4_R2=$(herdr pane split "$T4_R" --direction down --ratio 0.25 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T4_R3=$(herdr pane split "$T4_R2" --direction down --ratio 0.33 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T4_R4=$(herdr pane split "$T4_R3" --direction down --ratio 0.5 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
herdr pane run "$T4_ROOT" "ssh_nvo_cloud_testbed citr2 -t 'TERM=xterm-256color sudo -i k9s'"
herdr pane run "$T4_R" "ssh_nvo_cloud_testbed citr2 -t 'TERM=xterm-256color sudo -i'"
herdr pane run "$T4_R2" "ssh_nvo_cloud_testbed citr2 -t 'TERM=xterm-256color sudo -i'"
herdr pane run "$T4_R3" "ssh_nvo_cloud_testbed citr2 -t 'TERM=xterm-256color sudo -i psql -h aurora-citr2.cluster-cbayk0yeyfjc.us-east-2.rds.amazonaws.com -U nvouser nvo_db -P pager=off'"
herdr pane run "$T4_R4" "ssh_nvo_cloud_testbed citr2 -t 'TERM=xterm-256color sudo -i PGPASSWORD=aerohive psql -h aurora-citr2.cluster-cbayk0yeyfjc.us-east-2.rds.amazonaws.com -U postgres platform_common_db -P pager=off'"

echo "✅ Cloud-Testbed-cit ready (workspace $WS_ID)"
