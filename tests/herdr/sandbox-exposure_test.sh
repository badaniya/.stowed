#!/usr/bin/env bash
set -euo pipefail
unset HERDR_ENV HERDR_SOCKET_PATH HERDR_ACTION_ERROR_ACTIVE
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
LAUNCHER="$ROOT/herdr/.config/herdr-spreader/sandbox-exposure.sh"
DIALOG="$ROOT/herdr/.config/herdr-spreader/sandbox-exposure-dialog.sh"
ACTION="$ROOT/herdr/.config/herdr/plugins/config/cloudmanic.herdr-plus/quick-actions/sandbox-exposure.toml"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/home"
export TEST_LOG="$TMP/log"
cat >"$TMP/bin/herdr" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TEST_LOG"
case "$1 $2" in
'pane split') printf '%s\n' "${TEST_SPLIT_RESPONSE:-{\"result\":{\"pane\":{\"pane_id\":\"w1:p2\"}}}}" ;;
'pane run') [[ ${TEST_FAIL_RUN:-0} == 0 ]] ;;
'pane close') exit 0 ;;
*) exit 2 ;;
esac
EOF
cat >"$TMP/bin/sudo" <<'EOF'
#!/usr/bin/env bash
printf '%q ' "$@" >>"$TEST_LOG"
printf '\n' >>"$TEST_LOG"
[[ ${TEST_SUDO_FAIL:-false} != true ]] || { printf 'Error: fixture exposure failure\n' >&2; exit 17; }
EOF
chmod +x "$TMP/bin/"*
export PATH="$TMP/bin:$PATH" HOME="$TMP/home" HERDR_PLUS_PANE_ID=w1:p1 XDG_STATE_HOME="$TMP/state"
fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}
: >"$TEST_LOG"
bash "$LAUNCHER" xiqfwd1
rg -q '^pane split w1:p1 --direction down --focus$' "$TEST_LOG" || fail 'missing focused pane'
rg -q '^pane run w1:p2 .*sandbox-exposure-dialog.sh.*xiqfwd1$' "$TEST_LOG" || fail 'missing safe dialog launch'
: >"$TEST_LOG"
bash "$LAUNCHER" list || fail 'launcher rejected direct list'
rg -q '^pane run w1:p2 .*sandbox-exposure-dialog.sh.*list$' "$TEST_LOG" || fail 'missing direct list pane launch'
for operation in create update delete status list adopt; do
  : >"$TEST_LOG"
  bash "$LAUNCHER" "xiqfwd0 $operation" || fail "launcher rejected direct $operation"
  rg -q "^pane run w1:p2 .*sandbox-exposure-dialog.sh.*xiqfwd0 $operation$" "$TEST_LOG" || fail "missing direct $operation dialog launch"
done
: >"$TEST_LOG"
bash "$LAUNCHER" xiqfwd0 update || fail 'launcher rejected separate operation argument'
rg -q '^pane run w1:p2 .*sandbox-exposure-dialog.sh.*xiqfwd0 update$' "$TEST_LOG" || fail 'missing separate operation delegation'
for bad in 'xiqfwd1;touch /tmp/nope' 'xiqfwd01' '../xiqfwd0' '' 'list;id' 'list extra' 'xiqfwd0 unknown' 'xiqfwd0 update extra' 'xiqfwd0 update;id' $'xiqfwd0 update\nstatus'; do
  : >"$TEST_LOG"
  if bash "$LAUNCHER" "$bad"; then fail 'accepted invalid input'; fi
  [[ ! -s $TEST_LOG ]] || fail 'invalid input invoked Herdr'
