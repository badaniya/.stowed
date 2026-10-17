#!/usr/bin/env bash
# Incus provider operations for ticket-scoped labctl sandboxes.
set -euo pipefail

LABCTL_INCUS_PROFILE=${LABCTL_INCUS_PROFILE:-agent-dev-env}
LABCTL_INCUS_STORAGE_POOL=${LABCTL_INCUS_STORAGE_POOL:-agentpool}

labctl_incus_profile_is_unsafe() {
	local profile_json=$1
	jq -e --arg agent_bridge "$LABCTL_AGENT_BRIDGE" '
		([
			.devices? | objects | to_entries[]? |
			select(
				.value.type == "nic" and (
					.key != "eth0" or
					.value.network != $agent_bridge or
					.value.name != "eth0" or
					(.value | has("parent")) or
					(.value | has("nictype"))
				)
			)
		] | length > 0) or
		([.. | objects | select(
			(.config? | type == "object" and has("raw.lxc")) or
			(."security.privileged" == true) or
			(."security.privileged" == "true") or
			(.network == "host") or
			(.type == "proxy") or
			(.source == "/var/run/docker.sock") or
			(.path == "/var/run/docker.sock") or
			(.type == "disk" and (.source? | type == "string" and startswith("/"))) or
			(.type == "unix-block") or
			(.type == "unix-char") or
			(.type == "unix-hotplug") or
			(.type == "gpu") or
			(.type == "pci") or
			(.type == "usb")
		)] | length > 0)
	' >/dev/null <<<"$profile_json"
}

labctl_incus_validate_profile_name() {
	local profile=$1
	[[ $profile =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]] || {
		labctl_die "invalid Incus profile name: $profile"
		return 1
	}
}

labctl_incus_profile_query() {
	local profile=$1 encoded_profile
	labctl_incus_validate_profile_name "$profile" || return 1
	encoded_profile=$(jq -rn --arg profile "$profile" '$profile | @uri') || {
		labctl_die "unable to encode Incus profile name: $profile"
		return 1
	}
	incus query "/1.0/profiles/$encoded_profile"
}

labctl_incus_ensure_profile() {
	labctl_incus_validate_profile_name "$LABCTL_INCUS_PROFILE" || return 1
	if ! labctl_incus_profile_query "$LABCTL_INCUS_PROFILE" >/dev/null 2>&1; then
		labctl_run incus profile create "$LABCTL_INCUS_PROFILE"
	fi

	labctl_run incus profile set "$LABCTL_INCUS_PROFILE" security.privileged=false
	labctl_run incus profile set "$LABCTL_INCUS_PROFILE" security.nesting=true
	labctl_run incus profile set "$LABCTL_INCUS_PROFILE" limits.cpu=2
	labctl_run incus profile set "$LABCTL_INCUS_PROFILE" limits.memory=4GiB
	labctl_run incus profile set "$LABCTL_INCUS_PROFILE" limits.memory.enforce=hard
	labctl_run incus profile set "$LABCTL_INCUS_PROFILE" limits.memory.swap=false
	labctl_run incus profile set "$LABCTL_INCUS_PROFILE" limits.processes=4096
	if incus profile device show "$LABCTL_INCUS_PROFILE" eth0 >/dev/null 2>&1; then
		labctl_run incus profile device set "$LABCTL_INCUS_PROFILE" eth0 network="$LABCTL_AGENT_BRIDGE"
	else
		labctl_run incus profile device add "$LABCTL_INCUS_PROFILE" eth0 nic network="$LABCTL_AGENT_BRIDGE" name=eth0
	fi
}

labctl_incus_render_cloud_init() {
	local output=$1 template_dir template
	template_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../share/labctl" && pwd)
	template=$template_dir/cloud-init.yaml.tmpl
	[[ -r $template ]] || {
		labctl_die "cloud-init template is missing: $template"
		return 1
	}
	umask 077
	sed "s|__LABCTL_INSTANCE_USER__|${LABCTL_INSTANCE_USER}|g" "$template" >"$output"
	chmod 600 "$output"
}

labctl_incus_validate_launch_profiles() {
	local profile profile_json
	for profile in default "$LABCTL_INCUS_PROFILE"; do
		profile_json=$(labctl_incus_profile_query "$profile" 2>/dev/null) || {
			labctl_die "unable to inspect Incus profile before launch; refusing to launch with an unvalidated profile: $profile"
			return 1
		}
		if labctl_incus_profile_is_unsafe "$profile_json"; then
			labctl_die "Incus profile is unsafe for launch: $profile"
			return 1
		fi
	done
}

