#!/usr/bin/env bash
# nvo-harness-worktree-sandbox — create/reuse NVO harness worktrees and open an
# asynchronous, dependency-aware Incus sandbox Build workspace.
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
stage_dir="${state_dir}/${ticket}.stages"

[[ -x $labctl ]] || {
	printf 'Error: labctl is unavailable at %s; stow the incus package first\n' "$labctl" >&2
	exit 1
}

# The standard creator remains responsible for worktrees and aggregate context.
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

run_labctl_stage() {
	local stage=$1 command
	printf -v command '%q %q %q %q' "$labctl" stage "$ticket" "$stage"
	sg incus-admin -c "$command"
}

stage_marker_path() {
	printf '%s/%s.%s\n' "$stage_dir" "$1" "$2"
}

stage_log_path() {
	printf '%s/%s.log\n' "$stage_dir" "$1"
}

write_stage_marker() {
	local stage=$1 result=$2 marker temporary
	marker=$(stage_marker_path "$stage" "$result")
	temporary=$(mktemp "${stage_dir}/.${stage}.${result}.XXXXXX")
	printf '%s\n' "$(date -Is) stage=${stage} result=${result}" >"$temporary"
	mv -- "$temporary" "$marker"
}

stage_is_ready() { [[ -f $(stage_marker_path "$1" ready) ]]; }
stage_is_failed() { [[ -f $(stage_marker_path "$1" failed) ]]; }

wait_for_stage() {
	local stage=$1
	until stage_is_ready "$stage"; do
		if stage_is_failed "$stage"; then
			printf 'stage prerequisite failed: %s\n' "$stage" >&2
			return 1
		fi
		sleep 0.2
	done
}

finalize_stage_output() {
	local stage=$1 raw=$2 output binary
	output=$(stage_log_path "$stage")
	binary="${stage_dir}/${stage}.binary-output"
	if ! cmp -s "$raw" "$output"; then
		mv -- "$raw" "$binary"
		printf '[%s] non-text output was saved to %s\n' "$stage" "$binary" >>"$output"
	else
		rm -f -- "$raw"
	fi
}

run_stage() {
	local stage=$1 raw output
	raw=$(mktemp "${stage_dir}/.${stage}.raw.XXXXXX")
	output=$(stage_log_path "$stage")
	printf '→ Starting stage %s for %s…\n' "$stage" "$ticket" >>"$state_log"
	if run_labctl_stage "$stage" 2>&1 | tee "$raw" | LC_ALL=C stdbuf -oL tr -cd '\11\12\15\40-\176' >"$output"; then
		finalize_stage_output "$stage" "$raw"
		write_stage_marker "$stage" ready
		printf '→ Stage %s completed.\n' "$stage" >>"$state_log"
		return 0
	fi
	finalize_stage_output "$stage" "$raw"
	write_stage_marker "$stage" failed
	printf '→ Stage %s failed; inspect %s.\n' "$stage" "$output" >>"$state_log"
	return 1
}

run_dependent_stage() {
	local stage=$1 prerequisite
	shift
	for prerequisite in "$@"; do
		if ! wait_for_stage "$prerequisite"; then
			printf 'stage %s skipped because prerequisite %s failed\n' "$stage" "$prerequisite" >"$(stage_log_path "$stage")"
			write_stage_marker "$stage" failed
			return 1
		fi
	done
	run_stage "$stage"
}

wait_for_workers() {
	local pid result=0
	for pid in "$@"; do
		wait "$pid" || result=1
	done
	return "$result"
}

bootstrap_sandbox() {
	local instance_user pcm_pid platform_build_pid godcapp_build_pid godcapp_infra_pid platform_start_pid godcapp_services_pid

	printf '%s\n' 'NVO_SANDBOX_BOOTSTRAP_STARTED'
	printf '→ Creating sandbox %s…\n' "$ticket"
	run_labctl create || return 1
	instance_user=$(run_labctl_without_ticket instance-user) || return 1
	[[ $instance_user =~ ^[a-z_][a-z0-9_-]*$ ]] || {
		printf 'Error: labctl returned an unsafe sandbox user name\n' >&2
		return 1
	}
	printf 'NVO_SANDBOX_INSTANCE_USER=%s\n' "$instance_user"
	printf '→ Syncing the host Git credential into sandbox %s…\n' "$ticket"
	run_labctl credential sync || return 1
	printf '→ Running shared sandbox preparation for %s…\n' "$ticket"
	run_stage shared || return 1

	run_stage pcm-db &
	pcm_pid=$!
	run_stage platform-tagging-build &
	platform_build_pid=$!
	run_stage godcapp-build &
	godcapp_build_pid=$!
	run_stage godcapp-infra &
	godcapp_infra_pid=$!
	run_dependent_stage platform-tagging-start pcm-db platform-tagging-build &
	platform_start_pid=$!
	run_dependent_stage godcapp-services pcm-db platform-tagging-start &
	godcapp_services_pid=$!
	wait_for_workers "$pcm_pid" "$platform_build_pid" "$godcapp_build_pid" "$godcapp_infra_pid" "$platform_start_pid" "$godcapp_services_pid" || return 1

	printf '→ Syncing private Loggo template into sandbox %s…\n' "$ticket"
	run_labctl template sync || return 1
	printf '%s\n' 'NVO_SANDBOX_BOOTSTRAP_SUCCESS'
}

