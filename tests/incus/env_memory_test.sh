#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$ROOT/incus/.local/lib/labctl/config.sh"
source "$ROOT/incus/.local/lib/labctl/monorepo-env.sh"
labctl_die() { printf '%s\n' "$*" >&2; return 1; }
labctl_incus_instance_ip() { printf '10.99.0.10\n'; }
labctl_monorepo_env_pass() { printf 'synthetic-value-from-pass\n'; }
TEMP=$(mktemp -d)
trap 'rm -rf "$TEMP"' EXIT
cat >"$TEMP/profile" <<'PROFILE'
# Fixture
export APP_VALUE='original'
export APP_SECRET='legacy-fixture'
PROFILE
chmod 600 "$TEMP/profile"
export LABCTL_MONOREPO_ENV_SOURCE_PATH="$TEMP/profile"
export LABCTL_MONOREPO_ENV_SECTION=Fixture
export LABCTL_MONOREPO_ENV_ALLOWED='APP_VALUE APP_SECRET'
export LABCTL_MONOREPO_ENV_PASS_REFERENCES='APP_SECRET=fixture/secret'
export LABCTL_MONOREPO_ENV_FIXED='APP_VALUE=fixed'
export LABCTL_INSTANCE_USER=fixture
output=$(labctl_monorepo_env_render fixture -)
[[ $output == *"export APP_SECRET='synthetic-value-from-pass'"* ]]
[[ $output == *"export APP_VALUE='fixed'"* ]]
[[ $(printf '%s\n' "$output" | rg -c '^export APP_VALUE=') == 1 ]]
[[ ! -e ./- ]]
printf '%s\n' 'PASS: stdout environment, pass references, fixed override and no output file'
source "$ROOT/incus/.local/lib/labctl/incus.sh"
export LABCTL_INCUS_PROJECT=agent-sandbox
export LABCTL_GIT_HOST=git.example.test
labctl_monorepo_env_render() { printf 'partial export\n'; return 1; }
python3() { touch "$TEMP/unexpected-delivery"; }
if labctl_incus_sync_monorepo_environment fixture fixture; then
  printf '%s\n' 'FAIL: failed render unexpectedly succeeded' >&2
  exit 1
fi
[[ ! -e $TEMP/unexpected-delivery ]]
printf '%s\n' 'PASS: failed render cannot replace live broker state'
