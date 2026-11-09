#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
temp_dir=$(mktemp -d)
trap 'rm -rf -- "$temp_dir"' EXIT
source_file=$temp_dir/private-profile
rendered=$temp_dir/sandbox.env

cat >"$source_file" <<'PROFILE'
###############################################################################
# NVO Development
###############################################################################
# This comment is part of the NVO Development section.
export NVO_MessageBusHost=127.0.0.1
export NVO_MessageBusPort=9093
export XIQ_MessageBusPort=9092
export CapWap_GrpcPort=50051
export XiqGrpcGetDevicesPerPageLimit=100
export DBAUTOMIGRATE=true
export DBLOGLEVEL=info
export EnableWirelessDeviceOnboardingAndKafkaMessaging=true
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

# shellcheck source=../.local/lib/labctl/nvo-env.sh
source "$repo_root/incus/.local/lib/labctl/nvo-env.sh"
LABCTL_NVO_ENV_SOURCE_PATH=$source_file
export LABCTL_INSTANCE_USER=badaniya

labctl_nvo_env_render nvo-20130 "$rendered"

assert_export() {
  local expected=$1
  rg -Fx --quiet -- "$expected" "$rendered" || {
    printf 'expected rendered environment to contain: %s\n' "$expected" >&2
    exit 1
  }
}

assert_export "export NVO_MessageBusHost='127.0.0.1'"
assert_export "export NVO_MessageBusPort='9093'"
assert_export "export XIQ_MessageBusPort='9092'"
assert_export "export CapWap_GrpcPort='50051'"
assert_export "export XiqGrpcGetDevicesPerPageLimit='100'"
assert_export "export DBAUTOMIGRATE='true'"
assert_export "export DBLOGLEVEL='info'"
assert_export "export EnableWirelessDeviceOnboardingAndKafkaMessaging='true'"
assert_export "export XIQ_HOST_IP='10.77.10.11'"
assert_export "export XIQ_MessageBusHost='10.77.10.11'"
assert_export "export CapWap_GrpcHost='10.77.10.11'"
if rg -F --quiet -- 'SHOULD_NOT_RENDER' "$rendered"; then
  printf 'rendered unrelated environment entry\n' >&2
  exit 1
fi

printf 'PASS: NVO environment rendering\n'
