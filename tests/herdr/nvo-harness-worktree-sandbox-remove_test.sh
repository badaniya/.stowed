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
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/home/.config/herdr-spreader" "$TEST_ROOT/home/.local/bin" "$TEST_ROOT/home/workspace/badaniya/NVO-20131/PlatformCommonModels" "$TEST_ROOT/home/workspace/badaniya/master/PlatformCommonModels"
LOG="$TEST_ROOT/commands.log"

cat >"$TEST_ROOT/home/.config/herdr-spreader/nvo-harness-worktree-remove.sh" <<'EOF'
#!/usr/bin/env bash
printf 'remove-worktree %s\n' "$*" >>"${TEST_LOG:?}"
EOF
cat >"$TEST_ROOT/home/.local/bin/labctl" <<'EOF'
#!/usr/bin/env bash
printf 'labctl %s\n' "$*" >>"${TEST_LOG:?}"
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
[[ $3 == worktree && $4 == list && $5 == --porcelain ]] || exit 2
EOF
chmod +x "$TEST_ROOT/home/.config/herdr-spreader/nvo-harness-worktree-remove.sh" "$TEST_ROOT/home/.local/bin/labctl" "$TEST_ROOT/bin/sg" "$TEST_ROOT/bin/sudo" "$TEST_ROOT/bin/git"

HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$PATH" TEST_LOG="$LOG" "$SCRIPT" 'NVO-20131 --force'
assert_contains 'labctl destroy NVO-20131 --yes' "$LOG"
assert_contains 'sudo chown -R' "$LOG"
assert_contains 'remove-worktree NVO-20131 --force' "$LOG"
[[ ! -d $TEST_ROOT/home/workspace/badaniya/NVO-20131/PlatformCommonModels ]] || fail 'unregistered orphan worktree was not removed'

: >"$LOG"
if HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$PATH" TEST_LOG="$LOG" "$SCRIPT" 'NVO-20131; rm -rf / --force'; then
	fail 'malformed ticket was accepted'
fi
[[ ! -s $LOG ]] || fail 'malformed ticket ran sandbox or worktree cleanup commands'
