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

assert_failure() {
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
assert_failure "no common writable host identity"

printf 'PASS: workspace identity resolution\n'
