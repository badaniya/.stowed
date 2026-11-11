#!/usr/bin/env bash
# Real cloudemu Git cleanup; all sandbox and Herdr calls are mocked.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$REPO_ROOT/herdr/.config/herdr-spreader/nvo-harness-worktree-sandbox-remove.sh"
fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
export HOME="$TEST_ROOT/home" TEST_LOG="$TEST_ROOT/commands.log"
# Existing sandbox removal uses this fixed workspace convention.
export NVO_WORKSPACE_ROOT="$HOME/workspace/badaniya" NVO_WORKSPACE_OWNER=badaniya
export GIT_CONFIG_NOSYSTEM=1 GIT_ALLOW_PROTOCOL=file
export GIT_CONFIG_GLOBAL="$HOME/.gitconfig" XDG_CONFIG_HOME="$HOME/.config"
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR
mkdir -p "$HOME/.config/herdr-spreader" "$HOME/.local/bin" "$TEST_ROOT/bin" "$NVO_WORKSPACE_ROOT/master"
export PATH="$TEST_ROOT/bin:$PATH"
git config --global user.name Fixture
git config --global user.email fixture@example.invalid
git init -q -b master "$TEST_ROOT/seed"
git -C "$TEST_ROOT/seed" commit -qm initial --allow-empty
git clone -q --bare "$TEST_ROOT/seed" "$TEST_ROOT/remote"
git config --global url."file://$TEST_ROOT/remote".insteadOf https://github.extremenetworks.com/thomma/cloudemu.git
# shellcheck source=/dev/null
source "$REPO_ROOT/herdr/.config/herdr-spreader/emulator-worktree.sh"
emulator_worktree_prepare "$NVO_WORKSPACE_ROOT" badaniya EMULATOR-10 >"$TEST_ROOT/output" 2>&1
project="$NVO_WORKSPACE_ROOT/EMULATOR-10"
printf 'local work\n' >"$project/cloudemu/local-changes"
cat >"$HOME/.local/bin/labctl" <<'EOF'
#!/usr/bin/env bash
printf 'labctl %s\n' "$*" >>"$TEST_LOG"
[[ ${TEST_FAIL_DESTROY:-false} != true ]]
EOF
cat >"$TEST_ROOT/bin/sg" <<'EOF'
#!/usr/bin/env bash
[[ $1 == incus-admin && $2 == -c ]] || exit 2
bash -c "$3"
EOF
cat >"$TEST_ROOT/bin/sudo" <<'EOF'
#!/usr/bin/env bash
printf 'sudo %s\n' "$*" >>"$TEST_LOG"
EOF
cat >"$TEST_ROOT/bin/herdr" <<'EOF'
#!/usr/bin/env bash
printf 'herdr %s\n' "$*" >>"$TEST_LOG"
printf '%s\n' '{"result":{"workspaces":[]}}'
EOF
cat >"$HOME/.config/herdr-spreader/nvo-harness-worktree-remove.sh" <<'EOF'
#!/usr/bin/env bash
[[ ! -e $NVO_WORKSPACE_ROOT/$1/cloudemu ]] || { printf 'cloudemu cleanup did not precede legacy remover\n' >&2; exit 1; }
printf 'legacy-remove %s\n' "$*" >>"$TEST_LOG"
EOF
chmod +x "$HOME/.local/bin/labctl" "$TEST_ROOT/bin/sg" "$TEST_ROOT/bin/sudo" "$TEST_ROOT/bin/herdr"
: >"$TEST_LOG"
bash "$SCRIPT" 'EMULATOR-10 --keep-worktrees' >"$TEST_ROOT/output" 2>&1
[[ -f $project/cloudemu/local-changes ]] || fail 'keep-worktrees removed cloudemu edits'
if rg -q '^(sudo |legacy-remove )' "$TEST_LOG"; then fail 'keep-worktrees attempted cleanup'; fi
: >"$TEST_LOG"
if TEST_FAIL_DESTROY=true bash "$SCRIPT" EMULATOR-10 >"$TEST_ROOT/output" 2>&1; then fail 'failed destroy was ignored'; fi
[[ -f $project/cloudemu/local-changes ]] || fail 'failed destroy removed cloudemu'
if rg -q '^(sudo |legacy-remove )' "$TEST_LOG"; then fail 'failed destroy continued cleanup'; fi
: >"$TEST_LOG"
if ! bash "$SCRIPT" EMULATOR-10 >"$TEST_ROOT/output" 2>&1; then fail "cleanup failed: $(<"$TEST_ROOT/output")"; fi
[[ ! -e $project/cloudemu ]] || fail 'sandbox removal orphaned cloudemu worktree'
if git -C "$NVO_WORKSPACE_ROOT/master/cloudemu" show-ref --verify --quiet refs/heads/badaniya/cloudemu/EMULATOR-10; then fail 'sandbox removal orphaned branch'; fi
rg -q '^labctl destroy EMULATOR-10 --yes$' "$TEST_LOG" || fail 'sandbox was not destroyed'
# Refuse to delete or repair ownership of an unrelated cloudemu directory.
mkdir -p "$project/cloudemu"
printf 'preserve\n' >"$project/cloudemu/sentinel"
: >"$TEST_LOG"
if bash "$SCRIPT" EMULATOR-10 >"$TEST_ROOT/output" 2>&1; then fail 'unrelated cloudemu directory was accepted'; fi
[[ -f $project/cloudemu/sentinel ]] || fail 'removed unrelated directory'
if rg -q '^(sudo |legacy-remove )' "$TEST_LOG"; then fail 'unsafe state reached cleanup'; fi
# The external legacy remover is hardcoded to ~/workspace/badaniya. Refuse
# overrides explicitly rather than silently destroying a different checkout.
: >"$TEST_LOG"
if NVO_WORKSPACE_OWNER=fixture bash "$SCRIPT" EMULATOR-10 >"$TEST_ROOT/output" 2>&1; then fail 'custom cleanup owner accepted'; fi
rg -Fq 'legacy sandbox removal supports only' "$TEST_ROOT/output" || fail 'missing custom-root limitation message'
[[ ! -s $TEST_LOG ]] || fail 'custom cleanup root reached destructive commands'
printf 'PASS: EMULATOR cleanup, keep-worktrees, root guards and destroy failure safety\n'