prepare_state() {
	mkdir -p "$state_dir"
	: >"$state_log"
	rm -rf -- "$stage_dir"
	mkdir -m 0700 "$stage_dir"
	local stage
	for stage in shared pcm-db platform-tagging-build platform-tagging-start godcapp-build godcapp-infra godcapp-services; do
		: >"$(stage_log_path "$stage")"
	done
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
	printf -v setup 'until instance_user=$(awk -F= %q %q) && [[ $instance_user =~ ^[a-z_][a-z0-9_-]*$ ]]; do if rg -Fxq %q %q; then printf %q >&2; exit 1; fi; sleep 0.2; done' \
		'/^NVO_SANDBOX_INSTANCE_USER=/{print $2; exit}' "$state_log" 'NVO_SANDBOX_BOOTSTRAP_FAILED' "$state_log" 'Sandbox bootstrap did not provide a safe instance user\n'
	printf '%s\n' "$setup"
}

guest_exec_command() {
	local guest_command=$1 interactive=${2:-false} command
	# shellcheck disable=SC2016 # Build pane obtains and validates this value at runtime.
	if [[ $interactive == true ]]; then
		local guest_setpriv_command
		printf -v guest_setpriv_command 'exec setpriv --reset-env --reuid "$1" --regid "$(id -g "$1")" --init-groups %q' "$guest_command"
		printf -v command 'incus exec --force-interactive %q -- bash -lc %q _ "$instance_user"' "$normalized_ticket" "$guest_setpriv_command"
	else
		printf -v command 'incus exec %q -- su - "$instance_user" -c %q' "$normalized_ticket" "$guest_command"
	fi
	printf '%s\n' "$command"
}

monitor_command() {
	local guest_command guest_exec setup command
	guest_command='tail -F /var/log/network/network-server.log /var/log/edge/edge-server.log /var/log/scheduler/scheduler-server.log /var/log/runonce/runonce-server.log /var/log/system/system-server.log | /usr/local/bin/loggo stream -t ~/.private-nvo-loggo.tpl'
	guest_exec=$(guest_exec_command "$guest_command")
	setup=$(instance_user_setup)
	# shellcheck disable=SC2016 # The generated Build-pane command owns its tail process.
	printf -v command 'tail -n +1 -F %q & log_pid=$!; trap %q EXIT; until rg -Fxq %q %q; do if rg -Fxq %q %q; then kill "$log_pid" 2>/dev/null || true; wait "$log_pid" 2>/dev/null || true; printf %q >&2; exec bash; fi; sleep 1; done; %s; export instance_user; sg incus-admin -c %q || { printf %q >&2; exec bash; }' \
		"$state_log" 'kill "$log_pid" 2>/dev/null || true' 'NVO_SANDBOX_BOOTSTRAP_SUCCESS' "$state_log" 'NVO_SANDBOX_BOOTSTRAP_FAILED' "$state_log" 'Sandbox bootstrap failed; inspect the log above.\n' "$setup" "$guest_exec" 'Loggo monitor exited; inspect the command and bootstrap log above.\n'
	printf '%s\n' "$command"
}

ready_guest_command() {
	local guest_command=$1 interactive=${2:-false} readiness guest_exec setup command
	printf -v readiness 'incus exec %q -- true' "$normalized_ticket"
	guest_exec=$(guest_exec_command "$guest_command" "$interactive")
	setup=$(instance_user_setup)
	# shellcheck disable=SC2016 # The generated pane shell expands after the guest is ready.
	printf -v command 'until sg incus-admin -c %q; do sleep 0.2; done; %s; export instance_user; sg incus-admin -c %q || { printf %q >&2; exec bash; }' \
		"$readiness" "$setup" "$guest_exec" 'Sandbox attachment exited; inspect the command above.\n'
	printf '%s\n' "$command"
}

