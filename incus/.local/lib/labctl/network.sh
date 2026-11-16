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

# Monorepo stage commands; each runs from the xcloud-platform-services worktree.
labctl_mono_stage_command() {
	case $1 in
	# Existing golden images may lack file; the PCM context builder needs it.
	# Atlas's installer treats a missing output directory as a filename.
	shared) printf '%s\n' "${LABCTL_MONO_STAGE_SHARED_COMMAND:-if ! command -v file >/dev/null 2>&1; then sudo apt-get update && sudo apt-get install -y --no-install-recommends file; fi && mkdir -p \"\$(go env GOPATH)/bin\"}" ;;
	pcm-db) printf '%s\n' "${LABCTL_MONO_STAGE_PCM_DB_COMMAND:-export PATH=\"\$(go env GOPATH)/bin:\$PATH\" && cd ngxcp/PlatformCommonModels/scripts/development && IMAGE_IMPORT=false make setup-config-db}" ;;
	platform-tagging-build) printf '%s\n' "${LABCTL_MONO_STAGE_PLATFORM_TAGGING_BUILD_COMMAND:-cd ngxcp/PlatformServices/scripts/development && make build-tagging}" ;;
	platform-tagging-start) printf '%s\n' "${LABCTL_MONO_STAGE_PLATFORM_TAGGING_START_COMMAND:-cd ngxcp/PlatformServices/scripts/development && make start-tagging}" ;;
	godcapp-build) printf '%s\n' "${LABCTL_MONO_STAGE_GODCAPP_BUILD_COMMAND:-cd NVO/scripts/development && make build}" ;;
	godcapp-infra)
		# Keep shell braces outside ${...:-...}: an unescaped } ends that expansion.
		local default_command
		default_command="cd NVO/scripts/development && { grep -q '^XIQ_THREAD_POOL ?=' Makefile || sed -i '/^XIQEmulatorKafkaContainerName=/a XIQ_THREAD_POOL ?= 1000' Makefile; } && sed -i 's/thread-pool=1000/thread-pool=\$(XIQ_THREAD_POOL)/' Makefile && make start-infra"
		printf '%s\n' "${LABCTL_MONO_STAGE_GODCAPP_INFRA_COMMAND:-$default_command}"
		;;
	godcapp-services) printf '%s\n' "${LABCTL_MONO_STAGE_GODCAPP_SERVICES_COMMAND:-cd NVO/scripts/development && make start-services}" ;;
	*) return 1 ;;
	esac
}

labctl_stack_stage() {
	local ticket=$1 stage=$2 command root mono_dir
	root=$(labctl_workspace_ticket_root "$ticket") || return 1
	if mono_dir=$(labctl_workspace_mono_dir "$root"); then
		command=$(labctl_mono_stage_command "$stage") || {
			labctl_die "invalid sandbox stage: $stage"
			return 1
		}
		[[ $mono_dir == . ]] || command="cd $mono_dir && $command"
		printf 'stage: %s ticket=%s (monorepo)\n' "$stage" "$ticket"
		labctl_stack_run "$ticket" "$command"
		return
	fi
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
	local ticket=$1 root identity uid gid
	local -a identity_fields
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
	identity=$(labctl_incus_resolve_workspace_identity "$LABCTL_MASTER_ROOT" "$root") || return 1
	mapfile -t identity_fields <<<"$identity"
	[[ ${#identity_fields[@]} == 3 ]] || {
		labctl_die 'workspace identity resolver returned an invalid identity'
		return 1
	}
	uid=${identity_fields[1]}
	gid=${identity_fields[2]}
	[[ $uid =~ ^[0-9]+$ && $gid =~ ^[0-9]+$ ]] || {
		labctl_die 'workspace identity resolver returned an invalid identity'
		return 1
	}
	# shellcheck disable=SC2016 # The guest shell validates its positional arguments and owns probe cleanup.
	labctl_run incus exec "$ticket" -- su - "$LABCTL_INSTANCE_USER" -c 'set -euo pipefail
instance_user=$1
expected_uid=$2
expected_gid=$3
shifted_mounts=("$4" "$5")
[[ $# == 5 && $expected_uid =~ ^[0-9]+$ && $expected_gid =~ ^[0-9]+$ ]] || {
	printf "invalid workspace identity verification arguments\\n" >&2
	exit 1
}
[[ $(id -u "$instance_user") == "$expected_uid" ]] || {
	printf "guest user UID does not match workspace identity\\n" >&2
	exit 1
}
[[ $(id -g "$instance_user") == "$expected_gid" ]] || {
	printf "guest user GID does not match workspace identity\\n" >&2
	exit 1
}
probes=()
cleanup() {
	local status=$? probe
	for probe in "${probes[@]}"; do
		rm -rf -- "$probe" || true
	done
	exit "$status"
}
trap cleanup EXIT
for mount in "${shifted_mounts[@]}"; do
	[[ $(stat -c '\''%u:%g'\'' -- "$mount") == "$expected_uid:$expected_gid" ]] || {
		printf "shifted mount ownership does not match workspace identity: %s\\n" "$mount" >&2
		exit 1
	}
	probe=$(mktemp -d "$mount/.labctl-write-probe.XXXXXX")
	probes+=("$probe")
done' -- "$LABCTL_INSTANCE_USER" "$uid" "$gid" "$LABCTL_MASTER_ROOT" "$root" || return 1
	labctl_run incus exec "$ticket" -- docker info
	labctl_stack_health "$ticket"
	labctl_verify_ports "$ticket"
	printf 'manual check required: verify GNS3/device routing to the sandbox IP through an approved probe path\n'
}
