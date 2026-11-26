#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
temp_dir=$(mktemp -d)
trap 'rm -rf -- "$temp_dir"' EXIT
source_file=$temp_dir/private-profile
rendered=$temp_dir/sandbox.env

cat >"$source_file" <<'PROFILE'
###############################################################################
# App Development
###############################################################################
# This comment is part of the App Development section.
export APP_BUS_PORT=9093
export APP_GRPC_PORT=50051
export APP_PAGE_LIMIT=100
export DBAUTOMIGRATE=true
export DBLOGLEVEL="info"
export APP_UI_TOKEN=host-only-secret
export APP_BUS_HOST=192.0.2.1
export APP_INSTANCE=ignored
###############################################################################
# Unrelated section
###############################################################################
export SHOULD_NOT_RENDER=true
PROFILE
chmod 600 "$source_file"

labctl_die() {
  printf 'labctl: %s\n' "$*" >&2
  return 1
}

labctl_incus_instance_ip() { printf '%s\n' '10.77.10.11'; }
labctl_config_is_ipv4() { [[ $1 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; }

# shellcheck source=../.local/lib/labctl/monorepo-env.sh
source "$repo_root/incus/.local/lib/labctl/monorepo-env.sh"
export LABCTL_INSTANCE_USER=sandbox-user
LABCTL_MONOREPO_ENV_SOURCE_PATH=$source_file
LABCTL_MONOREPO_ENV_SECTION='App Development'
LABCTL_MONOREPO_ENV_ALLOWED='APP_BUS_PORT APP_GRPC_PORT APP_PAGE_LIMIT DBAUTOMIGRATE DBLOGLEVEL'
LABCTL_MONOREPO_ENV_SKIPPED='APP_UI_TOKEN'
LABCTL_MONOREPO_ENV_HOST_IP_VARS='APP_HOST_IP APP_BUS_HOST'
LABCTL_MONOREPO_ENV_INSTANCE_ID_VAR='APP_INSTANCE'
LABCTL_MONOREPO_ENV_FIXED='APP_THREAD_POOL=100'

labctl_monorepo_env_render abc-123 "$rendered"

assert_export() {
  local expected=$1
  rg -Fx --quiet -- "$expected" "$rendered" || {
    printf 'expected rendered environment to contain: %s\n' "$expected" >&2
    exit 1
  }
}

assert_absent() {
  if rg -F --quiet -- "$1" "$rendered"; then
    printf 'rendered unexpected environment entry: %s\n' "$1" >&2
    exit 1
  fi
}

assert_export "export APP_BUS_PORT='9093'"
assert_export "export APP_GRPC_PORT='50051'"
assert_export "export APP_PAGE_LIMIT='100'"
assert_export "export DBAUTOMIGRATE='true'"
assert_export "export DBLOGLEVEL='info'"
assert_export "export APP_HOST_IP='10.77.10.11'"
assert_export "export APP_BUS_HOST='10.77.10.11'"
assert_export "export APP_INSTANCE='sandbox-user:$(hostname):10.77.10.11'"
assert_export "export APP_THREAD_POOL='100'"
assert_absent 'SHOULD_NOT_RENDER'
assert_absent 'host-only-secret'
assert_absent '192.0.2.1'
assert_absent 'ignored'

expect_failure() {
  local description=$1 expected=$2 output
  if output=$(labctl_monorepo_env_render abc-123 "$temp_dir/failed.env" 2>&1); then
    printf 'FAIL: %s must be rejected\n' "$description" >&2
    exit 1
  fi
  [[ $output == *"$expected"* ]] || {
    printf 'FAIL: %s: expected error containing %s, got: %s\n' "$description" "$expected" "$output" >&2
    exit 1
  }
}

# Variables outside the configured lists are refused.
(
  LABCTL_MONOREPO_ENV_ALLOWED='APP_BUS_PORT'
  expect_failure 'an unapproved variable' 'unapproved monorepo environment variable: APP_GRPC_PORT'
)
# Section and allowlist are required configuration.
(
  LABCTL_MONOREPO_ENV_SECTION=
  expect_failure 'a missing section setting' 'set LABCTL_MONOREPO_ENV_SECTION'
)
(
  LABCTL_MONOREPO_ENV_SECTION='Missing Section'
  expect_failure 'an absent profile section' 'section is missing: Missing Section'
)
(
  # shellcheck disable=SC2016 # the literal command substitution must be rejected
  LABCTL_MONOREPO_ENV_FIXED='BAD=$(id)'
  expect_failure 'an unsafe fixed pair' 'invalid LABCTL_MONOREPO_ENV_FIXED entry'
)
(
  chmod 644 "$source_file"
  expect_failure 'a group-readable profile' 'must not be group- or world-accessible'
)

printf 'PASS: monorepo environment rendering\n'
