#!/usr/bin/env bash
# Exercise profile creation and reconciliation without contacting a real daemon.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=/dev/null
source "$REPO_ROOT/incus/.local/lib/labctl/incus.sh"

TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
COMMAND_LOG="$TEST_ROOT/commands"
export LABCTL_INCUS_PROJECT=agent-sandbox
export LABCTL_INCUS_PROFILE=agent-dev-env
export LABCTL_AGENT_BRIDGE=agentbr0

labctl_die() {
	printf 'FAIL: %s\n' "$*" >&2
	return 1
}
labctl_run() {
	printf '%s\n' "$*" >>"$COMMAND_LOG"
}
incus() {
	case "$*" in
	'query /1.0/profiles/agent-dev-env?project=agent-sandbox' | '--project agent-sandbox profile device show agent-dev-env eth0')
		[[ $profile_exists == true ]]
		;;
	*) labctl_die "unexpected Incus command: $*" ;;
	esac
}

for profile_exists in false true; do
	: >"$COMMAND_LOG"
	labctl_incus_ensure_profile
	for setting in limits.cpu=4 limits.memory=6GiB limits.memory.enforce=hard limits.memory.swap=false; do
		[[ $(rg -Fxc "incus profile set agent-dev-env $setting" "$COMMAND_LOG") == 1 ]] ||
			labctl_die "profile_exists=$profile_exists did not apply $setting exactly once"
	done
	if [[ $profile_exists == false ]]; then
		rg -Fxq 'incus profile create agent-dev-env' "$COMMAND_LOG" || labctl_die 'missing profile was not created'
	elif rg -q '^incus profile create ' "$COMMAND_LOG"; then
		labctl_die 'existing profile was recreated'
	fi
	if rg -q '^incus (start|stop|restart|delete) ' "$COMMAND_LOG"; then
		labctl_die 'profile reconciliation invoked a container lifecycle command'
	fi
done
printf '%s\n' 'PASS: profile resource defaults for creation and reconciliation'
