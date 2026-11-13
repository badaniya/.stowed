#!/usr/bin/env bash
# Exercise the dedicated action boundary; sandbox removal is mocked here.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPTS="$REPO_ROOT/herdr/.config/herdr-spreader"
fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}
[[ -f $SCRIPTS/emulator-worktree-sandbox-remove.sh ]] || fail 'EMULATOR destroy launcher is missing'
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
export HOME="$TEST_ROOT/home" TEST_LOG="$TEST_ROOT/commands.log" XDG_STATE_HOME="$TEST_ROOT/state"
unset HERDR_ENV HERDR_SOCKET_PATH HERDR_ACTION_ERROR_ACTIVE
mkdir -p "$HOME/.config/herdr-spreader" "$TEST_ROOT/bin"
for name in emulator-worktree-sandbox-remove.sh emulator-worktree-sandbox-remove-notify.sh herdr-action-errors.py; do
  cp "$SCRIPTS/$name" "$HOME/.config/herdr-spreader/$name"
done
export PATH="$TEST_ROOT/bin:$PATH"
cat >"$HOME/.config/herdr-spreader/nvo-harness-worktree-sandbox-remove.sh" <<'EOF'
#!/usr/bin/env bash
printf 'arg=%s\n' "$@" >>"$TEST_LOG"
if [[ ${TEST_FAIL:-false} == true ]]; then printf 'fixture destroy failure\n' >&2; exit 7; fi
EOF
cat >"$TEST_ROOT/bin/herdr" <<'EOF'
#!/usr/bin/env bash
printf 'herdr %s\n' "$*" >>"$TEST_LOG"
EOF
chmod +x "$TEST_ROOT/bin/herdr"
launcher="$HOME/.config/herdr-spreader/emulator-worktree-sandbox-remove.sh"
notify="$HOME/.config/herdr-spreader/emulator-worktree-sandbox-remove-notify.sh"
for form in single positional; do
  for flag in '' --keep-worktrees --force; do
    : >"$TEST_LOG"
    if [[ $form == single ]]; then
      bash "$launcher" "EMULATOR-10${flag:+ $flag}"
    elif [[ -n $flag ]]; then
      bash "$launcher" EMULATOR-10 "$flag"
    else
      bash "$launcher" EMULATOR-10
    fi
    printf 'arg=EMULATOR-10\n' >"$TEST_ROOT/expected"
    printf 'arg=%s\n' "${flag:---force}" >>"$TEST_ROOT/expected"
    cmp -s "$TEST_ROOT/expected" "$TEST_LOG" || fail "incorrect delegation: $form $flag"
  done
done
for ticket in 'EMULATOR - 11' 'EMULATOR- 11' 'EMULATOR -11'; do
  : >"$TEST_LOG"
  if bash "$launcher" "$ticket" >"$TEST_ROOT/output" 2>&1; then fail "accepted spaced ticket: $ticket"; fi
  [[ ! -s $TEST_LOG ]] || fail 'spaced ticket delegated sandbox destruction'
  rg -Fq 'Error: invalid ticket input' "$TEST_ROOT/output" || fail 'missing invalid-ticket error'
  rg -Fq 'EMULATOR-11 (no spaces around the hyphen)' "$TEST_ROOT/output" || fail 'missing ticket format hint'
  printf -v received '%q' "$ticket"
  rg -Fq "$received" "$TEST_ROOT/output" || fail 'missing rejected input'
done
for input in 'EMULATOR - 1 1' 'EMULATOR - 11x' 'EMULATOR - 11 --unknown' 'EMULATOR - 11; touch nope' '' 'NVO-10' '../EMULATOR-10' 'EMULATOR-' 'EMULATOR-10x' 'emulator-10' 'EMULATOR-10 --unknown' 'EMULATOR-10 extra' 'EMULATOR-10 --force --keep-worktrees' 'EMULATOR-10 --keep-worktrees --force' 'EMULATOR-10; touch nope'; do
  : >"$TEST_LOG"
  if bash "$launcher" "$input" >"$TEST_ROOT/output" 2>&1; then fail "accepted invalid input: $input"; fi
  [[ ! -s $TEST_LOG ]] || fail 'invalid input delegated sandbox destruction'
  rg -Fq 'Error:' "$TEST_ROOT/output" || fail "missing validation error: $input"
done
if bash "$launcher" >"$TEST_ROOT/output" 2>&1; then fail 'accepted missing arguments'; fi
rg -Fq 'force-removes worktrees by default' "$TEST_ROOT/output" || fail 'usage does not explain force default'
rg -Fq 'Error: missing ticket' "$TEST_ROOT/output" || fail 'missing missing-ticket error'
if TEST_FAIL=true bash "$launcher" EMULATOR-10 >"$TEST_ROOT/output" 2>&1; then fail 'delegate failure ignored'; fi
: >"$TEST_LOG"
HERDR_PLUS_PANE_ID=w9:p1 bash "$notify" EMULATOR-10
if rg -q '^herdr ' "$TEST_LOG"; then fail 'success notified a failure'; fi
: >"$TEST_LOG"
if TEST_FAIL=true HERDR_PLUS_PANE_ID=w9:p1 bash "$notify" EMULATOR-10 >"$TEST_ROOT/output" 2>&1; then fail 'notification wrapper swallowed failure'; fi
rg -Fq 'fixture destroy failure' "$TEST_ROOT/output" || fail 'missing failure output'
rg -q 'fixture destroy failure' "$XDG_STATE_HOME/herdr/action-errors/"*.log || fail 'missing retained failure log'
if rg -q '^herdr ' "$TEST_LOG"; then fail 'failure injected input into an existing pane'; fi
if TEST_FAIL=true HERDR_PLUS_PANE_ID='' bash "$notify" EMULATOR-10 >"$TEST_ROOT/output" 2>&1; then fail 'no-pane wrapper swallowed failure'; fi
rg -Fq 'fixture destroy failure' "$TEST_ROOT/output" || fail 'no-pane failure was not surfaced'
python3 - "$REPO_ROOT" <<'PY'
import pathlib, sys, tomllib
root = pathlib.Path(sys.argv[1])
action = root / 'herdr/.config/herdr/plugins/config/cloudmanic.herdr-plus/quick-actions/ws-emulator-worktree-sandbox-remove.toml'
with action.open('rb') as f:
    data = tomllib.load(f)
assert data['type'] == 'form'
assert data['name'] == 'Destroy sandbox & remove workspace: EMULATOR-WORKTREE-SANDBOX'
assert 'herdr-action-errors.py run --name' in data['command']
assert data['command'].endswith("-- bash ~/.config/herdr-spreader/emulator-worktree-sandbox-remove-notify.sh '{{.Value}}'")
assert 'DESTRUCTIVE' in data['form']['prompt']
assert 'cloudemu' in data['form']['prompt']
assert '--keep-worktrees' in data['form']['prompt']
assert data['form']['placeholder'] == 'EMULATOR-10 [--keep-worktrees]'
PY
printf 'PASS: EMULATOR destroy form, validation, delegation and notifications\n'
