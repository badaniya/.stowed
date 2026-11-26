#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../.local/lib/labctl/network.sh
source "$repo_root/incus/.local/lib/labctl/network.sh"
unset LABCTL_MONO_STAGE_SHARED_COMMAND
root=$(mktemp -d)
trap 'rm -rf -- "$root"' EXIT
export TEST_DEP_BIN="$root/tools" TEST_PACKAGE_LOG="$root/packages.log" TEST_GOPATH="$root/go"
mkdir -p "$TEST_DEP_BIN"
bash_binary=$(command -v bash)
# An isolated PATH genuinely lacks file; package installation is the only
# external operation substituted. It cannot reach the host package manager.
for tool in bash mkdir chmod; do ln -s "$(command -v "$tool")" "$TEST_DEP_BIN/$tool"; done
cat >"$TEST_DEP_BIN/go" <<'GO'
#!/usr/bin/env bash
[[ $* == 'env GOPATH' ]] || exit 2
printf '%s\n' "$TEST_GOPATH"
GO
cat >"$TEST_DEP_BIN/sudo" <<'SUDO'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$TEST_PACKAGE_LOG"
[[ ${TEST_PACKAGE_FAIL:-false} != true ]] || exit 42
case "$*" in
'apt-get update') ;;
'apt-get install -y --no-install-recommends file')
  printf '#!/bin/sh\nexit 0\n' >"$TEST_DEP_BIN/file"
  chmod +x "$TEST_DEP_BIN/file"
  ;;
*) exit 2 ;;
esac
SUDO
chmod +x "$TEST_DEP_BIN/go" "$TEST_DEP_BIN/sudo"
shared=$(labctl_mono_stage_command shared)
PATH="$TEST_DEP_BIN" "$bash_binary" -euo pipefail -c "$shared"
[[ -x $TEST_DEP_BIN/file && -d $TEST_GOPATH/bin ]] || {
  printf 'FAIL: shared preparation must provide file and the per-user Go-bin directory\n' >&2
  exit 1
}
expected=$'apt-get update\napt-get install -y --no-install-recommends file'
[[ $(<"$TEST_PACKAGE_LOG") == "$expected" ]] || {
  printf 'FAIL: dependency preparation used unexpected package-manager commands\n' >&2
  exit 1
}
# Existing tools must not trigger package-manager operations on every bootstrap.
PATH="$TEST_DEP_BIN" "$bash_binary" -euo pipefail -c "$shared"
[[ $(<"$TEST_PACKAGE_LOG") == "$expected" ]] || {
  printf 'FAIL: repeated preparation reinstalled an existing dependency\n' >&2
  exit 1
}
rm "$TEST_DEP_BIN/file"
export TEST_GOPATH="$root/failed-go" TEST_PACKAGE_FAIL=true
if PATH="$TEST_DEP_BIN" "$bash_binary" -euo pipefail -c "$shared"; then
  printf 'FAIL: package installation failure was ignored\n' >&2
  exit 1
fi
[[ ! -e $TEST_GOPATH/bin ]] || {
  printf 'FAIL: preparation continued after package-manager failure\n' >&2
  exit 1
}
printf 'PASS: shared mono dependencies, idempotency, and installation failure propagation\n'