labctl_incus_launch() {
	local ticket=$1 ip=$2 instance cloud_init
	instance=$(labctl_normalize_ticket "$ticket") || return 1
	cloud_init=$(mktemp "${TMPDIR:-/tmp}/labctl-cloud-init.XXXXXX") || return 1
	labctl_incus_render_cloud_init "$cloud_init" || {
		rm -f "$cloud_init"
		return 1
	}
	labctl_incus_validate_launch_profiles || {
		rm -f "$cloud_init"
		return 1
	}
	labctl_run incus launch "$LABCTL_INSTANCE_IMAGE" "$instance" --profile default --profile "$LABCTL_INCUS_PROFILE" -c "user.user-data=$(cat "$cloud_init")" || {
		rm -f "$cloud_init"
		return 1
	}
	rm -f "$cloud_init"
	labctl_run incus config device set "$instance" eth0 ipv4.address="$ip"
}

labctl_incus_inspect() {
	local instance=$1
	incus info "$instance" --format json
}

labctl_incus_instance_exists() {
	incus info "$1" >/dev/null 2>&1
}

labctl_incus_instance_ip() {
	incus config get "$1" eth0 ipv4.address
}

labctl_incus_is_running() {
	incus info "$1" --format json | jq -e '.status == "Running"' >/dev/null
}

labctl_incus_attach_workspace() {
	local instance=$1 ticket_root=$2
	labctl_run incus config device add "$instance" git-master disk source="$LABCTL_MASTER_ROOT" path="$LABCTL_MASTER_ROOT" shift=true readonly=false
	labctl_run incus config device add "$instance" ticket-workspace disk source="$ticket_root" path="$ticket_root" shift=true readonly=false
}

labctl_incus_wait_ready() {
	local instance=$1
	labctl_run incus exec "$instance" -- cloud-init status --wait
	labctl_run incus exec "$instance" -- docker info
}

labctl_incus_instance_is_unsafe() {
	local instance_json=$1
	jq -e '
		(.config["security.privileged"] == true) or
		(.config["security.privileged"] == "true") or
		(.config["raw.lxc"]? | type == "string" and test("lxc\\.net|lxc\\.mount")) or
		([
			.devices? | objects | to_entries[]? |
			select(
				.value.type == "proxy" or
				(.value.type == "nic" and (
					.value.network == "host" or
					(.value | has("parent")) or
					.value.nictype == "physical" or
					.value.nictype == "macvlan" or
					.value.nictype == "sriov" or
					.value.nictype == "bridged"
				)) or
				((.value.source? // "") | endswith("/docker.sock")) or
				((.value.path? // "") | endswith("/docker.sock"))
			)
		] | length > 0)
	' >/dev/null <<<"$instance_json"
}

labctl_incus_workspace_is_mounted() {
	local instance=$1 ticket_root=$2 instance_json
	instance_json=$(incus config show "$instance" --expanded --format json) || {
		labctl_die "unable to inspect sandbox configuration: $instance"
		return 1
	}
	jq -e --arg master "$LABCTL_MASTER_ROOT" --arg ticket "$ticket_root" '
		[.devices? | objects | .[]?] as $devices |
		any($devices[]?; .type == "disk" and .source == $master and .path == $master) and
		any($devices[]?; .type == "disk" and .source == $ticket and .path == $ticket)
	' >/dev/null <<<"$instance_json"
}

labctl_incus_verify_isolation() {
	local instance=$1 instance_json
	labctl_incus_validate_launch_profiles || return 1
	instance_json=$(incus config show "$instance" --expanded --format json) || {
		labctl_die "unable to inspect sandbox configuration: $instance"
		return 1
	}
	if labctl_incus_instance_is_unsafe "$instance_json"; then
		labctl_die "sandbox configuration violates isolation policy: $instance"
		return 1
	fi
}

labctl_incus_stack_command() {
	local instance=$1 ticket_root=$2 command=$3 quoted_root
	printf -v quoted_root '%q' "$ticket_root"
	labctl_run incus exec "$instance" -- bash -lc "cd -- $quoted_root && $command"
}

labctl_incus_start() {
	local instance=$1 ticket_root=$2
	labctl_run incus start "$instance"
	labctl_incus_wait_ready "$instance"
	labctl_stack_up "$instance"
}

labctl_incus_stop() {
	local instance=$1 ticket_root=$2
	labctl_stack_down "$instance"
	labctl_run incus stop "$instance"
}
