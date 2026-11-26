#!/usr/bin/env bash
set -euo pipefail

TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

failures=0

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	failures=$((failures + 1))
}

assert_equals() {
	local expected=$1 actual=$2
	if [[ $expected != "$actual" ]]; then
		fail "expected [$expected], got [$actual]"
	fi
}

assert_fails() {
	if "$@"; then
		fail "expected command to fail: $*"
	fi
}

assert_succeeds() {
	if ! "$@"; then
		fail "expected command to succeed: $*"
	fi
}

finish_tests() {
	if ((failures > 0)); then
		printf '%d test assertion(s) failed\n' "$failures" >&2
		return 1
	fi
	printf 'All tests passed\n'
}
