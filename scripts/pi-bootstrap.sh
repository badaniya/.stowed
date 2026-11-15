#!/usr/bin/env bash
# Install or repair the per-machine managed Pi runtime.
#
# The pi.dev installer owns ~/.pi/agent/install and writes a versioned release
# (releases/<version>/node_modules) on each machine. That tree is generated and
# is not tracked in this repo, so a stowed config can arrive without a working
# runtime. The installer also trusts an existing release directory and skips
# installing into it, which leaves such a host broken while reporting success.
#
# Usage:
#   pi-bootstrap.sh [--check | --dry-run]
#
#   (none)     install or repair the runtime
#   --check    change nothing; exit non-zero unless the launcher runs
#   --dry-run  change nothing; report the detected state
set -euo pipefail

managed_root="${PI_MANAGED_INSTALL_ROOT:-$HOME/.pi/agent/install}"
launcher="${PI_LAUNCHER:-$HOME/.pi/agent/bin/pi}"
installer_url="${PI_INSTALLER_URL:-https://pi.dev/install.sh}"

die() {
  printf 'pi-bootstrap: %s\n' "$*" >&2
  exit 1
}

current_version=""
if [ -f "$managed_root/current-version" ]; then
  IFS= read -r current_version <"$managed_root/current-version" || true
fi
case "$current_version" in
  "" | . | .. | *[!0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz._+-]*)
    [ -z "$current_version" ] || die "invalid managed version: $current_version"
    ;;
esac

release_bin=""
if [ -n "$current_version" ]; then
  release_bin="$managed_root/releases/$current_version/node_modules/.bin/pi"
fi

state=ok
if [ -z "$current_version" ] || [ ! -d "$managed_root/releases/$current_version" ]; then
  state=no-release
elif [ ! -x "$release_bin" ]; then
  state=partial-release
fi

case "${1:-}" in
  --check)
    [ "$state" = ok ] || die "managed Pi is not runnable ($state, version=${current_version:-none})"
    "$launcher" --version >/dev/null 2>&1 || die "$launcher is not runnable"
    printf 'pi-bootstrap: ok (%s)\n' "$("$launcher" --version)"
    exit 0
    ;;
  --dry-run)
    printf 'pi-bootstrap: state=%s version=%s release=%s\n' \
      "$state" "${current_version:-none}" "${release_bin:-none}"
    exit 0
    ;;
  "" | --repair) ;;
  *) die "usage: pi-bootstrap.sh [--check|--dry-run]" ;;
esac

# A release directory without node_modules is the signature of a checkout that
# carried the manifests but not the installed runtime. Remove it first, or the
# installer discards its own staged install and exits while still broken.
if [ "$state" = partial-release ]; then
  printf 'pi-bootstrap: removing incomplete release %s\n' "$current_version"
  rm -rf "${managed_root:?}/releases/${current_version:?}"
fi

if "$launcher" --version >/dev/null 2>&1; then
  printf 'pi-bootstrap: already runnable (%s)\n' "$("$launcher" --version)"
  exit 0
fi

[ -n "$installer_url" ] || die "installer URL is empty"
printf 'pi-bootstrap: running the managed installer\n'
curl -fsSL "$installer_url" | sh

"$launcher" --version >/dev/null 2>&1 ||
  die "installer finished but $launcher is still not runnable"
printf 'pi-bootstrap: installed %s\n' "$("$launcher" --version)"
