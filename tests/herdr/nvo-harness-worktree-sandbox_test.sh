#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="${REPO_ROOT}/herdr/.config/herdr-spreader/nvo-harness-worktree-sandbox.sh"

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
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/home/.config/herdr-spreader" "$TEST_ROOT/home/.local/bin"
LOG="$TEST_ROOT/commands.log"

cat >"$TEST_ROOT/home/.config/herdr-spreader/nvo-harness-worktree.sh" <<'EOF'
#!/usr/bin/env bash
printf 'worktree %s\n' "$*" >>"${TEST_LOG:?}"
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
chmod +x "$TEST_ROOT/home/.config/herdr-spreader/nvo-harness-worktree.sh" "$TEST_ROOT/home/.local/bin/labctl" "$TEST_ROOT/bin/sg"

HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$PATH" TEST_LOG="$LOG" "$SCRIPT" 'NVO-20131 25.16.0 --restore-harness'
assert_contains 'worktree NVO-20131 25.16.0 --restore-harness' "$LOG"
assert_contains 'labctl credential sync NVO-20131' "$LOG"
assert_contains 'labctl bootstrap NVO-20131' "$LOG"

: >"$LOG"
if HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$PATH" TEST_LOG="$LOG" "$SCRIPT" 'NVO-20131; rm -rf / 25.16.0'; then
	fail 'malformed ticket was accepted'
fi
[[ ! -s $LOG ]] || fail 'malformed ticket ran worktree or labctl commands'