stage_pane_command() {
	local final_stage=$1 directory=$2 stage guest_exec setup command logs='' ready failed
	shift 2
	for stage in "$@"; do
		printf -v logs '%s %q' "$logs" "$(stage_log_path "$stage")"
	done
	ready=$(stage_marker_path "$final_stage" ready)
	failed=$(stage_marker_path "$final_stage" failed)
	guest_exec=$(guest_exec_command "cd $(printf '%q' "$directory") && exec bash -l")
	setup=$(instance_user_setup)
	# shellcheck disable=SC2016 # Pane tails all owned stage logs, then opens the guest directory after the final stage succeeds.
	printf -v command 'tail -q -n +1 -F%s & stage_log_pid=$!; trap %q EXIT; until [[ -f %q || -f %q ]]; do sleep 0.2; done; if [[ -f %q ]]; then printf %q >&2; exec bash; fi; kill "$stage_log_pid" 2>/dev/null || true; wait "$stage_log_pid" 2>/dev/null || true; %s; export instance_user; sg incus-admin -c %q || { printf %q >&2; exec bash; }' \
		"$logs" 'kill "$stage_log_pid" 2>/dev/null || true' "$ready" "$failed" "$failed" "Stage ${final_stage} failed; inspect the stage logs above.\n" "$setup" "$guest_exec" 'Sandbox attachment exited; inspect the command above.\n'
	printf '%s\n' "$command"
}

workspace_label() {
	local title
	title=$(jira issue view "$ticket" --raw 2>/dev/null | jq -r '.fields.summary // empty' 2>/dev/null || true)
	title=${title//$'\n'/ }
	[[ -n $title ]] || title='NVO Workspace'
	printf '%s - %s\n' "$ticket" "$title"
}

create_workspace() {
	local workspace_json workspace_id agent_tab_id agent_pane_id build_json build_pane_id label
	label=$(workspace_label)
	workspace_json=$(herdr workspace create --cwd "$project_dir" --label "$label" --focus)
	workspace_id=$(jq -er '.result.workspace.workspace_id' <<<"$workspace_json")
	agent_tab_id=$(jq -er '.result.tab.tab_id' <<<"$workspace_json")
	agent_pane_id=$(jq -er '.result.root_pane.pane_id' <<<"$workspace_json")
	herdr tab rename "$agent_tab_id" '1 - Agent'
	herdr pane run "$agent_pane_id" 'claude'

	build_json=$(herdr tab create --workspace "$workspace_id" --cwd "$project_dir" --label '2 - Build' --no-focus)
	build_pane_id=$(jq -er '.result.root_pane.pane_id' <<<"$build_json")

	local monitor lazydocker pcm platform godcapp
	monitor=$(monitor_command)
	lazydocker=$(ready_guest_command 'lazydocker' true)
	pcm=$(stage_pane_command pcm-db "${project_dir}/PlatformCommonModels/scripts/development" pcm-db)
	platform=$(stage_pane_command platform-tagging-start "${project_dir}/PlatformServices/scripts/development" platform-tagging-build platform-tagging-start)
	godcapp=$(stage_pane_command godcapp-services "${project_dir}/GoDCApp/NVO/scripts/development" godcapp-build godcapp-infra godcapp-services)

	herdr pane rename "$build_pane_id" Monitor
	herdr pane run "$build_pane_id" "$monitor"
	lazy_json=$(herdr pane split "$build_pane_id" --direction down --ratio 0.42 --cwd "$project_dir" --no-focus)
	lazy_pane_id=$(jq -er '.result.pane.pane_id' <<<"$lazy_json")
	herdr pane rename "$lazy_pane_id" LazyDocker
	herdr pane run "$lazy_pane_id" "$lazydocker"
	pcm_json=$(herdr pane split "$lazy_pane_id" --direction right --ratio 0.65 --cwd "$project_dir" --no-focus)
	pcm_pane_id=$(jq -er '.result.pane.pane_id' <<<"$pcm_json")
	herdr pane rename "$pcm_pane_id" PlatformCommonModels
	herdr pane run "$pcm_pane_id" "$pcm"
	platform_json=$(herdr pane split "$pcm_pane_id" --direction down --ratio 0.33 --cwd "$project_dir" --no-focus)
	platform_pane_id=$(jq -er '.result.pane.pane_id' <<<"$platform_json")
	herdr pane rename "$platform_pane_id" PlatformServices
	herdr pane run "$platform_pane_id" "$platform"
	godcapp_json=$(herdr pane split "$platform_pane_id" --direction down --ratio 0.5 --cwd "$project_dir" --focus)
	godcapp_pane_id=$(jq -er '.result.pane.pane_id' <<<"$godcapp_json")
	herdr pane rename "$godcapp_pane_id" GoDCApp
	herdr pane run "$godcapp_pane_id" "$godcapp"
}

# Make state available before the Build top pane starts tailing it. Tabs are
# usable immediately while the worker records the stage outcomes.
prepare_state
create_workspace
start_bootstrap
