#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../.local/lib/labctl/network.sh
source "$repo_root/incus/.local/lib/labctl/network.sh"
unset LABCTL_MONO_STAGE_SHARED_COMMAND LABCTL_MONO_STAGE_PCM_DB_COMMAND

temp_dir=$(mktemp -d)
trap 'rm -rf -- "$temp_dir"' EXIT
mkdir -p "$temp_dir/tools" "$temp_dir/workspace/ngxcp/PlatformCommonModels/scripts/development"
export TEST_GOPATH="$temp_dir/go path"
# Only Go's environment lookup is substituted; the generated shell command,
# directory creation, PATH resolution and make invocation are exercised for real.
cat >"$temp_dir/tools/go" <<'GO'
#!/usr/bin/env bash
set -euo pipefail
[[ $* == 'env GOPATH' ]] || exit 2
printf '%s\n' "$TEST_GOPATH"
GO
# Prevent a host-installed Atlas from being used by the broken command.
cat >"$temp_dir/tools/atlas" <<'NO_ATLAS'
#!/usr/bin/env bash
exit 127
NO_ATLAS
chmod +x "$temp_dir/tools/go" "$temp_dir/tools/atlas"
export PATH="$temp_dir/tools:$PATH"

shared=$(labctl_mono_stage_command shared)
bash -euo pipefail -c "$shared"
bash -euo pipefail -c "$shared"
failures=0
if [[ ! -d $TEST_GOPATH/bin ]]; then
  printf 'FAIL: shared preparation must create the resolved GOPATH/bin directory\n' >&2
  failures=$((failures + 1))
fi

# A successful PCM setup must discover the user's Atlas, even when the login
# PATH does not contain GOPATH/bin. Never run actual migrations in this test.
mkdir -p "$TEST_GOPATH/bin"
cat >"$TEST_GOPATH/bin/atlas" <<'ATLAS'
#!/usr/bin/env bash
printf 'atlas fixture IMAGE_IMPORT=%s\n' "$IMAGE_IMPORT"
ATLAS
chmod +x "$TEST_GOPATH/bin/atlas"
cat >"$temp_dir/workspace/ngxcp/PlatformCommonModels/scripts/development/Makefile" <<'MAKEFILE'
.PHONY: setup-config-db
setup-config-db:
	@atlas > atlas-result
MAKEFILE
pcm=$(labctl_mono_stage_command pcm-db)
if ! (cd "$temp_dir/workspace" && bash -euo pipefail -c "$pcm"); then
  printf 'FAIL: PCM setup must discover Atlas in GOPATH/bin\n' >&2
  failures=$((failures + 1))
elif [[ $(<"$temp_dir/workspace/ngxcp/PlatformCommonModels/scripts/development/atlas-result") != 'atlas fixture IMAGE_IMPORT=false' ]]; then
  printf 'FAIL: PCM setup did not use the user Atlas with image import disabled\n' >&2
  failures=$((failures + 1))
fi

# Do not silently overwrite an unexpected file when initializing a tool path.
export TEST_GOPATH="$temp_dir/corrupt-go"
mkdir -p "$TEST_GOPATH"
printf 'preserve this file\n' >"$TEST_GOPATH/bin"
if bash -euo pipefail -c "$shared" 2>"$temp_dir/error"; then
  printf 'FAIL: shared preparation must reject a regular file at GOPATH/bin\n' >&2
  failures=$((failures + 1))
fi
[[ $(<"$TEST_GOPATH/bin") == 'preserve this file' ]] || {
  printf 'FAIL: shared preparation modified an unexpected Go-bin file\n' >&2
  exit 1
}

# Explicit operator overrides must remain unchanged.
LABCTL_MONO_STAGE_SHARED_COMMAND='echo custom shared'
LABCTL_MONO_STAGE_PCM_DB_COMMAND='echo custom pcm'
[[ $(labctl_mono_stage_command shared) == "$LABCTL_MONO_STAGE_SHARED_COMMAND" ]]
[[ $(labctl_mono_stage_command pcm-db) == "$LABCTL_MONO_STAGE_PCM_DB_COMMAND" ]]
((failures == 0)) || exit 1
printf 'PASS: mono Go-bin preparation, PCM tool discovery, and override preservation\n'
