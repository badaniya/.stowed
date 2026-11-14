#!/usr/bin/env bash
# rack2-topology.sh — declarative herdr workspace for Salem FO Test Bed
# Self-contained: no dependency on rack2-connect.sh or any skill script.
#
# Usage: bash ~/.config/herdr-spreader/rack2-topology.sh

set -euo pipefail

# ── Inline device registry ────────────────────────────────────────────
TERMINAL_SERVER="10.139.38.4"
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5 \
  -o PreferredAuthentications=password -o PubkeyAuthentication=no \
  -o KexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 \
  -o HostKeyAlgorithms=+ssh-rsa \
  -o Ciphers=+aes128-cbc,aes256-cbc,3des-cbc"

# format: "IP:CONSOLE_PORT:USER:PASS"  (blank pass = empty string)
declare -A DEVICE
DEVICE[5301]="10.139.38.43:5025:rwa:rwa"
DEVICE[5401]="10.139.38.49:5026:rwa:rwa"
DEVICE[5402]="10.139.38.50:5027:rwa:rwa"
DEVICE[5701]="10.139.38.47:5028:rwa:rwa"
DEVICE[5702]="10.139.38.48:5032:rwa:rwa"
DEVICE[5529]="10.139.38.51:5012:rwa:rwa"
DEVICE[5530]="10.139.38.52:5024:rwa:rwa"
DEVICE[7413]="10.139.38.45:5029:rwa:rwa"
DEVICE[7414]="10.139.38.46:5030:rwa:rwa"
DEVICE[4908]="10.139.38.30:5023:rwa:rwa"
DEVICE[5302]="10.139.38.44:5031:admin:"
DEVICE[5405]="10.139.38.55:5044:admin:"
DEVICE[5406]="10.139.38.56:5046:admin:"
DEVICE[5407]="10.139.38.58:5048:admin:"
DEVICE[NVO-2-310-1]="10.139.38.190:5002:admin:abc123"
DEVICE[NVO-2-410-1]="10.139.38.189:5003:admin:abc123"
DEVICE[NVO-2-510-1]="10.139.38.191:5004:admin:aerohive123"
DEVICE[NVO-2-510-2]="10.139.38.192:5005:admin:aerohive123"

# ── Helpers ───────────────────────────────────────────────────────────
pane_id() { python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])"; }

# Build the per-pane shell command: SSH first, telnet console on failure
device_cmd() {
  local dev="$1"
  local entry="${DEVICE[$dev]}"
  local ip port user pass
  IFS=: read -r ip port user pass <<<"$entry"
  cat <<CMD
echo 'Connecting to $dev ($ip)...'
sshpass -p '$pass' ssh $SSH_OPTS $user@$ip 2>/dev/null || {
  echo 'SSH failed, trying console...'
  telnet $TERMINAL_SERVER $port
}
CMD
}

# Rename pane then launch its device connection
connect() {
  local pane="$1" label="$2" dev="$3"
  herdr pane rename "$pane" "$label"
  herdr pane run "$pane" "$(device_cmd "$dev")"
}

# ── Create workspace + 3 tabs ─────────────────────────────────────────
echo "Creating Rack2-Topology workspace..."

