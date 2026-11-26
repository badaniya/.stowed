#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../.local/lib/labctl/network.sh
source "$repo_root/incus/.local/lib/labctl/network.sh"
declare -F labctl_die >/dev/null || labctl_die() {
  printf 'labctl: %s\n' "$*" >&2
  return 1
}

# Catch malformed generated commands and override handling without running
# Incus, Docker, credentials, or any real application's Makefile.
stages=(db platform-build platform-start app-build app-infra app-services)
for name in shared "${stages[@]}"; do
  name=${name^^}
  unset "LABCTL_MONO_STAGE_${name//-/_}_COMMAND"
done

failures=0
fail() {
  printf 'FAIL: %s\n' "$*" >&2
  failures=$((failures + 1))
}

# Only the shared stage has a built-in default; it must be valid Bash.
command=$(labctl_mono_stage_command shared)
bash -n -c "$command" || fail 'default shared command must be valid Bash'

# Project-specific stages have no default and must name the missing setting.
for stage in "${stages[@]}"; do
  name=${stage^^}
  name="LABCTL_MONO_STAGE_${name//-/_}_COMMAND"
  if error=$(labctl_mono_stage_command "$stage" 2>&1); then
    fail "unconfigured $stage stage must fail"
  elif [[ $error != *"$name"* ]]; then
    fail "unconfigured $stage stage must name $name (got: $error)"
  fi
done

# Configured commands are returned verbatim, without a default-command suffix.
for stage in shared "${stages[@]}"; do
  name=${stage^^}
  name="LABCTL_MONO_STAGE_${name//-/_}_COMMAND"
  printf -v "$name" '%s' "printf '%s\\n' 'custom $stage'"
  command=$(labctl_mono_stage_command "$stage") || fail "configured $stage stage failed"
  [[ $command == "${!name}" ]] || fail "$stage override must be returned unchanged"
  [[ $(bash -c "$command") == "custom $stage" ]] || fail "$stage override did not run"
  unset "$name"
done

# Unknown and retired stage names are rejected.
for stage in unknown legacy-db legacy-infra legacy-build; do
  if labctl_mono_stage_command "$stage" >/dev/null 2>&1; then
    fail "stage $stage must be rejected"
  fi
done

((failures == 0)) || exit 1
printf 'PASS: monorepo stage defaults, required configuration and overrides\n'
