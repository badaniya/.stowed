#!/usr/bin/env bash
# cloud-testbed-dl2-kafka-lag.sh — herdr workspace for dl2 kafka lag monitoring
# Converted from ~/.private-cloud-testbed-dl2-kafka-lag.yml
set -euo pipefail

pane_id() { python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])"; }

echo "Creating Cloud-Testbed-dl2-kafka-lag workspace..."

WS_JSON=$(herdr workspace create --cwd "$HOME/workspace/badaniya" --label Cloud-Testbed-dl2-kafka-lag --focus)
WS_ID=$(echo "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['workspace']['workspace_id'])")
P1=$(echo    "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
T1=$(echo    "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['tab']['tab_id'])")
herdr tab rename "$T1" "1 - g1-console" > /dev/null

# ── 1 - g1-console ───────────────────────────────────────────────────
T1_R=$(herdr pane split "$P1" --direction right --ratio 0.45 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
herdr pane run "$P1"   "ssh_nvo_cloud_testbed dl2 -t 'TERM=xterm-256color sudo -i watch \"kubectl -n commongdc get pods\\; kubectl -n gdc get pods\"'"
herdr pane run "$T1_R" "ssh_nvo_cloud_testbed dl2 -t 'TERM=xterm-256color sudo -i'"

# ── 2 - r1-console (kafka lag) ────────────────────────────────────────
T2_ROOT=$(herdr tab create --workspace "$WS_ID" --label "2 - r1-console" --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
T2_R=$(  herdr pane split "$T2_ROOT" --direction right --ratio 0.45 --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
T2_R2=$( herdr pane split "$T2_R"    --direction down  --ratio 0.5  --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
herdr pane run "$T2_ROOT" "ssh_nvo_cloud_testbed dl2r1 -t 'TERM=xterm-256color sudo -i watch \"kubectl -n nvo get pods\\; kubectl -n nvo top pods\"'"
herdr pane run "$T2_R"   "ssh_nvo_cloud_testbed dl2r1 -t 'TERM=xterm-256color sudo -i watch \"kubectl -n common exec -it common-kafka-0 -- /bin/bash -c \\\"unset JMX_PORT; /opt/bitnami/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --group network\\\"\"'"
herdr pane run "$T2_R2"  "ssh_nvo_cloud_testbed dl2r1 -t 'TERM=xterm-256color sudo -i watch \"kubectl -n nvo exec -it nvo-kafka-0 -- /bin/bash -c \\\"unset JMX_PORT; /opt/bitnami/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --group network | grep -e TOPIC -e NVOAPP_DEVICE_ONBOARD\\\"\"'"

echo "✅ Cloud-Testbed-dl2-kafka-lag ready (workspace $WS_ID)"
