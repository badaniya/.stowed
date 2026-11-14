#!/usr/bin/env bash
# cloud-testbed-xcp7.sh — herdr workspace for xcp7 cloud testbed
# Converted from ~/.private-cloud-testbed-xcp7.yml
set -euo pipefail

pane_id() { python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])"; }

echo "Creating Cloud-Testbed-xcp7 workspace..."

WS_JSON=$(herdr workspace create --cwd "$HOME/workspace/badaniya" --label Cloud-Testbed-xcp7 --focus)
WS_ID=$(echo "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['workspace']['workspace_id'])")
P1=$(echo    "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
T1=$(echo    "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['tab']['tab_id'])")
herdr tab rename "$T1" "1 - xcp7-us-console" > /dev/null

# ── 1 - xcp7-us-console (GDC) ───────────────────────────────────────────────────
T1_R=$(herdr pane split "$P1" --direction right --ratio 0.45 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
herdr pane run "$P1"   "ssh_nvo_cloud_testbed xcp7-us -t 'TERM=xterm-256color sudo -i watch \"kubectl -n commongdc get pods\\; kubectl -n gdc get pods\"'"
herdr pane run "$T1_R" "ssh_nvo_cloud_testbed xcp7-us -t 'TERM=xterm-256color sudo -i'"

# ── 2 - xcp7-eu-console ───────────────────────────────────────────────────
T2_ROOT=$(herdr tab create --workspace "$WS_ID" --label "2 - xcp7-eu-console" --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
T2_R=$(herdr pane split "$T2_ROOT" --direction right --ratio 0.45 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
herdr pane run "$T2_ROOT"   "ssh_nvo_cloud_testbed xcp7-eu -t 'TERM=xterm-256color sudo -i watch \"kubectl -n commongdc get pods\\; kubectl -n gdc get pods\"'"
herdr pane run "$T2_R" "ssh_nvo_cloud_testbed xcp7-eu -t 'TERM=xterm-256color sudo -i'"

# ── 3 - xcp7r1-console ──────────────────────────────────────────────────────
T3_ROOT=$(herdr tab create --workspace "$WS_ID" --label "3 - xcp7r1-console" --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
T3_R=$(  herdr pane split "$T3_ROOT" --direction right --ratio 0.45 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T3_R2=$( herdr pane split "$T3_R"    --direction down  --ratio 0.25 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T3_R3=$( herdr pane split "$T3_R2"   --direction down  --ratio 0.33 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T3_R4=$( herdr pane split "$T3_R3"   --direction down  --ratio 0.5  --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
herdr pane run "$T3_ROOT" "ssh_nvo_cloud_testbed xcp7r1 -t 'TERM=xterm-256color sudo -i watch \"kubectl -n nvo get pods\\; kubectl -n nvo top pods\"'"
herdr pane run "$T3_R"   "ssh_nvo_cloud_testbed xcp7r1 -t 'TERM=xterm-256color sudo -i'"
herdr pane run "$T3_R2"  "ssh_nvo_cloud_testbed xcp7r1 -t 'TERM=xterm-256color sudo -i'"
herdr pane run "$T3_R3"  "ssh_nvo_cloud_testbed xcp7r1 -t 'TERM=xterm-256color sudo -i kubectl -n nvo exec -it postgresql-ha-postgresql-0 -- /bin/bash -c \\\"PGPASSWORD=aerohive123 psql -U nvouser nvo_db -P pager=off\\\"'"
herdr pane run "$T3_R4"  "ssh_nvo_cloud_testbed xcp7r1 -t 'TERM=xterm-256color sudo -i PGPASSWORD=aerohive psql -h aurora-xcp7r1.cluster-ch4ceyuoq7f4.eu-west-1.rds.amazonaws.com -U postgres platform_common_db -P pager=off'"

# ── 4 - xcp7r2-console ──────────────────────────────────────────────────────
T4_ROOT=$(herdr tab create --workspace "$WS_ID" --label "4 - xcp7r2-console" --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
T4_R=$(  herdr pane split "$T4_ROOT" --direction right --ratio 0.45 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T4_R2=$( herdr pane split "$T4_R"    --direction down  --ratio 0.25 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T4_R3=$( herdr pane split "$T4_R2"   --direction down  --ratio 0.33 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T4_R4=$( herdr pane split "$T4_R3"   --direction down  --ratio 0.5  --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
herdr pane run "$T4_ROOT" "ssh_nvo_cloud_testbed xcp7r2 -t 'TERM=xterm-256color sudo -i watch \"kubectl -n nvo get pods\\; kubectl -n nvo top pods\"'"
herdr pane run "$T4_R"   "ssh_nvo_cloud_testbed xcp7r2 -t 'TERM=xterm-256color sudo -i'"
herdr pane run "$T4_R2"  "ssh_nvo_cloud_testbed xcp7r2 -t 'TERM=xterm-256color sudo -i'"
herdr pane run "$T4_R3"  "ssh_nvo_cloud_testbed xcp7r2 -t 'TERM=xterm-256color sudo -i kubectl -n nvo exec -it postgresql-ha-postgresql-0 -- /bin/bash -c \\\"PGPASSWORD=aerohive123 psql -U nvouser nvo_db -P pager=off\\\"'"
herdr pane run "$T4_R4"  "ssh_nvo_cloud_testbed xcp7r2 -t 'TERM=xterm-256color sudo -i PGPASSWORD=aerohive psql -h aurora-xcp7r2.cluster-cl8aa20q00k0.us-east-2.rds.amazonaws.com -U postgres platform_common_db -P pager=off'"


echo "✅ Cloud-Testbed-xcp7 ready (workspace $WS_ID)"
