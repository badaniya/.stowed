#!/usr/bin/env bash
# nvo-harness-worktree-sandbox — create/reuse an NVO harness worktree, then open
# its agent/build Herdr workspace while the ticket-scoped Incus sandbox bootstraps.
set -euo pipefail

if [[ $# -lt 1 ]]; then
	printf 'Usage: nvo-harness-worktree-sandbox.sh <JIRA#> <upstream-version> [--restore-harness]\n' >&2
	exit 1
fi

if [[ $# -ge 2 ]]; then
	args=("$@")
else
	read -r -a args <<<"$1"
fi

ticket=${args[0]:-}
[[ $ticket =~ ^NVO-[0-9]+$ ]] || {
	printf 'Error: ticket must use the NVO-<number> format\n' >&2
	exit 1
}
normalized_ticket=${ticket,,}

spreader_dir="${HOME}/.config/herdr-spreader"
labctl="${HOME}/.local/bin/labctl"
workspace_owner=${NVO_WORKSPACE_OWNER:-${USER:?}}
workspace_root=${NVO_WORKSPACE_ROOT:-"${HOME}/workspace/${workspace_owner}"}
project_dir="${workspace_root}/${ticket}"
state_dir="${XDG_STATE_HOME:-${HOME}/.local/state}/herdr-spreader"
state_log="${state_dir}/${ticket}.log"

[[ -x $labctl ]] || {
	printf 'Error: labctl is unavailable at %s; stow the incus package first\n' "$labctl" >&2
	exit 1
}

# The standard creator remains responsible for worktrees and aggregate context.
# Its normal one-tab workspace is deliberately deferred while this script creates
# the agent and build tabs below.
NVO_HARNESS_DEFER_WORKSPACE=true bash "${spreader_dir}/nvo-harness-worktree-sandbox-base.sh" "${args[@]}"

run_labctl() {
	local command
	printf -v command '%q ' "$labctl" "$@" "$ticket"
	sg incus-admin -c "$command"
}

run_labctl_without_ticket() {
	local command
	printf -v command '%q ' "$labctl" "$@"
	sg incus-admin -c "$command"
}

bootstrap_sandbox() {
	local instance_user

	printf '%s\n' 'NVO_SANDBOX_BOOTSTRAP_STARTED'
	printf '→ Creating sandbox %s…\n' "$ticket"
	run_labctl create || return 1
	printf '→ Syncing the host Git credential into sandbox %s…\n' "$ticket"
	run_labctl credential sync || return 1
	printf '→ Bootstrapping sandbox %s…\n' "$ticket"
	run_labctl bootstrap || return 1
	printf '→ Syncing private Loggo template into sandbox %s…\n' "$ticket"
	run_labctl template sync || return 1

	instance_user=$(run_labctl_without_ticket instance-user) || return 1
	[[ $instance_user =~ ^[a-z_][a-z0-9_-]*$ ]] || {
		printf 'Error: labctl returned an unsafe sandbox user name\n' >&2
		return 1
	}
	printf 'NVO_SANDBOX_INSTANCE_USER=%s\n' "$instance_user"
	printf '%s\n' 'NVO_SANDBOX_BOOTSTRAP_SUCCESS'
}

prepare_state_log() {
	mkdir -p "$state_dir"
	: >"$state_log"
}

start_bootstrap() {
	(
		if ! bootstrap_sandbox; then
			printf '%s\n' 'NVO_SANDBOX_BOOTSTRAP_FAILED'
		fi
	) >>"$state_log" 2>&1 &
}

instance_user_setup() {
	local setup
	# shellcheck disable=SC2016 # Build pane expands this only after bootstrap writes its state log.
	printf -v setup 'until instance_user=$(awk -F= %q %q) && [[ $instance_user =~ ^[a-z_][a-z0-9_-]*$ ]]; do if rg -Fxq %q %q; then printf %q >&2; exit 1; fi; printf %q; sleep 1; done' \
		'/^NVO_SANDBOX_INSTANCE_USER=/{print $2; exit}' "$state_log" 'NVO_SANDBOX_BOOTSTRAP_FAILED' "$state_log" 'Sandbox bootstrap did not provide a safe instance user\n' 'Waiting for sandbox bootstrap user…\n'
	printf '%s\n' "$setup"
}

guest_exec_command() {
	local guest_command=$1 command
	# shellcheck disable=SC2016 # Build pane obtains and validates this value at runtime.
	printf -v command 'incus exec %q -- su - "$instance_user" -c %q' "$normalized_ticket" "$guest_command"
	printf '%s\n' "$command"
}

monitor_command() {
	local guest_command guest_exec setup command
	guest_command='tail -F /var/log/network/network-server.log /var/log/edge/edge-server.log /var/log/scheduler/scheduler-server.log /var/log/runonce/runonce-server.log /var/log/system/system-server.log | loggo stream -t ~/.private-nvo-loggo.tpl'
	guest_exec=$(guest_exec_command "$guest_command")
	setup=$(instance_user_setup)
	# shellcheck disable=SC2016 # The generated Build-pane command owns its tail process.
	printf -v command 'tail -n +1 -F %q & log_pid=$!; trap %q EXIT; until rg -Fxq %q %q; do if rg -Fxq %q %q; then kill "$log_pid" 2>/dev/null || true; wait "$log_pid" 2>/dev/null || true; printf %q >&2; exec bash; fi; sleep 1; done; %s; export instance_user; sg incus-admin -c %q || { printf %q >&2; exec bash; }' \
		"$state_log" 'kill "$log_pid" 2>/dev/null || true' 'NVO_SANDBOX_BOOTSTRAP_SUCCESS' "$state_log" 'NVO_SANDBOX_BOOTSTRAP_FAILED' "$state_log" 'Sandbox bootstrap failed; inspect the log above.\n' "$setup" "$guest_exec" 'Loggo monitor exited; inspect the command and bootstrap log above.\n'
	printf '%s\n' "$command"
}

ready_guest_command() {
	local guest_command=$1 readiness guest_exec setup command
	printf -v readiness 'incus exec %q -- true' "$normalized_ticket"
	guest_exec=$(guest_exec_command "$guest_command")
	setup=$(instance_user_setup)
	printf -v command 'until sg incus-admin -c %q; do printf %q; sleep 2; done; %s; export instance_user; sg incus-admin -c %q || { printf %q >&2; exec bash; }' \
		"$readiness" "Waiting for sandbox ${ticket} to become ready…\\n" "$setup" "$guest_exec" 'Sandbox attachment exited; inspect the command above.'
	printf '%s\n' "$command"
}

create_workspace() {
	local workspace_json workspace_id agent_tab_id agent_pane_id build_json build_pane_id
	workspace_json=$(herdr workspace create --cwd "$project_dir" --label "$ticket - NVO Workspace" --focus)
	workspace_id=$(jq -er '.result.workspace.workspace_id' <<<"$workspace_json")
	agent_tab_id=$(jq -er '.result.tab.tab_id' <<<"$workspace_json")
	agent_pane_id=$(jq -er '.result.root_pane.pane_id' <<<"$workspace_json")
	herdr tab rename "$agent_tab_id" '1 - Agent'
	herdr pane run "$agent_pane_id" 'claude'

	build_json=$(herdr tab create --workspace "$workspace_id" --cwd "$project_dir" --label '2 - Build' --no-focus)
	build_pane_id=$(jq -er '.result.root_pane.pane_id' <<<"$build_json")

	local monitor lazydocker pcm platform godcapp
	monitor=$(monitor_command)
	lazydocker=$(ready_guest_command 'lazydocker')
	pcm=$(ready_guest_command "cd $(printf '%q' "${project_dir}/PlatformCommonModels/scripts/development") && exec bash -l")
	platform=$(ready_guest_command "cd $(printf '%q' "${project_dir}/PlatformServices/scripts/development") && exec bash -l")
	godcapp=$(ready_guest_command "cd $(printf '%q' "${project_dir}/GoDCApp/NVO/scripts/development") && exec bash -l")

	herdr pane run "$build_pane_id" "$monitor"
	lazy_json=$(herdr pane split "$build_pane_id" --direction down --ratio 0.42 --cwd "$project_dir" --no-focus)
	lazy_pane_id=$(jq -er '.result.pane.pane_id' <<<"$lazy_json")
	herdr pane run "$lazy_pane_id" "$lazydocker"
	pcm_json=$(herdr pane split "$lazy_pane_id" --direction right --ratio 0.65 --cwd "$project_dir" --no-focus)
	pcm_pane_id=$(jq -er '.result.pane.pane_id' <<<"$pcm_json")
	herdr pane run "$pcm_pane_id" "$pcm"
	platform_json=$(herdr pane split "$pcm_pane_id" --direction down --ratio 0.33 --cwd "$project_dir" --no-focus)
	platform_pane_id=$(jq -er '.result.pane.pane_id' <<<"$platform_json")
	herdr pane run "$platform_pane_id" "$platform"
	godcapp_json=$(herdr pane split "$platform_pane_id" --direction down --ratio 0.5 --cwd "$project_dir" --focus)
	godcapp_pane_id=$(jq -er '.result.pane.pane_id' <<<"$godcapp_json")
	herdr pane run "$godcapp_pane_id" "$godcapp"
}

# Make the log available before the Build top pane starts tailing it. Tabs are
# then usable immediately while the worker records the bootstrap outcome.
prepare_state_log
create_workspace
start_bootstrap
