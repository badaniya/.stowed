#!/usr/bin/env bash
# Stack hooks and network verification for ticket-scoped labctl sandboxes.
set -euo pipefail

# Stack hook values are trusted, private configuration. They are deliberately not
# interpreted by the host: each runs inside its instance. An optional third
# argument selects a monorepo hook, relative to the detected monorepo directory.
labctl_stack_run() {
	local ticket=$1 hook=$2 mono_hook=${3:-} root mono_dir
	ticket=$(labctl_normalize_ticket "$ticket") || return 1
	root=$(labctl_workspace_ticket_root "$ticket") || return 1
	if [[ -n $mono_hook ]] && mono_dir=$(labctl_workspace_mono_dir "$root"); then
		hook=$mono_hook
		if [[ $mono_dir != . ]]; then
			printf -v mono_dir '%q' "$mono_dir"
			hook="cd $mono_dir && $hook"
		fi
	fi
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

# Succeeds when the ticket's workspace contains a monorepo worktree.
labctl_stack_is_mono() {
	local ticket root
	ticket=$(labctl_normalize_ticket "$1") || return 1
	root=$(labctl_workspace_ticket_root "$ticket") || return 1
	labctl_workspace_mono_dir "$root" >/dev/null
}

labctl_stack_up() {
	local command=${LABCTL_MONO_STACK_UP_COMMAND:-} stage stage_command
	# Monorepo stage commands are required only for monorepo workspaces.
	labctl_stack_is_mono "$1" || command=
	if [[ -z $command ]] && labctl_stack_is_mono "$1"; then
		# Isolate each stage's cd while retaining one fail-fast guest hook.
		for stage in shared db platform-build platform-start app-infra app-build app-services; do
			stage_command=$(labctl_mono_stage_command "$stage") || return 1
			[[ -z $command ]] || command+=' && '
			printf -v stage_command '(\n%s\n)' "$stage_command"
			command+=$stage_command
		done
	fi
	labctl_stack_run "$1" "$LABCTL_STACK_UP_COMMAND" "$command"
}

labctl_stack_down() {
	if labctl_stack_is_mono "$1"; then
		[[ -n ${LABCTL_MONO_STACK_DOWN_COMMAND:-} ]] || {
			labctl_die 'set LABCTL_MONO_STACK_DOWN_COMMAND in the labctl configuration'
			return 1
		}
	fi
	labctl_stack_run "$1" "$LABCTL_STACK_DOWN_COMMAND" "${LABCTL_MONO_STACK_DOWN_COMMAND:-}"
}

labctl_stack_health() {
	labctl_stack_run "$1" "$LABCTL_STACK_HEALTH_COMMAND" \
		"${LABCTL_MONO_STACK_HEALTH_COMMAND:-docker info}"
}

# Monorepo stage commands; each runs from the monorepo worktree. Only the
# shared stage has a default: the others are project-specific, so they live in
# the private labctl configuration as LABCTL_MONO_STAGE_<STAGE>_COMMAND.
labctl_mono_stage_command() {
	local name command
	case $1 in
	# Existing golden images may lack file. Go-installed tools need GOPATH/bin.
	shared) printf '%s\n' "${LABCTL_MONO_STAGE_SHARED_COMMAND:-if ! command -v file >/dev/null 2>&1; then sudo apt-get update && sudo apt-get install -y --no-install-recommends file; fi && mkdir -p \"\$(go env GOPATH)/bin\"}" ;;
	db | platform-build | platform-start | app-build | app-infra | app-services)
		name=${1^^}
		name="LABCTL_MONO_STAGE_${name//-/_}_COMMAND"
		command=${!name:-}
		[[ -n $command ]] || {
			labctl_die "set $name in the labctl configuration"
			return 1
		}
		printf '%s\n' "$command"
		;;
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
	db) command=$LABCTL_STAGE_DB_COMMAND ;;
	platform-build) command=$LABCTL_STAGE_PLATFORM_BUILD_COMMAND ;;
	platform-start) command=$LABCTL_STAGE_PLATFORM_START_COMMAND ;;
	app-build) command=$LABCTL_STAGE_APP_BUILD_COMMAND ;;
	app-infra) command=$LABCTL_STAGE_APP_INFRA_COMMAND ;;
	app-services) command=$LABCTL_STAGE_APP_SERVICES_COMMAND ;;
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
	labctl_run incus exec "$ticket" -- runuser -u "$LABCTL_INSTANCE_USER" -- bash -c 'set -euo pipefail
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
done' labctl-verify "$LABCTL_INSTANCE_USER" "$uid" "$gid" "$LABCTL_MASTER_ROOT" "$root" || return 1
	labctl_run incus exec "$ticket" -- docker info
	labctl_stack_health "$ticket"
	labctl_verify_ports "$ticket"
	printf 'manual check required: verify GNS3/device routing to the sandbox IP through an approved probe path\n'
}
