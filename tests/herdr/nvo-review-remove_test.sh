#!/usr/bin/env bash
# Real Git fixtures; destructive external services are test doubles.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$ROOT/herdr/.config/herdr-spreader/nvo-review-remove.sh"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
[[ -f $SCRIPT ]] || fail 'review cleanup action is missing'
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" XDG_STATE_HOME="$tmp/state" NVO_WORKSPACE_ROOT="$tmp/workspace"
export TEST_LOG="$tmp/commands" TEST_DESTROY_FAIL=false
mkdir -p "$HOME/.local/bin" "$tmp/bin" "$NVO_WORKSPACE_ROOT/master"
export PATH="$tmp/bin:$PATH" GIT_CONFIG_NOSYSTEM=1 GIT_ALLOW_PROTOCOL=file
: >"$TEST_LOG"
git config --global user.name Test
git config --global user.email test@example.invalid
git init -q "$tmp/submodule"
printf 'submodule\n' >"$tmp/submodule/file"
git -C "$tmp/submodule" add .
git -C "$tmp/submodule" commit -qm initial
for repo in GoDCApp PlatformServices PlatformServicesCommon PlatformCommonModels; do
  git init -q "$tmp/seed-$repo"
  printf 'base\n' >"$tmp/seed-$repo/file"
  if [[ $repo == PlatformServices ]]; then
    git -C "$tmp/seed-$repo" submodule add -q "$tmp/submodule" IAM/authn/casdoor
  fi
  git -C "$tmp/seed-$repo" add .
  git -C "$tmp/seed-$repo" commit -qm initial
  git clone -q --bare "$tmp/seed-$repo" "$NVO_WORKSPACE_ROOT/master/$repo"
done
cat >"$HOME/.local/bin/labctl" <<'SH'
#!/usr/bin/env bash
printf 'labctl %s\n' "$*" >>"$TEST_LOG"
[[ $TEST_DESTROY_FAIL != true ]]
SH
cat >"$tmp/bin/sg" <<'SH'
#!/usr/bin/env bash
[[ $1 == incus-admin && $2 == -c ]] || exit 2
bash -c "$3"
SH
cat >"$tmp/bin/sudo" <<'SH'
#!/usr/bin/env bash
printf 'sudo %s\n' "$*" >>"$TEST_LOG"
# Fixtures are already owned by this user.
[[ $1 == chown ]]
SH
cat >"$tmp/bin/herdr" <<'SH'
#!/usr/bin/env bash
printf 'herdr %s\n' "$*" >>"$TEST_LOG"
case "$1 $2" in
  'workspace list') printf '%s\n' '{"result":{"workspaces":[{"label":"NVO-REVIEW-CFD-123 - Review","workspace_id":"w1"},{"label":"NVO-REVIEW-CFD-1234","workspace_id":"w2"},{"label":"CFD-123","workspace_id":"w3"}]}}' ;;
  'workspace close') [[ $3 == w1 ]] ;;
  *) exit 2 ;;
