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
	incus query "/1.0/profiles/$encoded_profile?project=$(jq -rn --arg project "$LABCTL_INCUS_PROJECT" '$project | @uri')"
}

labctl_incus_ensure_profile() {
	labctl_incus_validate_profile_name "$LABCTL_INCUS_PROFILE" || return 1
	if ! labctl_incus_profile_query "$LABCTL_INCUS_PROFILE" >/dev/null 2>&1; then
		labctl_run incus --project "$LABCTL_INCUS_PROJECT" profile create "$LABCTL_INCUS_PROFILE"
	fi

	labctl_run incus --project "$LABCTL_INCUS_PROJECT" profile set "$LABCTL_INCUS_PROFILE" security.privileged=false
	labctl_run incus --project "$LABCTL_INCUS_PROJECT" profile set "$LABCTL_INCUS_PROFILE" security.nesting=true
	labctl_run incus --project "$LABCTL_INCUS_PROJECT" profile set "$LABCTL_INCUS_PROFILE" security.syscalls.intercept.mknod=true
	labctl_run incus --project "$LABCTL_INCUS_PROJECT" profile set "$LABCTL_INCUS_PROFILE" security.syscalls.intercept.setxattr=true
	labctl_run incus --project "$LABCTL_INCUS_PROJECT" profile set "$LABCTL_INCUS_PROFILE" limits.cpu=4
	labctl_run incus --project "$LABCTL_INCUS_PROJECT" profile set "$LABCTL_INCUS_PROFILE" limits.memory=6GiB
	labctl_run incus --project "$LABCTL_INCUS_PROJECT" profile set "$LABCTL_INCUS_PROFILE" limits.memory.enforce=hard
	labctl_run incus --project "$LABCTL_INCUS_PROJECT" profile set "$LABCTL_INCUS_PROFILE" limits.memory.swap=false
	labctl_run incus --project "$LABCTL_INCUS_PROJECT" profile set "$LABCTL_INCUS_PROFILE" limits.processes=4096
	if incus --project "$LABCTL_INCUS_PROJECT" profile device get "$LABCTL_INCUS_PROFILE" eth0 network >/dev/null 2>&1; then
		labctl_run incus --project "$LABCTL_INCUS_PROJECT" profile device set "$LABCTL_INCUS_PROFILE" eth0 network="$LABCTL_AGENT_BRIDGE"
	else
		labctl_run incus --project "$LABCTL_INCUS_PROJECT" profile device add "$LABCTL_INCUS_PROFILE" eth0 nic network="$LABCTL_AGENT_BRIDGE" name=eth0
	fi
	if incus --project "$LABCTL_INCUS_PROJECT" profile device get "$LABCTL_INCUS_PROFILE" root pool >/dev/null 2>&1; then
		labctl_run incus --project "$LABCTL_INCUS_PROJECT" profile device set "$LABCTL_INCUS_PROFILE" root pool="$LABCTL_INCUS_STORAGE_POOL"
	else
		labctl_run incus --project "$LABCTL_INCUS_PROJECT" profile device add "$LABCTL_INCUS_PROFILE" root disk path=/ pool="$LABCTL_INCUS_STORAGE_POOL"
	fi
}

labctl_incus_docker_daemon_json() {
	jq -cn \
		--arg dns_servers "$LABCTL_DOCKER_DNS_SERVERS" \
		--arg insecure_registries "$LABCTL_INTERNAL_INSECURE_REGISTRIES" \
		'{dns: ($dns_servers | split(",")), "insecure-registries": ($insecure_registries | split(","))}'
}

