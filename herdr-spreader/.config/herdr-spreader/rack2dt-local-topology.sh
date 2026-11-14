#!/usr/bin/env bash
# rack2dt-local-topology.sh — declarative herdr workspace for Rack2 Digital-Twin (GNS3, CI)
# via a LOCAL GNS3 server/tunnel (127.0.0.1), instead of the shared 10.64.192.11 host.
# Self-contained. Devices are GNS3-simulated QEMU nodes with serial consoles exposed as
# telnet ports on the GNS3 server host — connect via `telnet 127.0.0.1 <port>`,
# not SSH to a per-device management IP.
#
# GNS3 project (source of truth for node/console-port mapping):
#   http://127.0.0.1:3080/static/web-ui/server/1/project/bb77c165-10cc-455b-a808-b80da268961f
#   API: curl http://127.0.0.1:3080/v2/projects/bb77c165-10cc-455b-a808-b80da268961f/nodes
#
# NOTE: console ports queried from the local instance mostly match the remote
# (10.64.192.11) instance, EXCEPT EXOS-5405(Stack) is 5021 here vs 5070 remotely.
#
# EXOS-5703/5704/5705 are extra vs. the physical rack2 (which only has 5302/5405/5406/5407).
#
# Usage: bash ~/.config/herdr-spreader/rack2dt-local-topology.sh

set -euo pipefail

GNS3_HOST="127.0.0.1"

# format: "console_port"
declare -A DEVICE
DEVICE[VOSS-5301]="5073"
DEVICE[VOSS-5401]="5077"
DEVICE[VOSS-5402]="5075"
DEVICE[VOSS-5701]="5063"
DEVICE[VOSS-5702]="5067"
DEVICE[VOSS-5529]="5069"
DEVICE[VOSS-5530]="5071"
DEVICE[VOSS-7413]="5096"
DEVICE[VOSS-7414]="5100"
DEVICE[VOSS-4908]="5104"
DEVICE[EXOS-5302]="5079"
DEVICE[EXOS-5405-Stack]="5021"
DEVICE[EXOS-5703]="5088"
DEVICE[EXOS-5704]="5084"
DEVICE[EXOS-5705]="5092"
DEVICE[XIQEMU]="local" # not a GNS3 console — local shell, see xiqemu_cmd()

# ── Helpers ───────────────────────────────────────────────────────────
pane_id() { python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])"; }

# GNS3 console: plain telnet to the GNS3 server's per-node console port
console_cmd() {
  local dev="$1"
  local port="${DEVICE[$dev]}"
  cat <<CMD
echo 'Connecting to $dev (console telnet $GNS3_HOST:$port)...'
telnet $GNS3_HOST $port
CMD
}

# Queue of "pane|dev" entries needing a login pass — populated by connect(),
# drained once at the end by login_all().
# NOTE: entries are '|'-delimited, NOT ':' — herdr pane IDs are themselves of the
# form "<workspace>:<pane>" (e.g. "w92:p5"), so splitting on ':' truncated every
# pane id down to its bare workspace id, and under `set -e` the resulting
# "pane_not_found" on the very first real call silently killed the rest of the
# batch. That's why only one console (whichever tolerated the bad target) ever
# got its keystrokes.
#
# NOTE: this GNS3 telnet console is silent on connect — it prints nothing (no banner,
# no login prompt) until it receives a keypress, and there IS no real login/enable
# password on this simulated topology (VOSS drops straight to the "> " exec prompt).
# login_all() runs in strict BATCHED PHASES — the same step fired at every pane in a
# tight loop, then ONE shared sleep before the next phase — instead of doing full
# wait-output/read-detect per device, which serializes the whole thing back to one
# device at a time (that's what made it crawl before).
LOGIN_QUEUE=()

creds_for() {
  local dev="$1"
  if [[ "$dev" == VOSS-* ]]; then
    echo "rwa rwa"
  elif [[ "$dev" == EXOS-* ]]; then
    echo "admin ''"
  fi
}

