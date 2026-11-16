#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../.local/lib/labctl/network.sh
source "$repo_root/incus/.local/lib/labctl/network.sh"

# Catch malformed generated commands and override suffixes without running
# Incus, Docker, credentials, or any real application's Makefile.
for name in shared pcm_db platform_tagging_build platform_tagging_start godcapp_build godcapp_infra godcapp_services; do
  unset "LABCTL_MONO_STAGE_${name^^}_COMMAND"
done

failures=0
for stage in shared pcm-db platform-tagging-build platform-tagging-start godcapp-build godcapp-infra godcapp-services; do
  command=$(labctl_mono_stage_command "$stage")
  if ! bash -n -c "$command"; then
    printf 'FAIL: generated %s command must be valid Bash\n' "$stage" >&2
    failures=$((failures + 1))
  fi
done

LABCTL_MONO_STAGE_GODCAPP_INFRA_COMMAND="printf '%s\\n' 'custom infra'"
command=$(labctl_mono_stage_command godcapp-infra)
if [[ $command != "$LABCTL_MONO_STAGE_GODCAPP_INFRA_COMMAND" ]]; then
  printf 'FAIL: infra override must be returned without a default-command suffix\n' >&2
  failures=$((failures + 1))
fi
unset LABCTL_MONO_STAGE_GODCAPP_INFRA_COMMAND
((failures == 0)) || exit 1

# Execute the actual default twice against a harmless local Makefile. This
# checks that the generated command patches the thread-pool setting once and
# reaches start-infra, rather than merely parsing successfully.
temp_dir=$(mktemp -d)
trap 'rm -rf -- "$temp_dir"' EXIT
mkdir -p "$temp_dir/NVO/scripts/development"
makefile="$temp_dir/NVO/scripts/development/Makefile"
cat >"$makefile" <<'MAKEFILE'
XIQEmulatorKafkaContainerName=fixture
# emulator argument: thread-pool=1000
.PHONY: start-infra
start-infra:
	@printf '%s\n' '$(XIQ_THREAD_POOL)' >> infra-starts
MAKEFILE
command=$(labctl_mono_stage_command godcapp-infra)
(cd "$temp_dir" && bash -euo pipefail -c "$command" && bash -euo pipefail -c "$command")
[[ $(<"${makefile%/*}/infra-starts") == $'1000\n1000' ]] || {
  printf 'FAIL: default command did not run start-infra twice with the configured thread pool\n' >&2
  exit 1
}
[[ $(rg -c '^XIQ_THREAD_POOL \?=' "$makefile") == 1 ]] || {
  printf 'FAIL: repeated execution duplicated the thread-pool variable\n' >&2
  exit 1
}
rg -Fq 'thread-pool=$(XIQ_THREAD_POOL)' "$makefile" || {
  printf 'FAIL: emulator argument did not retain the literal Make variable\n' >&2
  exit 1
}

# Existing operator tuning must survive the default patch.
sed -i 's/^XIQ_THREAD_POOL ?= 1000$/XIQ_THREAD_POOL ?= 64/' "$makefile"
(cd "$temp_dir" && bash -euo pipefail -c "$command")
[[ $(<"${makefile%/*}/infra-starts") == $'1000\n1000\n64' ]] || {
  printf 'FAIL: default command replaced an existing thread-pool setting\n' >&2
  exit 1
}

printf 'PASS: monorepo stage syntax, infra overrides, and idempotent infra preparation\n'
