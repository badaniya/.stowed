#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
temp_dir=$(mktemp -d)
stub_dir=$temp_dir/stubs
metadata_file=$temp_dir/stat-metadata
mkdir -p "$stub_dir"
trap 'rm -rf -- "$temp_dir"' EXIT

cat >"$stub_dir/stat" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
path=${!#}
while IFS=$'\t' read -r fixture_path uid gid mode; do
  if [[ $fixture_path == "$path" ]]; then
    printf '%s %s %s\n' "$uid" "$gid" "$mode"
    exit 0
  fi
done <"$LABCTL_TEST_STAT_METADATA"
printf 'unknown stat path: %s\n' "$path" >&2
exit 1
SCRIPT

cat >"$stub_dir/getent" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
[[ $1 == passwd ]] || exit 2
case $2 in
0) printf 'root:x:0:0:root:/root:/bin/bash\n' ;;
1000) printf 'badaniya:x:1000:1000:Badaniya:/home/badaniya:/bin/bash\n' ;;
1001) printf 'developer:x:1001:1001:Developer:/home/developer:/bin/bash\n' ;;
1002) printf 'reviewer:x:1002:1002:Reviewer:/home/reviewer:/bin/bash\n' ;;
*) exit 2 ;;
esac
SCRIPT

cat >"$stub_dir/id" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
[[ $1 == -G ]] || exit 2
case $2 in
badaniya) printf '1000\n' ;;
developer) printf '1001\n' ;;
reviewer) printf '1002\n' ;;
*) exit 1 ;;
esac
SCRIPT
chmod +x "$stub_dir/stat" "$stub_dir/getent" "$stub_dir/id"

# shellcheck source=../.local/lib/labctl/common.sh
source "$repo_root/incus/.local/lib/labctl/common.sh"
# shellcheck source=../.local/lib/labctl/incus.sh
source "$repo_root/incus/.local/lib/labctl/incus.sh"

assert_identity() {
  local expected_user=$1 expected_uid=$2 expected_gid=$3 actual
  if ! actual=$(labctl_incus_resolve_workspace_identity "$LABCTL_MASTER_ROOT" "$ticket_root"); then
    printf 'expected identity %s:%s:%s, resolver failed\n' "$expected_user" "$expected_uid" "$expected_gid" >&2
    return 1
  fi
  [[ $actual == "$expected_user"$'\n'"$expected_uid"$'\n'"$expected_gid" ]] || {
    printf 'expected identity %s:%s:%s, got %q\n' "$expected_user" "$expected_uid" "$expected_gid" "$actual" >&2
    return 1
  }
}

assert_resolver_failure() {
  local expected_message=$1 output error_file=$temp_dir/resolver-error
  if output=$(labctl_incus_resolve_workspace_identity "$LABCTL_MASTER_ROOT" "$ticket_root" 2>"$error_file"); then
    printf 'expected resolver failure, got %q\n' "$output" >&2
    return 1
  fi
  [[ -z $output ]] || {
    printf 'resolver emitted identity on failure: %q\n' "$output" >&2
    return 1
  }
  rg -F --quiet -- "$expected_message" "$error_file" || {
    printf 'expected failure message %q, got:\n' "$expected_message" >&2
    cat "$error_file" >&2
    return 1
  }
}

set_fixture() {
  local master_uid=$1 master_gid=$2 master_mode=$3 ticket_uid=$4 ticket_gid=$5 ticket_mode=$6
  local fixture_dir=$temp_dir/fixture-$RANDOM
  LABCTL_MASTER_ROOT=$fixture_dir/master
  ticket_root=$fixture_dir/ticket
  mkdir -p "$LABCTL_MASTER_ROOT" "$ticket_root"
  printf '%s\t%s\t%s\t%s\n%s\t%s\t%s\t%s\n' \
    "$LABCTL_MASTER_ROOT" "$master_uid" "$master_gid" "$master_mode" \
    "$ticket_root" "$ticket_uid" "$ticket_gid" "$ticket_mode" >"$metadata_file"
}

export PATH="$stub_dir:$PATH"
export LABCTL_TEST_STAT_METADATA=$metadata_file

# An owner candidate with write/search access to both roots wins.
set_fixture 1000 1000 0750 1000 1000 0750
assert_identity "badaniya" "1000" "1000"

# With distinct root owners, a candidate granted group w+x to both roots wins.
set_fixture 1001 1001 0770 1002 1001 0770
assert_identity "developer" "1001" "1001"

# No common non-root writable identity returns nonzero and does not emit one.
set_fixture 0 0 0700 1002 1002 0700
assert_resolver_failure "no common writable host identity"

captured_run=()
labctl_run() {
  captured_run=("$@")
}

assert_contains() {
  local expected=$1
  [[ $guest_command == *"$expected"* ]] || {
    printf 'expected guest command to contain %q, got:\n%s\n' "$expected" "$guest_command" >&2
    return 1
  }
}

