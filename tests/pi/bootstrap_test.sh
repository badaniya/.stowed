#!/usr/bin/env bash
# Exercise the Pi runtime bootstrap without touching the real install or network.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
BOOTSTRAP="$REPO_ROOT/scripts/pi-bootstrap.sh"

TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

export PI_MANAGED_INSTALL_ROOT="$TEST_ROOT/home/.pi/agent/install"
export PI_LAUNCHER="$TEST_ROOT/home/.pi/agent/bin/pi"
export PI_INSTALLER_URL="file://$TEST_ROOT/fake-installer.sh"
export INSTALLER_LOG="$TEST_ROOT/installer.log"
export FAKE_VERSION=1.9.9

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

installer_runs() {
	if [ -f "$INSTALLER_LOG" ]; then
		wc -l <"$INSTALLER_LOG" | tr -d ' '
	else
		printf '0\n'
	fi
}

assert_eq() {
	[ "$1" = "$2" ] || fail "$3 (got '$1', want '$2')"
}

# Stand-in for https://pi.dev/install.sh: writes the same release layout and a
# launcher that refuses to run when the release payload is missing.
cat >"$TEST_ROOT/fake-installer.sh" <<'EOF'
#!/bin/sh
printf 'run\n' >>"$INSTALLER_LOG"
release="$PI_MANAGED_INSTALL_ROOT/releases/$FAKE_VERSION"
mkdir -p "$release/node_modules/.bin" "$(dirname "$PI_LAUNCHER")"
printf '%s\n' "$FAKE_VERSION" >"$PI_MANAGED_INSTALL_ROOT/current-version"
cat >"$release/node_modules/.bin/pi" <<NESTED
#!/bin/sh
printf '%s\n' "$FAKE_VERSION"
NESTED
chmod +x "$release/node_modules/.bin/pi"
cat >"$PI_LAUNCHER" <<NESTED
#!/bin/sh
version=\$(cat "$PI_MANAGED_INSTALL_ROOT/current-version") || exit 1
[ -x "$PI_MANAGED_INSTALL_ROOT/releases/\$version/node_modules/.bin/pi" ] || exit 1
printf '%s\n' "$FAKE_VERSION"
NESTED
chmod +x "$PI_LAUNCHER"
EOF

# Fresh machine: nothing installed yet.
bash "$BOOTSTRAP" >/dev/null
assert_eq "$(installer_runs)" 1 'fresh install should run the installer once'
assert_eq "$("$PI_LAUNCHER" --version)" "$FAKE_VERSION" 'fresh install should produce a runnable launcher'

# Healthy machine: repair must not reinstall.
bash "$BOOTSTRAP" >/dev/null
assert_eq "$(installer_runs)" 1 'healthy runtime should not reinstall'

# Config-only checkout: release manifests exist, node_modules does not.
rm -rf "$PI_MANAGED_INSTALL_ROOT/releases/$FAKE_VERSION/node_modules"
dry_run=$(bash "$BOOTSTRAP" --dry-run)
case "$dry_run" in
*state=partial-release*) ;;
*) fail "partial release was not detected: $dry_run" ;;
esac
if bash "$BOOTSTRAP" --check >/dev/null 2>&1; then
	fail '--check passed on a partial release'
fi
bash "$BOOTSTRAP" >/dev/null
assert_eq "$(installer_runs)" 2 'partial release should be removed and reinstalled'
[ -x "$PI_MANAGED_INSTALL_ROOT/releases/$FAKE_VERSION/node_modules/.bin/pi" ] ||
	fail 'repaired release has no executable'

# Stale current-version pointing at a release that was never installed.
printf '2.0.0\n' >"$PI_MANAGED_INSTALL_ROOT/current-version"
bash "$BOOTSTRAP" >/dev/null
assert_eq "$(installer_runs)" 3 'missing release should trigger an install'

# Corrupt version file must fail loudly instead of being used in a path.
printf '../../evil\n' >"$PI_MANAGED_INSTALL_ROOT/current-version"
if bash "$BOOTSTRAP" >/dev/null 2>&1; then
	fail 'invalid version was accepted'
fi

printf '%s\n' "$FAKE_VERSION" >"$PI_MANAGED_INSTALL_ROOT/current-version"
bash "$BOOTSTRAP" --check >/dev/null || fail '--check failed on a healthy runtime'

printf 'pi-bootstrap tests passed\n'
