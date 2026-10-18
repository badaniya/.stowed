#!/usr/bin/env bash
# nvo-harness-worktree-sandbox — create/reuse an NVO harness worktree, bootstrap
# its ticket-scoped Incus sandbox, then open an agent/build Herdr workspace.
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

[[ -x $labctl ]] || {
	printf 'Error: labctl is unavailable at %s; stow the incus package first\n' "$labctl" >&2
	exit 1
}

# The standard creator remains responsible for worktrees and aggregate context.
# Its normal one-tab workspace is deliberately deferred until the guest is ready.
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

printf '→ Creating sandbox %s…\n' "$ticket"
run_labctl create
printf '→ Syncing the host Git credential into sandbox %s…\n' "$ticket"
run_labctl credential sync
printf '→ Bootstrapping sandbox %s…\n' "$ticket"
run_labctl bootstrap
printf '→ Syncing private Loggo template into sandbox %s…\n' "$ticket"
run_labctl template sync

instance_user=$(run_labctl_without_ticket instance-user)
[[ $instance_user =~ ^[a-z_][a-z0-9_-]*$ ]] || {
	printf 'Error: labctl returned an unsafe sandbox user name\n' >&2
	exit 1
}

incus_command() {
	local guest_command=$1 command
	printf -v command 'incus exec %q -- su - %q -c %q' "$normalized_ticket" "$instance_user" "$guest_command"
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
	monitor=$(incus_command 'tail -F /var/log/network/network-server.log /var/log/edge/edge-server.log /var/log/scheduler/scheduler-server.log /var/log/runonce/runonce-server.log /var/log/system/system-server.log | loggo stream -t ~/.private-nvo-loggo.tpl')
	lazydocker=$(incus_command 'lazydocker')
	pcm=$(incus_command "cd $(printf '%q' "${project_dir}/PlatformCommonModels/scripts/development") && exec bash -l")
	platform=$(incus_command "cd $(printf '%q' "${project_dir}/PlatformServices/scripts/development") && exec bash -l")
	godcapp=$(incus_command "cd $(printf '%q' "${project_dir}/GoDCApp/NVO/scripts/development") && exec bash -l")

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

create_workspace