assert_not_contains() {
  local unexpected=$1
  [[ $guest_command != *"$unexpected"* ]] || {
    printf 'expected guest command not to contain %q, got:\n%s\n' "$unexpected" "$guest_command" >&2
    return 1
  }
}

capture_guest_command() {
  local username=$1 uid=$2 gid=$3
  captured_run=()
  labctl_incus_ensure_instance_user test-instance "$username" "$uid" "$gid"
  guest_command=${captured_run[6]:-}
  [[ -n $guest_command ]] || {
    printf 'expected guest reconciliation command to be captured\n' >&2
    return 1
  }
}

assert_failure() {
  local expected_message=$1 error_file=$temp_dir/guest-error
  : >"$temp_dir/account-mutations"
  if PATH="$stub_dir:$PATH" LABCTL_TEST_GUEST_STATE=mismatched LABCTL_TEST_MUTATIONS="$temp_dir/account-mutations" \
    bash -c "$guest_command" -- badaniya 1000 1000 2>"$error_file"; then
    printf 'expected guest reconciliation command to fail\n' >&2
    return 1
  fi
  rg -F --quiet -- "$expected_message" "$error_file" || {
    printf 'expected failure message %q, got:\n' "$expected_message" >&2
    cat "$error_file" >&2
    return 1
  }
  [[ ! -s $temp_dir/account-mutations ]] || {
    printf 'guest reconciliation mutated accounts before failing:\n' >&2
    cat "$temp_dir/account-mutations" >&2
    return 1
  }
}

assert_mutations() {
  local expected=$1 actual
  actual=$(<"$temp_dir/account-mutations")
  [[ $actual == "$expected" ]] || {
    printf 'expected account mutations:\n%s\ngot:\n%s\n' "$expected" "$actual" >&2
    return 1
  }
}

run_guest_scenario() {
  local state=$1 username=$2 uid=$3 gid=$4
  : >"$temp_dir/account-mutations"
  PATH="$stub_dir:$PATH" LABCTL_TEST_GUEST_STATE="$state" LABCTL_TEST_MUTATIONS="$temp_dir/account-mutations" \
    bash -c "$guest_command" -- "$username" "$uid" "$gid"
}

cat >"$stub_dir/id" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
case "${LABCTL_TEST_GUEST_STATE:-}" in
mismatched)
  case "$1:$2" in
  -u:badaniya) printf '1001\n' ;;
  -g:badaniya) printf '1001\n' ;;
  *) exit 1 ;;
  esac
  ;;
ubuntu-1000)
  case "$1:$2" in
  -u:ubuntu|-g:ubuntu) printf '1000\n' ;;
  *) exit 1 ;;
  esac
  ;;
*) exit 1 ;;
esac
SCRIPT
cat >"$stub_dir/getent" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
case "${LABCTL_TEST_GUEST_STATE:-}:$1:$2" in
mismatched:passwd:badaniya) printf 'badaniya:x:1001:1001:Badaniya:/home/badaniya:/bin/bash\n' ;;
ubuntu-1000:passwd:ubuntu) printf 'ubuntu:x:1000:1000:Ubuntu:/home/ubuntu:/bin/bash\n' ;;
ubuntu-1000:group:ubuntu) printf 'ubuntu:x:1000:\n' ;;
ubuntu-1000:group:sudo|ubuntu-1000:group:docker|fresh-1001:group:sudo|fresh-1001:group:docker) printf '%s:x:1:\n' "$2" ;;
*) exit 2 ;;
esac
SCRIPT
for command in useradd usermod groupadd groupmod; do
  cat >"$stub_dir/$command" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
{
  printf '%s' "$(basename "$0")"
  printf ' %s' "$@"
  printf '\n'
} >>"$LABCTL_TEST_MUTATIONS"
SCRIPT
  chmod +x "$stub_dir/$command"
done
cat >"$stub_dir/install" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT
chmod +x "$stub_dir/id" "$stub_dir/getent" "$stub_dir/install"

# Ubuntu at 1000:1000 is renamed, its home moved, then its primary group and memberships are reconciled.
rename_user=labctl-test-renamed-user
capture_guest_command "$rename_user" 1000 1000
run_guest_scenario ubuntu-1000 "$rename_user" 1000 1000
assert_mutations "usermod --login $rename_user --home /home/$rename_user --move-home ubuntu
groupmod --new-name $rename_user ubuntu
usermod --append --groups sudo,docker $rename_user"

# A vacant 1001:1001 identity creates its primary group before its user, then reconciles memberships.
created_user=labctl-test-created-user
capture_guest_command "$created_user" 1001 1001
run_guest_scenario fresh-1001 "$created_user" 1001 1001
assert_mutations "groupadd --gid 1001 $created_user
useradd --uid 1001 --gid 1001 --create-home --shell /bin/bash $created_user
usermod --append --groups sudo,docker $created_user"

# A mismatched existing identity is rejected before any account mutation.
capture_guest_command badaniya 1000 1000
assert_failure "recreate the sandbox"

printf 'PASS: workspace identity resolution and guest provisioning\n'