labctl_incus_render_cloud_init() {
	local output=$1 template_dir template docker_daemon_json line indent
	template_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../share/labctl" && pwd)
	template=$template_dir/cloud-init.yaml.tmpl
	[[ -r $template ]] || {
		labctl_die "cloud-init template is missing: $template"
		return 1
	}
	docker_daemon_json=$(labctl_incus_docker_daemon_json)
	umask 077
	while IFS= read -r line || [[ -n $line ]]; do
		case $line in
		*__LABCTL_DOCKER_DAEMON_JSON__*)
			indent=${line%%[^[:space:]]*}
			printf '%s%s\n' "$indent" "$docker_daemon_json"
			;;
		*)
			line=${line//__LABCTL_INSTANCE_USER__/$LABCTL_INSTANCE_USER}
			line=${line//__LABCTL_GO_VERSION__/$LABCTL_GO_VERSION}
			printf '%s\n' "$line"
			;;
		esac
	done <"$template" >"$output"
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

labctl_incus_set_cloud_init() {
	local instance=$1 cloud_init=$2
	printf '+ incus config set %q user.user-data - < [private cloud-init]\n' "$instance"
	if [[ ${LABCTL_DRY_RUN:-false} == true ]]; then
		return 0
	fi
	incus --project "$LABCTL_INCUS_PROJECT" config set "$instance" user.user-data - <"$cloud_init"
}

labctl_incus_launch() {
	local ticket=$1 ip=$2 instance
	instance=$(labctl_normalize_ticket "$ticket") || return 1
	labctl_config_is_ipv4 "$ip" || {
		labctl_die "invalid sandbox IP address: $ip"
		return 1
	}
	labctl_incus_validate_launch_profiles || return 1
	local -a image_check=(python3 "$(dirname "${BASH_SOURCE[0]}")/ensure-private-image.py" --image "$LABCTL_INSTANCE_IMAGE" --project "$LABCTL_INCUS_PROJECT")
	[[ ${LABCTL_DRY_RUN:-false} != true ]] || image_check+=(--dry-run)
	"${image_check[@]}" || return 1
	labctl_run incus init "$LABCTL_INSTANCE_IMAGE" "$instance" --profile default --profile "$LABCTL_INCUS_PROFILE"
	labctl_run incus config device override "$instance" eth0 ipv4.address="$ip"
	labctl_run incus start "$instance"
}

labctl_incus_redact_systemd_credentials() {
	jq '
		def redact_credentials:
			if type == "object" then
				with_entries(
					if (.key | startswith("systemd.credential.")) then .value = "[REDACTED]" else . end
				)
			else
				.
			end;
		.config |= redact_credentials |
		.expanded_config |= redact_credentials
	'
}

labctl_incus_instance_query() {
	local instance=$1 normalized encoded_instance instance_json api_path
	normalized=$(labctl_normalize_ticket "$instance") || return 1
	[[ $instance == "$normalized" ]] || {
		labctl_die "invalid Incus instance name: $instance"
		return 1
	}
	encoded_instance=$(jq -rn --arg instance "$instance" '$instance | @uri') || {
		labctl_die "unable to encode Incus instance name: $instance"
		return 1
	}
	api_path=$(labctl_incus_instance_api_path "$instance") || return 1
	instance_json=$(incus query "$api_path" 2>&1) || {
		labctl_die "unable to inspect sandbox configuration: $instance"
		return 1
	}
	labctl_incus_redact_systemd_credentials <<<"$instance_json" || {
		labctl_die "unable to sanitize sandbox configuration: $instance"
		return 1
	}
}

labctl_incus_inspect() {
	labctl_incus_instance_query "$1"
}

labctl_incus_instance_exists() {
	incus --project "$LABCTL_INCUS_PROJECT" info "$1" >/dev/null 2>&1
}

labctl_incus_instance_ip() {
	incus --project "$LABCTL_INCUS_PROJECT" config device get "$1" eth0 ipv4.address
}

labctl_incus_is_running() {
	labctl_incus_instance_query "$1" | jq -e '.status == "Running"' >/dev/null
}

labctl_incus_resolve_workspace_identity() {
	local master_root=$1 ticket_root=$2 master_metadata ticket_metadata
	local master_uid master_gid master_mode ticket_uid ticket_gid ticket_mode
	local candidate_uid passwd_entry username account_uid primary_gid candidate_groups
	local root root_index root_uid root_gid root_mode candidate_group permission_bits access_class
	local candidate_has_group candidate_is_eligible minimum_class total_class
	local selected_username='' selected_uid='' selected_gid='' selected_minimum_class=0 selected_total_class=0
	local -a candidate_uids root_uids root_gids root_modes groups

	for root in "$master_root" "$ticket_root"; do
		[[ -d $root ]] || {
			labctl_die "workspace root is missing or not a directory: $root"
			return 1
		}
	done
	master_metadata=$(stat -c '%u %g %a' -- "$master_root") || {
		labctl_die "unable to inspect workspace root: $master_root"
		return 1
	}
	ticket_metadata=$(stat -c '%u %g %a' -- "$ticket_root") || {
		labctl_die "unable to inspect workspace root: $ticket_root"
		return 1
	}
	read -r master_uid master_gid master_mode <<<"$master_metadata"
	read -r ticket_uid ticket_gid ticket_mode <<<"$ticket_metadata"
	[[ $master_uid =~ ^[0-9]+$ && $master_gid =~ ^[0-9]+$ && $master_mode =~ ^[0-7]{3,4}$ && $ticket_uid =~ ^[0-9]+$ && $ticket_gid =~ ^[0-9]+$ && $ticket_mode =~ ^[0-7]{3,4}$ ]] || {
		labctl_die 'unable to read numeric workspace ownership and mode metadata'
		return 1
	}

	candidate_uids=("$master_uid")
	[[ $ticket_uid == "$master_uid" ]] || candidate_uids+=("$ticket_uid")
	root_uids=("$master_uid" "$ticket_uid")
	root_gids=("$master_gid" "$ticket_gid")
	root_modes=("${master_mode: -3}" "${ticket_mode: -3}")
	for candidate_uid in "${candidate_uids[@]}"; do
		[[ $candidate_uid != 0 ]] || continue
		passwd_entry=$(getent passwd "$candidate_uid") || continue
		IFS=: read -r username _ account_uid primary_gid _ <<<"$passwd_entry"
		[[ -n $username && $account_uid == "$candidate_uid" && $primary_gid =~ ^[0-9]+$ ]] || continue
		candidate_groups=$(id -G "$username") || continue
		IFS=' ' read -r -a groups <<<"$candidate_groups"

		candidate_is_eligible=true
		minimum_class=4
		total_class=0
		for root_index in 0 1; do
			root_uid=${root_uids[$root_index]}
			root_gid=${root_gids[$root_index]}
			root_mode=${root_modes[$root_index]}
			if [[ $candidate_uid == "$root_uid" ]]; then
				access_class=3
				permission_bits=$((8#${root_mode:0:1}))
			else
				candidate_has_group=false
				for candidate_group in "${groups[@]}"; do
					if [[ $candidate_group == "$root_gid" ]]; then
						candidate_has_group=true
						break
					fi
				done
				if [[ $candidate_has_group == true ]]; then
					access_class=2
					permission_bits=$((8#${root_mode:1:1}))
				else
					access_class=1
					permission_bits=$((8#${root_mode:2:1}))
				fi
			fi
			if (( (permission_bits & 3) != 3 )); then
				candidate_is_eligible=false
				break
			fi
			(( access_class < minimum_class )) && minimum_class=$access_class
			total_class=$((total_class + access_class))
		done
		[[ $candidate_is_eligible == true ]] || continue
		if (( minimum_class > selected_minimum_class || (minimum_class == selected_minimum_class && total_class > selected_total_class) )); then
			selected_username=$username
			selected_uid=$candidate_uid
			selected_gid=$primary_gid
			selected_minimum_class=$minimum_class
			selected_total_class=$total_class
		fi
	done
	[[ -n $selected_username ]] || {
		labctl_die 'no common writable host identity'
		return 1
	}
	printf '%s\n%s\n%s\n' "$selected_username" "$selected_uid" "$selected_gid"
}

labctl_incus_attach_workspace() {
	local instance=$1 ticket_root=$2
	labctl_run incus config device add "$instance" git-master disk source="$LABCTL_MASTER_ROOT" path="$LABCTL_MASTER_ROOT" shift=true readonly=false
	labctl_run incus config device add "$instance" ticket-workspace disk source="$ticket_root" path="$ticket_root" shift=true readonly=false
}

labctl_incus_ensure_instance_user() {
	local instance=$1 username=$2 uid=$3 gid=$4
	# shellcheck disable=SC2016 # The guest shell validates and expands only its positional arguments.
	labctl_run incus exec "$instance" -- bash -c 'set -euo pipefail
username=$1
uid=$2
gid=$3
[[ $# == 3 && $username =~ ^[a-z_][a-z0-9_-]*[$]?$ && $uid =~ ^[1-9][0-9]*$ && $gid =~ ^[1-9][0-9]*$ ]] || {
	printf "invalid requested guest identity\\n" >&2
	exit 1
}
if getent passwd "$username" >/dev/null; then
	[[ $(id -u "$username") == "$uid" && $(id -g "$username") == "$gid" ]] || {
		printf "guest user %s does not match requested UID:GID %s:%s; recreate the sandbox\\n" "$username" "$uid" "$gid" >&2
		exit 1
	}
else
	for supplementary_group in sudo docker; do
		getent group "$supplementary_group" >/dev/null || {
			printf "required guest group is missing: %s\\n" "$supplementary_group" >&2
			exit 1
		}
	done
	if [[ $uid == 1000 && $gid == 1000 ]] && getent passwd ubuntu >/dev/null && [[ $(id -u ubuntu) == 1000 && $(id -g ubuntu) == 1000 ]] && ubuntu_group=$(getent group ubuntu) && [[ ${ubuntu_group#*:*:} == 1000:* ]]; then
		getent group "$username" >/dev/null && {
			printf "guest group name is already in use: %s; recreate the sandbox\\n" "$username" >&2
			exit 1
		}
		[[ ! -e "/home/$username" ]] || {
			printf "guest home already exists: /home/%s; recreate the sandbox\\n" "$username" >&2
			exit 1
		}
		usermod --login "$username" --home "/home/$username" --move-home ubuntu
		groupmod --new-name "$username" ubuntu
	else
		getent passwd "$uid" >/dev/null && {
			printf "guest UID is already in use: %s; recreate the sandbox\\n" "$uid" >&2
			exit 1
		}
		getent group "$gid" >/dev/null && {
			printf "guest GID is already in use: %s; recreate the sandbox\\n" "$gid" >&2
			exit 1
		}
		getent group "$username" >/dev/null && {
			printf "guest group name is already in use: %s; recreate the sandbox\\n" "$username" >&2
			exit 1
		}
		groupadd --gid "$gid" "$username"
		useradd --uid "$uid" --gid "$gid" --create-home --shell /bin/bash "$username"
	fi
fi
install -d -m 0755 -o "$username" -g "$gid" "/home/$username"
usermod --append --groups sudo,docker "$username"
sudoers_file="/etc/sudoers.d/labctl-$username"
sudoers_temporary=$(mktemp)
printf "%s ALL=(ALL) NOPASSWD: ALL\\n" "$username" >"$sudoers_temporary"
chmod 0440 "$sudoers_temporary"
visudo -cf "$sudoers_temporary" >/dev/null
install -o root -g root -m 0440 "$sudoers_temporary" "$sudoers_file"
rm -f -- "$sudoers_temporary"' -- "$username" "$uid" "$gid"
}

labctl_incus_wait_ready() {
	local instance=$1 ticket_root=$2 identity username uid gid
	local -a identity_fields
	identity=$(labctl_incus_resolve_workspace_identity "$LABCTL_MASTER_ROOT" "$ticket_root") || return 1
	mapfile -t identity_fields <<<"$identity"
	[[ ${#identity_fields[@]} == 3 ]] || {
		labctl_die 'workspace identity resolver returned an invalid identity'
		return 1
	}
	username=${identity_fields[0]}
	uid=${identity_fields[1]}
	gid=${identity_fields[2]}
	[[ -n $username && $uid =~ ^[0-9]+$ && $gid =~ ^[0-9]+$ ]] || {
		labctl_die 'workspace identity resolver returned an invalid identity'
		return 1
	}
	labctl_incus_ensure_instance_user "$instance" "$LABCTL_INSTANCE_USER" "$uid" "$gid"
	# Docker may be started by the guest init system after Incus reports the container running.
	# Do not require a systemd bus; wait for the daemon socket with a bounded retry.
	# shellcheck disable=SC2016 # The guest shell evaluates the retry loop.
	labctl_run incus exec "$instance" -- bash -c 'for attempt in $(seq 1 300); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; printf "Docker daemon did not become ready within five minutes\n" >&2; exit 1'
	labctl_run incus exec "$instance" -- docker info
}

labctl_incus_configure_network() {
	local instance=$1 docker_daemon_json command ip prefix
	local -a dns_servers
	mapfile -t dns_servers < <(tr ',' '\n' <<<"$LABCTL_DOCKER_DNS_SERVERS")
	ip=$(labctl_incus_instance_ip "$instance") || return 1
	prefix=${LABCTL_AGENT_CIDR#*/}
	docker_daemon_json=$(labctl_incus_docker_daemon_json) || return 1
	# shellcheck disable=SC2016 # The guest shell expands its positional DNS arguments.
	printf -v command 'set -euo pipefail; ip link set eth0 up; ip addr replace "$1/$2" dev eth0; ip route replace default via "$3" dev eth0; shift 3; rm -f /etc/resolv.conf; : >/etc/resolv.conf; for server in "$@"; do printf "nameserver %%s\\n" "$server" >>/etc/resolv.conf; done; install -d -m 0755 /etc/docker; cat >/etc/docker/daemon.json <<%q\n%s\n%q\n' \
		'LABCTL_DOCKER_DAEMON_JSON' "$docker_daemon_json" 'LABCTL_DOCKER_DAEMON_JSON'
	# The private DNS and registry values are arguments, never printed in the lifecycle log.
	printf '+ incus exec %q -- bash -c [private network configuration]\n' "$instance"
	if [[ ${LABCTL_DRY_RUN:-false} == true ]]; then
		return 0
	fi
	LABCTL_FAKE_PRIVATE_NETWORK_CONFIGURATION=true incus --project "$LABCTL_INCUS_PROJECT" exec "$instance" -- bash -c "$command" -- "$ip" "$prefix" "$LABCTL_AGENT_GATEWAY" "${dns_servers[@]}"
}

labctl_incus_configure_git_safe_directories() {
	local instance=$1 ticket_root=$2 worktree repository_root command
	while IFS= read -r worktree; do
		labctl_run incus exec "$instance" -- git config --global --add safe.directory "$worktree" </dev/null
		printf -v command 'git config --global --add safe.directory %q' "$worktree"
		labctl_run incus exec "$instance" -- su - "$LABCTL_INSTANCE_USER" -c "$command" </dev/null
		repository_root=$(git -C "$worktree" rev-parse --show-toplevel 2>/dev/null || true)
		if [[ -n $repository_root && $repository_root != "$worktree" ]]; then
			labctl_run incus exec "$instance" -- git config --global --add safe.directory "$repository_root" </dev/null
			printf -v command 'git config --global --add safe.directory %q' "$repository_root"
			labctl_run incus exec "$instance" -- su - "$LABCTL_INSTANCE_USER" -c "$command" </dev/null
		fi
	done < <(labctl_workspace_linked_worktrees "$ticket_root")
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
	instance_json=$(labctl_incus_instance_query "$instance") || {
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
	instance_json=$(labctl_incus_instance_query "$instance") || {
		labctl_die "unable to inspect sandbox configuration: $instance"
		return 1
	}
	if labctl_incus_instance_is_unsafe "$instance_json"; then
		labctl_die "sandbox configuration violates isolation policy: $instance"
		return 1
	fi
}

labctl_incus_stack_command() (
	set -euo pipefail
	local instance=$1 ticket_root=$2 command=$3 helper
	helper="$(dirname "${BASH_SOURCE[0]}")/../../share/labctl/stack-wrapper.sh"
	[[ -r $helper ]] || { labctl_die 'stack wrapper is missing'; return 1; }
	labctl_incus_set_systemd_credential "$instance" "$LABCTL_GIT_CREDENTIAL_NAME" || return 1
	if [[ -n ${LABCTL_LOGGO_TEMPLATE_PATH:-}${LABCTL_LOGGO_PASS_REFERENCE:-} ]]; then
		labctl_incus_sync_loggo_template "$instance" || return 1
	fi
	if [[ -n ${LABCTL_MONOREPO_ENV_SOURCE_PATH:-} ]]; then
		labctl_incus_sync_monorepo_environment "$instance" "$instance" || return 1
	fi
	if [[ ${LABCTL_DRY_RUN:-false} == true ]]; then
		printf '+ sandbox stack command via stdin: %s\n' "$instance"
		return 0
	fi
	{
		printf 'stack_command=%q\n' "$command"
		cat "$helper"
	} | labctl_run incus --project "$LABCTL_INCUS_PROJECT" exec "$instance" -- bash -s -- \
		"$ticket_root" "$LABCTL_GIT_CREDENTIAL_NAME" "$LABCTL_GIT_HOST" "$LABCTL_INSTANCE_USER"
)

labctl_incus_start() {
	local instance=$1 ticket_root=$2
	if ! labctl_incus_is_running "$instance"; then
		labctl_run incus start "$instance"
	fi
	labctl_incus_configure_network "$instance"
	labctl_incus_wait_ready "$instance" "$ticket_root"
	labctl_stack_up "$instance"
}

labctl_incus_stop() {
	local instance=$1 ticket_root=$2
	if ! labctl_stack_down "$instance"; then
		printf 'warning: sandbox stack-down hook failed; continuing with instance stop: %s\n' "$instance" >&2
	fi
	labctl_run incus stop "$instance"
}

labctl_incus_validate_credential_name() { labctl_config_validate_credential_name "$1"; }

labctl_incus_instance_api_path() {
	local instance=$1 normalized encoded_instance
	normalized=$(labctl_normalize_ticket "$instance") || return 1
	[[ $instance == "$normalized" ]] || {
		labctl_die "invalid Incus instance name: $instance"
		return 1
	}
	encoded_instance=$(jq -rn --arg instance "$instance" '$instance | @uri') || return 1
	printf '/1.0/instances/%s?project=%s\n' "$encoded_instance" "$(jq -rn --arg project "$LABCTL_INCUS_PROJECT" '$project | @uri')"
}

labctl_incus_set_systemd_credential() {
	local instance=$1 credential_name=$2 helper
	labctl_incus_validate_credential_name "$credential_name" || return 1
	if [[ ${LABCTL_DRY_RUN:-false} == true ]]; then
		printf '+ pass-backed sandbox memory credential sync: %s\n' "$instance"
		return 0
	fi
	helper="$(dirname "${BASH_SOURCE[0]}")/pass-credential-sync.py"
	python3 "$helper" sync --instance "$instance" --project "$LABCTL_INCUS_PROJECT" \
		--host "$LABCTL_GIT_HOST" --name "$credential_name" --user "$LABCTL_INSTANCE_USER"
}

labctl_incus_set_systemd_credential_file() {
	local instance=$1 credential_name=$2 source_file=$3 format helper
	labctl_incus_validate_credential_name "$credential_name" || return 1
	case $credential_name in
		loggo-template) format=loggo-template ;;
		monorepo-environment) format=environment ;;
		*) labctl_die 'unsupported private memory input'; return 1 ;;
	esac
	if [[ ${LABCTL_DRY_RUN:-false} == true ]]; then
		printf '+ private input via sandbox memory: %s\n' "$credential_name"
		return 0
	fi
	helper="$(dirname "${BASH_SOURCE[0]}")/pass-credential-sync.py"
	python3 "$helper" blob --instance "$instance" --project "$LABCTL_INCUS_PROJECT" \
		--host "$LABCTL_GIT_HOST" --name "$credential_name" --user "$LABCTL_INSTANCE_USER" \
		--format "$format" --source "$source_file"
}

labctl_incus_sync_loggo_template() {
	local instance=$1 template=${LABCTL_LOGGO_TEMPLATE_PATH:-} reference=${LABCTL_LOGGO_PASS_REFERENCE:-} helper
	if [[ -n $reference ]]; then
		if [[ ${LABCTL_DRY_RUN:-false} == true ]]; then
			printf '+ pass-backed template via sandbox memory: %s\n' "$instance"
			return 0
		fi
		helper="$(dirname "${BASH_SOURCE[0]}")/pass-credential-sync.py"
		python3 "$helper" blob --instance "$instance" --project "$LABCTL_INCUS_PROJECT" \
			--host "$LABCTL_GIT_HOST" --name loggo-template --user "$LABCTL_INSTANCE_USER" \
			--format loggo-template --pass-reference "$reference"
	else
		[[ -n $template ]] || { labctl_die 'configure a Loggo template path or pass reference'; return 1; }
		labctl_incus_set_systemd_credential_file "$instance" loggo-template "$template"
	fi
}

labctl_incus_sync_monorepo_environment() (
	set -euo pipefail
	local instance=$1 ticket=$2 helper rendered
	local -a log_dirs=()
	read -r -a log_dirs <<<"${LABCTL_MONOREPO_SERVICE_LOG_DIRS:-}"
	if [[ ${LABCTL_DRY_RUN:-false} == true ]]; then
		printf '+ monorepo environment via sandbox memory: %s\n' "$instance"
		return 0
	fi
	helper="$(dirname "${BASH_SOURCE[0]}")/pass-credential-sync.py"
	# Validate the complete render in memory before replacing any live broker input.
	rendered=$(labctl_monorepo_env_render "$ticket" -) || return 1
	printf '%s\n' "$rendered" | python3 "$helper" blob \
		--instance "$instance" --project "$LABCTL_INCUS_PROJECT" --host "$LABCTL_GIT_HOST" \
		--name monorepo-environment --user "$LABCTL_INSTANCE_USER" --format environment --source -
	labctl_run incus --project "$LABCTL_INCUS_PROJECT" exec "$instance" -- bash -s -- "$LABCTL_INSTANCE_USER" "${log_dirs[@]}" <<'SCRIPT'
set -euo pipefail
username=$1
shift
for service in "$@"; do
  [[ $service =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || exit 1
  install -d -m 0755 -o "$username" -g "$username" "/var/log/$service"
done
SCRIPT
)

labctl_incus_unset_systemd_credential() {
	local instance=$1 credential_name=$2 helper
	labctl_incus_validate_credential_name "$credential_name" || return 1
	if [[ ${LABCTL_DRY_RUN:-false} == true ]]; then
		printf '+ sandbox memory credential unset: %s\n' "$instance"
		return 0
	fi
	helper="$(dirname "${BASH_SOURCE[0]}")/pass-credential-sync.py"
	python3 "$helper" unset --instance "$instance" --project "$LABCTL_INCUS_PROJECT" \
		--host "$LABCTL_GIT_HOST" --name "$credential_name" --user "$LABCTL_INSTANCE_USER"
}
