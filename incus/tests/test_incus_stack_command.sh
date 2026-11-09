#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
temp_dir=$(mktemp -d)
trap 'rm -rf -- "$temp_dir"' EXIT
captured_helper=$temp_dir/stack-wrapper

# shellcheck source=../.local/lib/labctl/common.sh
source "$repo_root/incus/.local/lib/labctl/common.sh"
# shellcheck source=../.local/lib/labctl/incus.sh
source "$repo_root/incus/.local/lib/labctl/incus.sh"

export LABCTL_GIT_CREDENTIAL_NAME=git-module-token
export LABCTL_GIT_HOST=github.extremenetworks.com
export LABCTL_INSTANCE_USER=badaniya

labctl_run() {
  cat >"$captured_helper"
}

labctl_incus_stack_command test-instance /workspace 'make start-services'

assert_contains() {
  local expected=$1
  rg -F --quiet -- "$expected" "$captured_helper" || {
    printf 'expected stack wrapper to contain: %s\n' "$expected" >&2
    exit 1
  }
}

assert_contains 'user_uid=$(id -u "$instance_user")'
assert_contains 'setpriv --reuid "$user_uid"'
assert_contains 'HOME="/home/$instance_user"'
assert_contains 'USER="$instance_user"'
assert_contains 'LABCTL_GIT_CREDENTIAL_FILE'
assert_contains 'bash -lc "$stack_command"'

printf 'PASS: stack command runs as sandbox user\n'
