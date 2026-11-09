#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="${REPO_ROOT}/herdr/.config/herdr-spreader/nvo-harness-worktree-sandbox-remove.sh"

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

assert_contains() {
	local expected=$1 path=$2
	rg -F --quiet -- "$expected" "$path" || fail "expected ${path} to contain: ${expected}"
}

TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/home/.config/herdr-spreader" "$TEST_ROOT/home/.local/bin" "$TEST_ROOT/home/workspace/badaniya/NVO-20131/PlatformCommonModels" "$TEST_ROOT/home/workspace/badaniya/NVO-20131/.agents" "$TEST_ROOT/home/workspace/badaniya/master/PlatformCommonModels"
touch "$TEST_ROOT/home/workspace/badaniya/NVO-20131/.agents/.herdr-aggregate-context"
LOG="$TEST_ROOT/commands.log"

cat >"$TEST_ROOT/home/.config/herdr-spreader/nvo-harness-worktree-remove.sh" <<'EOF'
#!/usr/bin/env bash
printf 'remove-worktree %s\n' "$*" >>"${TEST_LOG:?}"
EOF
cat >"$TEST_ROOT/home/.local/bin/labctl" <<'EOF'
#!/usr/bin/env bash
printf 'labctl %s\n' "$*" >>"${TEST_LOG:?}"
[[ ${TEST_FAIL_DESTROY:-false} != true ]]
EOF
cat >"$TEST_ROOT/bin/sg" <<'EOF'
#!/usr/bin/env bash
[[ $1 == incus-admin && $2 == -c ]] || exit 2
printf 'sg %s\n' "$3" >>"${TEST_LOG:?}"
bash -c "$3"
EOF
cat >"$TEST_ROOT/bin/sudo" <<'EOF'
#!/usr/bin/env bash
printf 'sudo %s\n' "$*" >>"${TEST_LOG:?}"
exec "$@"
EOF
cat >"$TEST_ROOT/bin/git" <<'EOF'
#!/usr/bin/env bash
printf 'git %s\n' "$*" >>"${TEST_LOG:?}"
case "$3 $4" in
'worktree list') exit 0 ;;
'show-ref --verify' | 'branch -D') exit 0 ;;
*) exit 2 ;;
esac
EOF
cat >"$TEST_ROOT/bin/herdr" <<'EOF'
#!/usr/bin/env bash
printf 'herdr %s\n' "$*" >>"${TEST_LOG:?}"
case "$1 $2" in
'workspace list') printf '%s\n' '{"result":{"workspaces":[{"workspace_id":"w1","label":"NVO-20131 - Test"},{"workspace_id":"w2","label":"NVO-20132 - Other"}]}}' ;;
'workspace close') [[ $3 == w1 ]] ;;
*) exit 2 ;;
esac
EOF
chmod +x "$TEST_ROOT/bin/herdr"
chmod +x "$TEST_ROOT/home/.config/herdr-spreader/nvo-harness-worktree-remove.sh" "$TEST_ROOT/home/.local/bin/labctl" "$TEST_ROOT/bin/sg" "$TEST_ROOT/bin/sudo" "$TEST_ROOT/bin/git"

# Default removal must force cleanup, even without an explicit --force.
HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$PATH" TEST_LOG="$LOG" "$SCRIPT" NVO-20131
assert_contains 'labctl destroy NVO-20131 --yes' "$LOG"
assert_contains 'sudo chown -R' "$LOG"
assert_contains 'remove-worktree NVO-20131 --force' "$LOG"
assert_contains 'branch -D badaniya/PlatformCommonModels/NVO-20131' "$LOG"
[[ ! -d $TEST_ROOT/home/workspace/badaniya/NVO-20131/PlatformCommonModels ]] || fail 'unregistered orphan worktree was not removed'
[[ ! -e $TEST_ROOT/home/workspace/badaniya/NVO-20131 ]] || fail 'aggregate context residue was not removed'

# A previous partial forced cleanup can leave an orphaned branch after the
# ticket root itself was removed; retrying the action must clean that branch.
: >"$LOG"
HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$PATH" TEST_LOG="$LOG" "$SCRIPT" 'NVO-20131 --force'
assert_contains 'branch -D badaniya/PlatformCommonModels/NVO-20131' "$LOG"
if rg -F --quiet 'remove-worktree' "$LOG"; then
	fail 'missing ticket root attempted guarded worktree removal'
fi

# --keep-worktrees must destroy the sandbox and close its Herdr view, but leave
# all repository files, branches and aggregate context untouched (even if dirty).
project="$TEST_ROOT/home/workspace/badaniya/NVO-20131"
mkdir -p "$project/PlatformCommonModels" "$project/.agents"
printf 'uncommitted work\n' >"$project/PlatformCommonModels/local-changes"
touch "$project/.agents/.herdr-aggregate-context"
for form in single positional; do
	: >"$LOG"
	if [[ $form == single ]]; then
		HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$PATH" TEST_LOG="$LOG" "$SCRIPT" 'NVO-20131 --keep-worktrees'
	else
		HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$PATH" TEST_LOG="$LOG" "$SCRIPT" NVO-20131 --keep-worktrees
	fi
	assert_contains 'labctl destroy NVO-20131 --yes' "$LOG"
	assert_contains 'herdr workspace close w1' "$LOG"
	if rg -q '^(sudo |git |remove-worktree |herdr workspace close w2)' "$LOG"; then
		fail 'keep-worktrees modified Git/worktrees or closed an unrelated workspace'
	fi
	[[ -f $project/.agents/.herdr-aggregate-context && -f $project/PlatformCommonModels/local-changes ]] || fail 'kept worktree files were removed'
done

# Invalid/conflicting flags must fail before destroying anything.
for options in '--keep-sandbox' '--no-force' '--keep-worktrees --force' '--force --keep-worktrees'; do
	: >"$LOG"
	if HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$PATH" TEST_LOG="$LOG" "$SCRIPT" "NVO-20131 $options"; then
		fail "accepted invalid/conflicting flags: $options"
	fi
	[[ ! -s $LOG ]] || fail 'invalid flags ran destructive commands'
done

# Failed sandbox destruction must never proceed to cleanup or workspace closure.
for options in '' ' --keep-worktrees'; do
	: >"$LOG"
	if HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$PATH" TEST_LOG="$LOG" TEST_FAIL_DESTROY=true "$SCRIPT" "NVO-20131$options"; then
		fail 'sandbox destruction failure was ignored'
	fi
	if rg -q '^(sudo |git |remove-worktree |herdr )' "$LOG"; then
		fail 'failed destruction continued to cleanup'
	fi
done

: >"$LOG"
if HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$PATH" TEST_LOG="$LOG" "$SCRIPT" 'NVO-20131; rm -rf / --force'; then
	fail 'malformed ticket was accepted'
fi
[[ ! -s $LOG ]] || fail 'malformed ticket ran sandbox or worktree cleanup commands'