esac
SH
chmod +x "$tmp/bin/"* "$HOME/.local/bin/labctl"
key=NVO-REVIEW-CFD-123
project="$NVO_WORKSPACE_ROOT/$key"
state="$XDG_STATE_HOME/herdr-spreader"
fixture() {
  mkdir -p "$project/.nvo-review" "$project/.agents" "$project/.claude" "$state/$key.stages" "$state/$key.pane-history"
  printf 'main\n' >"$project/.nvo-review/base"
  touch "$project/.agents/.herdr-aggregate-context" "$project/.claude/.herdr-aggregate-context"
  touch "$state/$key.log" "$state/$key.log.worker-ready" "$state/$key.log.monitor-pane" "$state/$key.GoDCApp.gh-dash.yml" "$state/$key-other.log"
  for repo in GoDCApp PlatformServices PlatformServicesCommon PlatformCommonModels; do
    git -C "$NVO_WORKSPACE_ROOT/master/$repo" worktree add -q --detach "$project/$repo" HEAD
  done
  git -C "$project/GoDCApp" switch -qc alice/CFD-123
  printf 'local commit\n' >>"$project/GoDCApp/file"
  git -C "$project/GoDCApp" commit -qam 'unpushed review work'
  printf 'dirty\n' >>"$project/GoDCApp/file"
  git -C "$project/PlatformServices" submodule update --init -q
  : >"$TEST_LOG"
}
run() { bash "$SCRIPT" "$@" >"$tmp/output" 2>&1 || { printf '%s\n' "$(<"$tmp/output")" >&2; fail 'cleanup failed'; }; }
reject() { if bash "$SCRIPT" "$@" >"$tmp/output" 2>&1; then fail "accepted unsafe cleanup: $*"; fi; }
fixture
commit=$(git -C "$project/GoDCApp" rev-parse HEAD)
# Invalid input, active bootstrap and wrong/symlinked repositories fail before destroy.
reject '../CFD-123'
reject 'CFD-123 --unknown'
flock "$state/$key.lock" sleep 2 &
lock_pid=$!
sleep 0.1
reject CFD-123
wait "$lock_pid"
mv "$project/PlatformCommonModels" "$project/pcm-backup"
ln -s "$project/pcm-backup" "$project/PlatformCommonModels"
reject CFD-123
rm "$project/PlatformCommonModels"
mv "$project/pcm-backup" "$project/PlatformCommonModels"
# A valid linked worktree from the wrong shared repo must also be rejected.
git -C "$NVO_WORKSPACE_ROOT/master/PlatformCommonModels" worktree remove --force "$project/PlatformCommonModels"
git -C "$NVO_WORKSPACE_ROOT/master/GoDCApp" worktree add -q --detach "$project/PlatformCommonModels" HEAD
reject CFD-123
git -C "$NVO_WORKSPACE_ROOT/master/GoDCApp" worktree remove --force "$project/PlatformCommonModels"
git -C "$NVO_WORKSPACE_ROOT/master/PlatformCommonModels" worktree add -q --detach "$project/PlatformCommonModels" HEAD
[[ ! -s $TEST_LOG ]] || fail 'invalid target caused external mutations'
export TEST_DESTROY_FAIL=true
reject CFD-123
[[ -f $project/GoDCApp/.git && -f $state/$key.log ]] || fail 'destroy failure removed worktrees/state'
export TEST_DESTROY_FAIL=false
: >"$TEST_LOG"
run CFD-123
[[ ! -e $project ]] || fail 'review project remains'
[[ $(git -C "$NVO_WORKSPACE_ROOT/master/GoDCApp" rev-parse refs/heads/alice/CFD-123) == "$commit" ]] || fail 'PR branch/commits were deleted'
for repo in GoDCApp PlatformServices PlatformServicesCommon PlatformCommonModels; do
  if git -C "$NVO_WORKSPACE_ROOT/master/$repo" worktree list --porcelain | rg -Fq "$project/$repo"; then fail 'worktree registration remains'; fi
done
[[ ! -e $state/$key.stages && ! -e $state/$key.log && ! -e $state/$key.GoDCApp.gh-dash.yml && -f $state/$key-other.log && -f $state/$key.lock ]] || fail 'state cleanup scope is wrong'
rg -Fq 'labctl destroy NVO-REVIEW-CFD-123 --yes' "$TEST_LOG" || fail 'wrong sandbox identity'
[[ $(tail -n 1 "$TEST_LOG") == 'herdr workspace close w1' ]] || fail 'workspace not closed last'
run NVO-REVIEW-CFD-123 # Repeated cleanup is safe.
git -C "$NVO_WORKSPACE_ROOT/master/GoDCApp" branch -D alice/CFD-123 >/dev/null
fixture
run 'CFD-123 --keep-worktrees'
[[ -f $project/GoDCApp/.git && -f $project/.nvo-review/base && -f $state/$key.log ]] || fail '--keep-worktrees removed project/state'
# Retry a partially removed project: missing registered worktrees are cleaned,
# while unknown root files and unrelated linked worktrees remain untouched.
rm -rf "$project/PlatformServicesCommon"
printf 'keep me\n' >"$project/user-notes"
git -C "$NVO_WORKSPACE_ROOT/master/GoDCApp" worktree add -q --detach "$tmp/unrelated" HEAD
run CFD-123
[[ -f $project/user-notes && -f $tmp/unrelated/.git ]] || fail 'cleanup touched unrelated files/worktrees'
[[ ! -e $project/.nvo-review ]] || fail 'review metadata remains'
ln -s "$SCRIPT" "$HOME/.config/herdr-spreader/nvo-review-remove.sh" 2>/dev/null || {
  mkdir -p "$HOME/.config/herdr-spreader"
  ln -s "$SCRIPT" "$HOME/.config/herdr-spreader/nvo-review-remove.sh"
}
if bash "$ROOT/herdr/.config/herdr-spreader/nvo-review-remove-notify.sh" '../unsafe' >"$tmp/notify-output" 2>&1; then
  fail 'notification wrapper hid cleanup failure'
fi
rg -Fq 'ticket must use a Jira key' "$tmp/notify-output" || fail 'wrapper did not surface failure'
python3 - "$ROOT" <<'PY'
import pathlib, sys, tomllib
path = pathlib.Path(sys.argv[1]) / 'herdr/.config/herdr/plugins/config/cloudmanic.herdr-plus/quick-actions/ws-nvo-review-remove.toml'
action = tomllib.loads(path.read_text())
assert action['type'] == 'form'
assert 'nvo-review-remove-notify.sh' in action['command']
assert '{{.Value}}' in action['command']
PY
printf 'PASS: review teardown, submodules, branch preservation, guards, retry, keep-worktrees and action wiring\n'