done
: >"$TEST_LOG"
if HERDR_PLUS_PANE_ID=bad bash "$LAUNCHER" xiqfwd1; then fail 'accepted invalid pane'; fi
[[ ! -s $TEST_LOG ]] || fail 'invalid pane invoked Herdr'
: >"$TEST_LOG"
if TEST_FAIL_RUN=1 bash "$LAUNCHER" xiqfwd1; then fail 'ignored run failure'; fi
rg -q '^pane close -- w1:p2$' "$TEST_LOG" || fail 'failed launch did not close new pane'
: >"$TEST_LOG"
printf '2\n10.77.1.2\ntcp:443,udp:5000-5002\n' | bash "$DIALOG" xiqfwd1
rg -q 'python3 .*sandbox-exposure.py update xiqfwd1 --target 10.77.1.2 --ports tcp:443\\,udp:5000-5002' "$TEST_LOG" || fail 'dialog did not preserve argument boundaries'
: >"$TEST_LOG"
printf '10.77.1.3\ntcp:8443\n' | bash "$DIALOG" xiqfwd0 update
rg -q 'update xiqfwd0 --target 10.77.1.3 --ports tcp:8443' "$TEST_LOG" || fail 'direct update did not reach target/ports prompts'
: >"$TEST_LOG"
bash "$DIALOG" xiqfwd0 status </dev/null
rg -q 'status xiqfwd0' "$TEST_LOG" || fail 'direct status asked for menu input'
: >"$TEST_LOG"
if bash "$DIALOG" xiqfwd0 'update;id'; then fail 'dialog accepted invalid operation'; fi
[[ ! -s $TEST_LOG ]] || fail 'invalid operation invoked backend'
: >"$TEST_LOG"
printf '3\n' | bash "$DIALOG" xiqfwd1
rg -q 'delete xiqfwd1' "$TEST_LOG" || fail 'missing delete delegation'
: >"$TEST_LOG"
printf '5\n' | bash "$DIALOG" xiqfwd1
rg -q 'list' "$TEST_LOG" || fail 'missing list delegation'
: >"$TEST_LOG"
bash "$DIALOG" list </dev/null >"$TMP/list-output" || fail 'dialog rejected direct list'
rg -q '^-- python3 .*sandbox-exposure.py list $' "$TEST_LOG" || fail 'direct list did not delegate without an interface'
if rg -q 'Choose:' "$TMP/list-output"; then fail 'direct list prompted for a menu selection'; fi
: >"$TEST_LOG"
printf '1\neth0\nagentbr0\ndefault\n10.77.1.2\nall\n' | bash "$DIALOG" xiqfwd1
rg -q 'create xiqfwd1 --parent eth0 --network agentbr0 --project default --target 10.77.1.2 --ports all' "$TEST_LOG" || fail 'missing explicit create arguments'
: >"$TEST_LOG"
printf '6\neth0\nagentbr0\ndefault\n10.77.1.2\nall\n12345\n' | bash "$DIALOG" xiqfwd0
rg -q 'adopt xiqfwd0 --parent eth0 --network agentbr0 --project default --target 10.77.1.2 --ports all --legacy-dhcp-pid 12345' "$TEST_LOG" || fail 'missing explicit adopt expectations'
: >"$TEST_LOG"
if printf '6\neth0\n\n\n10.77.1.2\nall\nnot-a-pid\n' | bash "$DIALOG" xiqfwd0; then fail 'adopt accepted invalid PID'; fi
[[ ! -s $TEST_LOG ]] || fail 'invalid adoption invoked backend'
: >"$TEST_LOG"
printf 'q\n' | bash "$DIALOG" xiqfwd1
[[ ! -s $TEST_LOG ]] || fail 'cancel invoked backend'
: >"$TEST_LOG"
if bash "$DIALOG" 'xiqfwd1;id'; then fail 'dialog accepted invalid name'; fi
[[ ! -s $TEST_LOG ]] || fail 'invalid dialog input invoked backend'
if TEST_SUDO_FAIL=true bash "$DIALOG" xiqfwd0 status </dev/null >"$TMP/failure-output" 2>&1; then fail 'dialog swallowed backend failure'; fi
rg -q 'fixture exposure failure' "$TMP/state/herdr/action-errors/"*.log || fail 'dialog backend failure log missing'
rg -q 'Sandbox Exposure: status xiqfwd0' "$TMP/state/herdr/action-errors/"*.json || fail 'dialog failure metadata missing'
python3 - "$ACTION" <<'EOF'
import sys
import tomllib
with open(sys.argv[1], 'rb') as handle:
    action = tomllib.load(handle)
assert action['name'] == 'Sandbox: Exposure'
assert action['type'] == 'form'
assert 'herdr-action-errors.py run --name' in action['command']
assert action['command'].endswith('-- bash ~/.config/herdr-spreader/sandbox-exposure.sh')
assert 'xiqfwd' in action['form']['placeholder']
EOF
printf 'PASS: sandbox exposure launcher/dialog\n'
