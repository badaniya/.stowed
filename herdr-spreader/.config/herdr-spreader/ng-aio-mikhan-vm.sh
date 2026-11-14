#!/usr/bin/env bash
# ng-aio-mikhan-vm.sh — herdr workspace for mikhan-vm NG-AIO
# Converted from ~/.private-ng-aio-mikhan-vm.yml
#
# Usage: bash ~/.config/herdr-spreader/ng-aio-mikhan-vm.sh
set -euo pipefail

pane_id() { python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])"; }

echo "Creating NG-AIO-mikhan-vm workspace..."

WS_JSON=$(herdr workspace create --cwd "$HOME/workspace/badaniya" --label NG-AIO-mikhan-vm --focus)
WS_ID=$(echo "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['workspace']['workspace_id'])")
P1=$(echo    "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
T1=$(echo    "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['tab']['tab_id'])")
herdr tab rename "$T1" "1 - Console" > /dev/null

# ── 1 - console ───────────────────────────────────────────────────────
#  ┌────────────┬──────────────────────────────────────┐
#  │  left      │  shell                               │ ~25% h
#  │  (45% w    ├──────────────────────────────────────┤
#  │  full h)   │  shell                               │ ~25% h
#  │            ├──────────────────────────────────────┤
#  │            │  psql nvo_db                         │ ~25% h
#  │            ├──────────────────────────────────────┤
#  │            │  psql platform_common_db             │ ~25% h
#  └────────────┴──────────────────────────────────────┘
P_RIGHT=$(herdr pane split "$P1"      --direction right --ratio 0.45 --no-focus | pane_id)
P_R2=$(   herdr pane split "$P_RIGHT" --direction down  --ratio 0.25 --no-focus | pane_id)
P_R3=$(   herdr pane split "$P_R2"    --direction down  --ratio 0.33 --no-focus | pane_id)
P_R4=$(   herdr pane split "$P_R3"    --direction down  --ratio 0.5  --no-focus | pane_id)

NVO_DB_CMD='kubectl -n gdc exec -it gdc-postgresql-ha-postgresql-0 -- bash -c "export PGPASSWORD=aerohive; psql -h localhost -U postgres nvo_db -P pager=off"'
PCM_DB_CMD='kubectl -n xiq exec -it hm-postgresql-ha-postgresql-0 -- bash -c "export PGPASSWORD=aerohive; psql -h localhost -U postgres platform_common_db -P pager=off"'

herdr pane run "$P1"      "kube_ctx mikhan-vm; k9s"
herdr pane run "$P_RIGHT" "ngaio-mikhan-vm"
herdr pane run "$P_R2"    "ngaio-mikhan-vm"
herdr pane run "$P_R3"    "ngaio-mikhan-vm -t \'$NVO_DB_CMD\'"
herdr pane run "$P_R4"    "ngaio-mikhan-vm -t \'$PCM_DB_CMD\'"

echo "✅ NG-AIO-mikhan-vm ready (workspace $WS_ID)"
