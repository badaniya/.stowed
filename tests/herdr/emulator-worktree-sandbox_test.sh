#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPTS="$REPO_ROOT/herdr/.config/herdr-spreader"
fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}
[[ -f $SCRIPTS/emulator-worktree-sandbox.sh ]] || fail 'EMULATOR launcher is missing'
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
export HOME="$TEST_ROOT/home" TEST_LOG="$TEST_ROOT/commands.log"
mkdir -p "$HOME/.config/herdr-spreader" "$TEST_ROOT/bin"
for name in emulator-worktree-sandbox.sh emulator-worktree-sandbox-notify.sh; do
  cp "$SCRIPTS/$name" "$HOME/.config/herdr-spreader/$name"
done
export PATH="$TEST_ROOT/bin:$PATH"
cat >"$HOME/.config/herdr-spreader/nvo-harness-worktree-sandbox.sh" <<'EOF'
#!/usr/bin/env bash
printf 'emulator=%s\n' "${EMULATOR_WORKSPACE:-missing}" >>"$TEST_LOG"
printf 'arg=%s\n' "$@" >>"$TEST_LOG"
if [[ ${TEST_FAIL:-false} == true ]]; then printf 'fixture sandbox failure\n' >&2; exit 7; fi
EOF
cat >"$TEST_ROOT/bin/herdr" <<'EOF'
#!/usr/bin/env bash
printf 'herdr %s\n' "$*" >>"$TEST_LOG"
EOF
chmod +x "$TEST_ROOT/bin/herdr"
launcher="$HOME/.config/herdr-spreader/emulator-worktree-sandbox.sh"
notify="$HOME/.config/herdr-spreader/emulator-worktree-sandbox-notify.sh"
for form in single positional; do
  : >"$TEST_LOG"
  if [[ $form == single ]]; then
    bash "$launcher" 'EMULATOR-10 25.17.0 --restore-harness'
  else bash "$launcher" EMULATOR-10 25.17.0 --restore-harness; fi
  for line in 'emulator=true' 'arg=EMULATOR-10' 'arg=25.17.0' 'arg=--restore-harness'; do
    rg -Fxq -- "$line" "$TEST_LOG" || fail "missing delegation: $line"
  done
done
for input in '' 'NVO-10 25.17.0' '../EMULATOR-10 25.17.0' 'EMULATOR-10' 'EMULATOR-10 --restore-harness' 'EMULATOR-10 25.17.0 extra' 'EMULATOR-10 25.17.0 --force' 'EMULATOR-10 --bad' 'EMULATOR-10 25.17.0 --restore-harness --restore-harness' 'EMULATOR-10 bad..branch'; do
  : >"$TEST_LOG"
  if bash "$launcher" "$input" >"$TEST_ROOT/output" 2>&1; then fail "accepted invalid input: $input"; fi
  [[ ! -s $TEST_LOG ]] || fail 'invalid input delegated sandbox creation'
done
# Origin-qualified NVO versions remain supported.
bash "$launcher" EMULATOR-11 origin/25.17.0
if TEST_FAIL=true bash "$launcher" EMULATOR-10 25.17.0 >"$TEST_ROOT/output" 2>&1; then fail 'delegate failure ignored'; fi
# Notifications must never send successful output back into the invoking pane.
: >"$TEST_LOG"
HERDR_PLUS_PANE_ID=w9:p1 bash "$notify" 'EMULATOR-10 25.17.0'
if rg -q '^herdr ' "$TEST_LOG"; then fail 'success notified a failure'; fi
# Sandbox failures are surfaced, without accidentally controlling the real Herdr.
: >"$TEST_LOG"
if TEST_FAIL=true HERDR_PLUS_PANE_ID=w9:p1 bash "$notify" 'EMULATOR-10 25.17.0'; then fail 'notification wrapper swallowed failure'; fi
rg -Fq 'herdr pane run w9:p1 cat /tmp/emulator-worktree-sandbox-last-error' "$TEST_LOG" || fail 'missing invoking-pane failure message'
if TEST_FAIL=true HERDR_PLUS_PANE_ID='' bash "$notify" 'EMULATOR-10 25.17.0' >"$TEST_ROOT/output" 2>&1; then fail 'no-pane wrapper swallowed failure'; fi
rg -Fq 'fixture sandbox failure' "$TEST_ROOT/output" || fail 'no-pane error was not surfaced'
python3 - "$REPO_ROOT" <<'PY'
import pathlib, sys, tomllib
root = pathlib.Path(sys.argv[1])
action = root / 'herdr/.config/herdr/plugins/config/cloudmanic.herdr-plus/quick-actions/ws-emulator-worktree-sandbox.toml'
with action.open('rb') as f:
    data = tomllib.load(f)
assert data['type'] == 'form'
assert 'EMULATOR-WORKTREE-SANDBOX' in data['name']
assert data['command'] == "bash ~/.config/herdr-spreader/emulator-worktree-sandbox-notify.sh '{{.Value}}'"
assert 'master' in data['form']['prompt']
assert 'EMULATOR-10' in data['form']['placeholder']
PY
printf 'PASS: EMULATOR form, delegation, argument validation and notifications\n'
