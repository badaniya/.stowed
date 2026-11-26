#!/usr/bin/env bash
# shellcheck disable=SC2016 # Fixture command strings expand in the guest shell.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=/dev/null
source "$repo_root/incus/.local/lib/labctl/workspace.sh"
# shellcheck source=/dev/null
source "$repo_root/incus/.local/lib/labctl/network.sh"

temp_dir=$(mktemp -d)
trap 'rm -rf -- "$temp_dir"' EXIT
LABCTL_MASTER_ROOT="$temp_dir/master"
export MONOREPO_NAME=mono-repo
mkdir -p "$LABCTL_MASTER_ROOT"
fixture_root="$temp_dir/ticket with spaces"
mkdir -p "$fixture_root"

# Only the Incus boundary is replaced: execute the generated guest command
# locally against harmless Makefiles, retaining real workspace detection.
labctl_normalize_ticket() { printf '%s\n' "$1"; }
labctl_workspace_ticket_root() { printf '%s\n' "$fixture_root"; }
labctl_incus_instance_exists() { return 0; }
labctl_incus_is_running() { return 0; }
labctl_incus_workspace_is_mounted() { return 0; }
labctl_incus_stack_command() {
  printf 'guest-call\n' >> "$temp_dir/calls"
  (cd "$2" && bash -euo pipefail -c "$3")
}
export TRACE="$temp_dir/trace"
export FAIL_TARGET=''
export LABCTL_MONO_STAGE_SHARED_COMMAND='printf "shared\n" >> "$TRACE" # private stage override'
# Project-specific stages and shutdown have no defaults; configure generic ones.
export LABCTL_MONO_STAGE_DB_COMMAND='cd database/scripts/development && make setup-db'
export LABCTL_MONO_STAGE_PLATFORM_BUILD_COMMAND='cd platform/scripts/development && make build-platform'
export LABCTL_MONO_STAGE_PLATFORM_START_COMMAND='cd platform/scripts/development && make start-platform'
export LABCTL_MONO_STAGE_APP_INFRA_COMMAND='cd app/scripts/development && make start-infra'
export LABCTL_MONO_STAGE_APP_BUILD_COMMAND='cd app/scripts/development && make build'
export LABCTL_MONO_STAGE_APP_SERVICES_COMMAND='cd app/scripts/development && make start-services'
export LABCTL_MONO_STACK_DOWN_COMMAND='make -C app/scripts/development stop-all && make -C platform/scripts/development stop-platform'
export LABCTL_STACK_UP_COMMAND='printf "legacy\n" >> "$TRACE"'
export LABCTL_STACK_DOWN_COMMAND='printf "legacy-down\n" >> "$TRACE"'
export LABCTL_STACK_HEALTH_COMMAND='printf "legacy-health\n" >> "$TRACE"'
unset LABCTL_MONO_STACK_UP_COMMAND LABCTL_MONO_STACK_HEALTH_COMMAND
mono_stack_down=$LABCTL_MONO_STACK_DOWN_COMMAND

# A harmless Docker executable verifies the default monorepo health command.
mkdir -p "$temp_dir/bin"
printf '%s\n' '#!/usr/bin/env bash' '[[ $* == info ]] || exit 1' \
  'printf "docker-health\n" >> "$TRACE"' > "$temp_dir/bin/docker"
chmod +x "$temp_dir/bin/docker"
export PATH="$temp_dir/bin:$PATH"

make_fixture() {
  local mono=$1 dir component
  for dir in database/scripts/development platform/scripts/development app/scripts/development; do
    component=${dir%/scripts/development}
    component=${component##*/}
    mkdir -p "$mono/$dir"
    printf '%s\n' "COMPONENT=$component" \
      'setup-db build-platform start-platform start-infra build start-services stop-all stop-platform:' \
      $'\t@test "$(FAIL_TARGET)" != "$@"' \
      $'\t@printf "%s:%s\\n" "$(COMPONENT)" "$@" >> "$$TRACE"' > "$mono/$dir/Makefile"
  done
}
expected=$'shared\ndatabase:setup-db\nplatform:build-platform\nplatform:start-platform\napp:start-infra\napp:build\napp:start-services'

# Missing monorepo dispatch, wrong paths, leaked cd between stages, and duplicate
# guest calls all fail these assertions. Test both supported monorepo layouts.
for layout in . mono-repo; do
  rm -rf -- "$fixture_root"
  mkdir -p "$fixture_root/$layout"
  printf 'gitdir: %s\n' "$LABCTL_MASTER_ROOT/worktrees/fixture" > "$fixture_root/$layout/.git"
  make_fixture "$fixture_root/$layout"
  : > "$TRACE"
  : > "$temp_dir/calls"
  labctl_stack_up fixture
  [[ $(<"$TRACE") == "$expected" ]] || {
    printf 'FAIL: %s startup did not run monorepo stages in order; got:\n%s\n' "$layout" "$(<"$TRACE")" >&2
    exit 1
  }
  [[ $(<"$temp_dir/calls") == guest-call ]] || {
    printf 'FAIL: startup must use one guest invocation\n' >&2
    exit 1
  }
  : > "$TRACE"
  labctl_stack_down fixture
  [[ $(<"$TRACE") == $'app:stop-all\nplatform:stop-platform' ]] || {
    printf 'FAIL: %s shutdown used the wrong layout or order\n' "$layout" >&2
    exit 1
  }
  : > "$TRACE"
  labctl_stack_health fixture
  [[ $(<"$TRACE") == docker-health ]] || {
    printf 'FAIL: %s health used the legacy workspace hook\n' "$layout" >&2
    exit 1
  }

  # Full private lifecycle overrides run relative to the detected monorepo.
  for action in up down health; do
    key="LABCTL_MONO_STACK_${action^^}_COMMAND"
    printf -v "$key" '%s' 'test -d app/scripts/development && printf "override\n" >> "$TRACE"'
    : > "$TRACE"
    "labctl_stack_$action" fixture
    [[ $(<"$TRACE") == override ]] || {
      printf 'FAIL: %s override was ignored or ran from the wrong cwd\n' "$action" >&2
      exit 1
    }
    unset "$key"
  done
  LABCTL_MONO_STACK_DOWN_COMMAND=$mono_stack_down
done

# A failed stage must stop later stages even when startup is used in an if.
: > "$TRACE"
FAIL_TARGET=build-platform
if labctl_stack_up fixture; then
  printf 'FAIL: startup swallowed a stage failure\n' >&2
  exit 1
fi
[[ $(<"$TRACE") == $'shared\ndatabase:setup-db' ]] || {
  printf 'FAIL: startup continued after a failed stage\n' >&2
  exit 1
}
FAIL_TARGET=''

# Non-monorepo workspaces keep the configured private hook unchanged.
rm -f -- "$fixture_root/mono-repo/.git"
: > "$TRACE"
labctl_stack_up fixture
[[ $(<"$TRACE") == legacy ]] || {
  printf 'FAIL: legacy startup hook changed\n' >&2
  exit 1
}
: > "$TRACE"
labctl_stack_down fixture
labctl_stack_health fixture
[[ $(<"$TRACE") == $'legacy-down\nlegacy-health' ]] || {
  printf 'FAIL: legacy shutdown/health hooks changed\n' >&2
  exit 1
}
printf 'PASS: monorepo lifecycle paths, ordering, overrides, failures, and legacy hooks\n'
