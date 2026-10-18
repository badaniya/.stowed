#!/usr/bin/env bash
# Stack hooks and network verification for ticket-scoped labctl sandboxes.
set -euo pipefail

# Stack hook values are trusted, private configuration. They are deliberately not
# interpreted by the host: each runs from the mounted ticket root in its instance.
labctl_stack_run() {
	local ticket=$1 hook=$2 root
	ticket=$(labctl_normalize_ticket "$ticket") || return 1
	root=$(labctl_workspace_ticket_root "$ticket") || return 1
	labctl_incus_instance_exists "$ticket" || {
		labctl_die "sandbox instance does not exist: $ticket"
		return 1
	}
	labctl_incus_is_running "$ticket" || {
		labctl_die "sandbox instance is not running: $ticket"
		return 1
	}
	labctl_incus_workspace_is_mounted "$ticket" "$root" || {
		labctl_die "sandbox workspace mounts are invalid: $ticket"
		return 1
	}
	labctl_incus_stack_command "$ticket" "$root" "$hook"
}

labctl_stack_up() {
	labctl_stack_run "$1" "$LABCTL_STACK_UP_COMMAND"
}

labctl_stack_down() {
	labctl_stack_run "$1" "$LABCTL_STACK_DOWN_COMMAND"
}

labctl_stack_health() {
	labctl_stack_run "$1" "$LABCTL_STACK_HEALTH_COMMAND"
}

labctl_stack_stage() {
	local ticket=$1 stage=$2 command
	case $stage in
	shared) command=$LABCTL_STAGE_SHARED_COMMAND ;;
	pcm-db) command=$LABCTL_STAGE_PCM_DB_COMMAND ;;
	platform-tagging-build) command=$LABCTL_STAGE_PLATFORM_TAGGING_BUILD_COMMAND ;;
	platform-tagging-start) command=$LABCTL_STAGE_PLATFORM_TAGGING_START_COMMAND ;;
	godcapp-build) command=$LABCTL_STAGE_GODCAPP_BUILD_COMMAND ;;
	godcapp-infra) command=$LABCTL_STAGE_GODCAPP_INFRA_COMMAND ;;
	godcapp-services) command=$LABCTL_STAGE_GODCAPP_SERVICES_COMMAND ;;
	*)
		labctl_die "invalid sandbox stage: $stage"
		return 1
		;;
	esac
	printf 'stage: %s ticket=%s\n' "$stage" "$ticket"
	labctl_stack_run "$ticket" "$command"
}

labctl_verify_ports() {
	local ticket=$1 ip port
	ticket=$(labctl_normalize_ticket "$ticket") || return 1
	labctl_incus_instance_exists "$ticket" || {
		labctl_die "sandbox instance does not exist: $ticket"
		return 1
	}
	ip=$(labctl_incus_instance_ip "$ticket")
	labctl_config_is_ipv4 "$ip" || {
		labctl_die "sandbox has no valid assigned IP: $ticket"
		return 1
	}
	IFS=, read -r -a ports <<<"$LABCTL_DEVICE_TCP_PORTS"
	for port in "${ports[@]}"; do
		labctl_run nc -z -w 3 "$ip" "$port" || {
			labctl_die "device TCP port is closed: $ip:$port"
			return 1
		}
	done
}

labctl_verify() {
	local ticket=$1 root
	ticket=$(labctl_normalize_ticket "$ticket") || return 1
	root=$(labctl_workspace_ticket_root "$ticket") || return 1
	labctl_incus_instance_exists "$ticket" || {
		labctl_die "sandbox instance does not exist: $ticket"
		return 1
	}
	labctl_incus_is_running "$ticket" || {
		labctl_die "sandbox instance is not running: $ticket"
		return 1
	}
	labctl_incus_workspace_is_mounted "$ticket" "$root" || {
		labctl_die "sandbox workspace mounts are invalid: $ticket"
		return 1
	}
	labctl_incus_verify_isolation "$ticket" || return 1
	labctl_run incus exec "$ticket" -- docker info
	labctl_stack_health "$ticket"
	labctl_verify_ports "$ticket"
	printf 'manual check required: verify GNS3/device routing to the sandbox IP through an approved probe path\n'
}