WS_JSON=$(herdr workspace create --cwd "$HOME/workspace/badaniya" --label Rack2-Topology --focus)
WS_ID=$(echo "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['workspace']['workspace_id'])")
VOSS=$(echo "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
VOSS_TAB=$(echo "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['tab']['tab_id'])")
herdr tab rename "$VOSS_TAB" "1 - VOSS" >/dev/null

EXOS_ROOT=$(herdr tab create --workspace "$WS_ID" --label "2 - EXOS" --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
APS_ROOT=$(herdr tab create --workspace "$WS_ID" --label "3 - APs" --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")

# ── VOSS: 3×3 grid + 1 full-width bottom row ─────────────────────────
#
#  ┌──────────┬──────────┬──────────┐
#  │  5301    │  5401    │  5402    │  row 1
#  ├──────────┼──────────┼──────────┤
#  │  5701    │  5702    │  5529    │  row 2
#  ├──────────┼──────────┼──────────┤
#  │  5530    │  7413    │  7414    │  row 3
#  ├──────────┴──────────┴──────────┤
#  │            4908                │  row 4  (full width)
#  └────────────────────────────────┘
#
# Build: reserve row 4 → 3 equal columns → 3 equal rows per column

ROW4=$(herdr pane split "$VOSS" --direction down --ratio 0.75 --no-focus | pane_id)
COL2=$(herdr pane split "$VOSS" --direction right --ratio 0.33 --no-focus | pane_id)
COL3=$(herdr pane split "$COL2" --direction right --ratio 0.5 --no-focus | pane_id)

C1R2=$(herdr pane split "$VOSS" --direction down --ratio 0.33 --no-focus | pane_id)
C1R3=$(herdr pane split "$C1R2" --direction down --ratio 0.5 --no-focus | pane_id)
C2R2=$(herdr pane split "$COL2" --direction down --ratio 0.33 --no-focus | pane_id)
C2R3=$(herdr pane split "$C2R2" --direction down --ratio 0.5 --no-focus | pane_id)
C3R2=$(herdr pane split "$COL3" --direction down --ratio 0.33 --no-focus | pane_id)
C3R3=$(herdr pane split "$C3R2" --direction down --ratio 0.5 --no-focus | pane_id)

connect "$VOSS" "5301 - TB012301K-H0087 - 10.139.38.43" 5301
connect "$COL2" "5401 - JA012302G-00272 - 10.139.38.49" 5401
connect "$COL3" "5402 - JA012301G-00047 - 10.139.38.50" 5402
connect "$C1R2" "5701 - AR022302Q-40002 - 10.139.38.47" 5701
connect "$C2R2" "5702 - AR022302Q-40016 - 10.139.38.48" 5702
connect "$C3R2" "5529 - SB032050G-00050 - 10.139.38.51" 5529
connect "$C1R3" "5530 - SB022248G-00068 - 10.139.38.52" 5530
connect "$C2R3" "7413 - 2306Q-40144 - 10.139.38.45" 7413
connect "$C3R3" "7414 - 2306Q-40050 - 10.139.38.46" 7414
connect "$ROW4" "4908 - 2042F-20961 - 10.139.38.30" 4908

# ── EXOS: 2×2 grid ───────────────────────────────────────────────────
#  ┌──────────┬──────────┐
#  │  5302    │  5405    │
#  ├──────────┼──────────┤
#  │  5406    │  5407    │
#  └──────────┴──────────┘
EXOS_TR=$(herdr pane split "$EXOS_ROOT" --direction right --ratio 0.5 --no-focus | pane_id)
EXOS_BL=$(herdr pane split "$EXOS_ROOT" --direction down --ratio 0.5 --no-focus | pane_id)
EXOS_BR=$(herdr pane split "$EXOS_TR" --direction down --ratio 0.5 --no-focus | pane_id)

connect "$EXOS_ROOT" "5302 - TB012301K-H0697 - 10.139.38.44" 5302
connect "$EXOS_TR" "5405 - JA062301G-00343 - 10.139.38.55" 5405
connect "$EXOS_BL" "5406 - JA062301G-00337 - 10.139.38.56" 5406
connect "$EXOS_BR" "5407 - JA062301G-00314 - 10.139.38.58" 5407

# ── APs: 2×2 grid ────────────────────────────────────────────────────
#  ┌──────────────┬──────────────┐
#  │ NVO-2-310-1  │ NVO-2-410-1  │
#  ├──────────────┼──────────────┤
#  │ NVO-2-510-1  │ NVO-2-510-2  │
#  └──────────────┴──────────────┘
# Note: APs are DHCP — check IQC at https://10.139.147.47:5825 (admin/abc123) if SSH fails
APS_TR=$(herdr pane split "$APS_ROOT" --direction right --ratio 0.5 --no-focus | pane_id)
APS_BL=$(herdr pane split "$APS_ROOT" --direction down --ratio 0.5 --no-focus | pane_id)
APS_BR=$(herdr pane split "$APS_TR" --direction down --ratio 0.5 --no-focus | pane_id)

connect "$APS_ROOT" "NVO-2-310-1 - 2148Y-1145900000 - 10.139.38.190" NVO-2-310-1
connect "$APS_TR" "NVO-2-410-1 - 2145Y-1087800000 - 10.139.38.189" NVO-2-410-1
connect "$APS_BL" "NVO-2-510-1 - 2149W-2048200000 - 10.139.38.191" NVO-2-510-1
connect "$APS_BR" "NVO-2-510-2 - 2149W-2047500000 - 10.139.38.192" NVO-2-510-2

echo "✅ rack2-topology ready (workspace $WS_ID) — switch to it in herdr"