login_all() {
  [[ ${#LOGIN_QUEUE[@]} -eq 0 ]] && return
  local entry pane dev user pass output
  declare -A NEEDS_LOGIN

  # Phase 1: wake up every console at once (nothing prints until a keypress).
  echo "Waking up ${#LOGIN_QUEUE[@]} consoles..."
  for entry in "${LOGIN_QUEUE[@]}"; do
    IFS='|' read -r pane dev <<<"$entry"
    herdr pane send-keys "$pane" enter || echo "WARN: wake-up failed for $dev ($pane)" >&2
  done
  sleep 1.5

  # Phase 1.5: only devices that actually show a login/username prompt get credentials —
  # this simulated topology mostly drops straight to the "> " exec prompt already
  # logged in, and blindly typing rwa/rwa there just produces "% Invalid input" noise.
  for entry in "${LOGIN_QUEUE[@]}"; do
    IFS='|' read -r pane dev <<<"$entry"
    output=$(herdr pane read "$pane" --source recent --lines 10 2>/dev/null || true)
    if echo "$output" | grep -qiE 'ogin:|sername:'; then
      NEEDS_LOGIN["$pane"]=1
    fi
  done

  # Phase 2: send username only to consoles that showed a real login prompt.
  for entry in "${LOGIN_QUEUE[@]}"; do
    IFS='|' read -r pane dev <<<"$entry"
    [[ -n "${NEEDS_LOGIN[$pane]:-}" ]] || continue
    read -r user pass <<<"$(creds_for "$dev")"
    herdr pane send-text "$pane" "$user" || true
    herdr pane send-keys "$pane" enter || true
  done
  sleep 0.5

  # Phase 3: send password only to those same consoles (blank pass = just Enter for EXOS admin).
  for entry in "${LOGIN_QUEUE[@]}"; do
    IFS='|' read -r pane dev <<<"$entry"
    [[ -n "${NEEDS_LOGIN[$pane]:-}" ]] || continue
    read -r user pass <<<"$(creds_for "$dev")"
    [[ "$pass" == "''" ]] && pass=""
    herdr pane send-text "$pane" "$pass" || true
    herdr pane send-keys "$pane" enter || true
  done
  sleep 0.5

  # Phase 3.5: VOSS-only — only devices still sitting at the unprivileged "> " prompt
  # need `enable`; some of these DT devices already come up at the privileged "# "
  # prompt, and sending enable there is a harmless no-op but pointless noise.
  declare -A NEEDS_ENABLE
  for entry in "${LOGIN_QUEUE[@]}"; do
    IFS='|' read -r pane dev <<<"$entry"
    [[ "$dev" == VOSS-* ]] || continue
    output=$(herdr pane read "$pane" --source recent --lines 5 2>/dev/null || true)
    last_line=$(echo "$output" | awk 'NF{line=$0} END{print line}')
    [[ "$last_line" == *'>' ]] && NEEDS_ENABLE["$pane"]=1
  done

  # Phase 4: send enable only to VOSS consoles that are confirmed at the "> " prompt.
  for entry in "${LOGIN_QUEUE[@]}"; do
    IFS='|' read -r pane dev <<<"$entry"
    if [[ -n "${NEEDS_ENABLE[$pane]:-}" ]]; then
      herdr pane send-text "$pane" "enable" || true
      herdr pane send-keys "$pane" enter || true
    fi
  done
}

# XIQEMU: runs locally on this laptop (not a remote host like the CI topology) —
# launch lazydocker and filter/select the xiqemu-server container.
# lazydocker panel jump: "2" = Containers. "/" opens the filter box (search-as-you-type).
xiqemu_lazydocker() {
  local pane="$1"
  herdr pane run "$pane" "lazydocker"
  sleep 1.5
  herdr pane send-keys "$pane" 2
  sleep 0.3
  herdr pane send-keys "$pane" /
  sleep 0.3
  herdr pane send-text "$pane" "xiqemu-server"
  sleep 0.3
  herdr pane send-keys "$pane" enter
}

# Rename pane then launch its device console/connection
connect() {
  local pane="$1" label="$2" dev="$3"
  herdr pane rename "$pane" "$label"
  if [[ "$dev" == "XIQEMU" ]]; then
    xiqemu_lazydocker "$pane"
  else
    herdr pane run "$pane" "$(console_cmd "$dev")"
    LOGIN_QUEUE+=("${pane}|${dev}")
  fi
}

# ── Create workspace + 3 tabs ─────────────────────────────────────────
echo "Creating Rack2DT-Local-Topology workspace..."

WS_JSON=$(herdr workspace create --cwd "$HOME/workspace/badaniya" --label Rack2DT-Local-Topology --focus)
WS_ID=$(echo "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['workspace']['workspace_id'])")
VOSS=$(echo "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
VOSS_TAB=$(echo "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['tab']['tab_id'])")
herdr tab rename "$VOSS_TAB" "1 - VOSS" >/dev/null

EXOS_ROOT=$(herdr tab create --workspace "$WS_ID" --label "2 - EXOS" --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
XIQEMU_ROOT=$(herdr tab create --workspace "$WS_ID" --label "3 - XIQEMU" --no-focus | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")

# ── VOSS: 3×3 grid + 1 full-width bottom row (10 panes) ───────────────
#
#  ┌────────────┬────────────┬────────────┐
#  │ VOSS-5301  │ VOSS-5401  │ VOSS-5402  │  row 1
#  ├────────────┼────────────┼────────────┤
#  │ VOSS-5701  │ VOSS-5702  │ VOSS-5529  │  row 2
#  ├────────────┼────────────┼────────────┤
#  │ VOSS-5530  │ VOSS-7413  │ VOSS-7414  │  row 3
#  ├────────────┴────────────┴────────────┤
#  │              VOSS-4908               │  row 4  (full width)
#  └───────────────────────────────────────┘

ROW4=$(herdr pane split "$VOSS" --direction down --ratio 0.75 --no-focus | pane_id)
COL2=$(herdr pane split "$VOSS" --direction right --ratio 0.33 --no-focus | pane_id)
COL3=$(herdr pane split "$COL2" --direction right --ratio 0.5 --no-focus | pane_id)

C1R2=$(herdr pane split "$VOSS" --direction down --ratio 0.33 --no-focus | pane_id)
C1R3=$(herdr pane split "$C1R2" --direction down --ratio 0.5 --no-focus | pane_id)
C2R2=$(herdr pane split "$COL2" --direction down --ratio 0.33 --no-focus | pane_id)
C2R3=$(herdr pane split "$C2R2" --direction down --ratio 0.5 --no-focus | pane_id)
C3R2=$(herdr pane split "$COL3" --direction down --ratio 0.33 --no-focus | pane_id)
C3R3=$(herdr pane split "$C3R2" --direction down --ratio 0.5 --no-focus | pane_id)

connect "$VOSS" "VOSS-5301 - console 5073" VOSS-5301
connect "$COL2" "VOSS-5401 - console 5077" VOSS-5401
connect "$COL3" "VOSS-5402 - console 5075" VOSS-5402
connect "$C1R2" "VOSS-5701 - console 5063" VOSS-5701
connect "$C2R2" "VOSS-5702 - console 5067" VOSS-5702
connect "$C3R2" "VOSS-5529 - console 5069" VOSS-5529
connect "$C1R3" "VOSS-5530 - console 5071" VOSS-5530
connect "$C2R3" "VOSS-7413 - console 5096" VOSS-7413
connect "$C3R3" "VOSS-7414 - console 5100" VOSS-7414
connect "$ROW4" "VOSS-4908 - console 5104" VOSS-4908

# ── EXOS: 3 top + 2 bottom (5 panes) ──────────────────────────────────
# 5302 + 5405(Stack) match the physical rack2; 5703/5704/5705 are extra on this DT rack.
#  ┌────────────┬──────────────────┬────────────┐
#  │ EXOS-5302  │ EXOS-5405(Stack) │ EXOS-5703  │
#  ├────────────┴────────┬─────────┴────────────┤
#  │     EXOS-5704        │       EXOS-5705       │
#  └──────────────────────┴───────────────────────┘
EXOS_ROW2=$(herdr pane split "$EXOS_ROOT" --direction down --ratio 0.4 --no-focus | pane_id)
EXOS_COL2=$(herdr pane split "$EXOS_ROOT" --direction right --ratio 0.33 --no-focus | pane_id)
EXOS_COL3=$(herdr pane split "$EXOS_COL2" --direction right --ratio 0.5 --no-focus | pane_id)
EXOS_ROW2B=$(herdr pane split "$EXOS_ROW2" --direction right --ratio 0.5 --no-focus | pane_id)

connect "$EXOS_ROOT" "EXOS-5302 - console 5079" EXOS-5302
connect "$EXOS_COL2" "EXOS-5405(Stack) - console 5021" EXOS-5405-Stack
connect "$EXOS_COL3" "EXOS-5703 - console 5088" EXOS-5703
connect "$EXOS_ROW2" "EXOS-5704 - console 5084" EXOS-5704
connect "$EXOS_ROW2B" "EXOS-5705 - console 5092" EXOS-5705

# ── XIQEMU: single pane (replaces the AP tab — this DT rack has no APs) ─
# XIQ Emulator / Inlets Server host for Rack2 Digital-Twin (CI).
# See NVO/scripts/development/xiqemu/common_xiq_emulator_setup_readme.md
connect "$XIQEMU_ROOT" "XIQEMU - lazydocker" XIQEMU

# ── Log in to all VOSS/EXOS consoles in one batched pass ──────────────
login_all

# ── Keepalive: prevent GNS3 telnet console idle-timeout logout ────────
# These simulated serial consoles get disconnected after a period of inactivity
# ("[1] NNNN terminated telnet 127.0.0.1 <port>"), dropping the pane back to the
# host shell and requiring a manual reconnect + re-login. A detached background
# loop sends a harmless Enter to every VOSS/EXOS pane every 2 minutes to keep
# each telnet session's idle timer from tripping. Runs via setsid+nohup so it
# survives this script exiting and keeps going for the life of the workspace.
KEEPALIVE_LOG="$HOME/.config/herdr-spreader/rack2dt-local-topology.keepalive.log"
KEEPALIVE_PIDFILE="$HOME/.config/herdr-spreader/rack2dt-local-topology.keepalive.pid"
KEEPALIVE_PANES=("$VOSS" "$COL2" "$COL3" "$C1R2" "$C2R2" "$C3R2" "$C1R3" "$C2R3" "$C3R3" "$ROW4" \
                  "$EXOS_ROOT" "$EXOS_COL2" "$EXOS_COL3" "$EXOS_ROW2" "$EXOS_ROW2B")

start_keepalive() {
  echo "Starting console keepalive loop (${#KEEPALIVE_PANES[@]} panes, every 120s)..."
  setsid nohup bash -c '
    while true; do
      for pane in '"${KEEPALIVE_PANES[*]}"'; do
        herdr pane send-keys "$pane" enter >/dev/null 2>&1
      done
      echo "$(date -u +%FT%TZ) keepalive sent"
      sleep 120
    done
  ' >>"$KEEPALIVE_LOG" 2>&1 </dev/null &
  echo $! >"$KEEPALIVE_PIDFILE"
  disown
}

start_keepalive

echo "✅ Rack2DT-Local-Topology ready (workspace $WS_ID) — switch to it in herdr"
echo "   Console keepalive running (PID $(cat "$KEEPALIVE_PIDFILE")); log: $KEEPALIVE_LOG"
echo "   To stop it: kill \$(cat $KEEPALIVE_PIDFILE)"
