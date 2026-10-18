#!/usr/bin/env bash
# Literal-only rendering of the NVO Development section from a private profile.
# shellcheck disable=SC2016,SC2129

labctl_nvo_env_allowed=(
	GOPRIVATE NVO_MessageBusHost NVO_MessageBusPort XIQ_MessageBusPort
	XIQ_HiveMiddlewarePort XIQ_GrpcCommonServicePort XIQ_GrpcHmwebPort
	CapWap_GrpcPort PeriodicDiscoveryInMinutes XiqGrpcGetDevicesPerPageLimit
	DBAUTOMIGRATE DBLOGLEVEL EnableWirelessDeviceOnboardingAndKafkaMessaging IMAGE_IMPORT
)

labctl_nvo_env_is_allowed() {
	local name=$1 allowed
	for allowed in "${labctl_nvo_env_allowed[@]}"; do [[ $name == "$allowed" ]] && return 0; done
	return 1
}

labctl_nvo_env_quote() {
	local value=$1
	value=${value//\'/\'\\\'}
	printf "'%s'" "$value"
}

labctl_nvo_env_render() {
	local ticket=$1 output=$2 source mode line in_section=false name value ip
	local -A seen=() values=()
	source=${LABCTL_NVO_ENV_SOURCE_PATH:-}
	[[ $source == /* && -f $source && -r $source && -O $source ]] || {
		labctl_die 'NVO environment source must be an absolute readable regular file owned by the current user'
		return 1
	}
	mode=$(stat -c '%a' -- "$source") || return 1
	(((8#$mode & 0077) == 0)) || {
		labctl_die 'NVO environment source must not be group- or world-accessible'
		return 1
	}
	while IFS= read -r line || [[ -n $line ]]; do
		if [[ $line == '###############################################################################' ]]; then
			[[ $in_section == true ]] && break
			continue
		fi
		[[ $line == '# NVO Development' ]] && { in_section=true; continue; }
		[[ $in_section == true ]] || continue
		[[ -z $line || $line == \\#* ]] && continue
		[[ $line =~ ^export[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]] || {
			labctl_die 'invalid NVO environment entry'
			return 1
		}
		name=${BASH_REMATCH[1]}; value=${BASH_REMATCH[2]}
		if [[ $value == \"*\" || $value == \'*\' ]]; then value=${value:1:${#value}-2}; fi
		case $name in
		NVO_UI_TOKEN | XIQ_HOST_IP | XIQ_MessageBusHost | XIQ_HiveMiddlewareHost | XIQ_GrpcCommonServiceHost | XIQ_GrpcHmwebHost | CapWap_GrpcHost | ApplicationName) continue ;;
		esac
		labctl_nvo_env_is_allowed "$name" || { labctl_die "unapproved NVO environment variable: $name"; return 1; }
		[[ ! ${seen[$name]+present} ]] || { labctl_die "duplicate NVO environment variable: $name"; return 1; }
		[[ $value != *'$('* && $value != *'`'* && $value != *';'* && $value != *'|'* && $value != *'&'* ]] || {
			labctl_die "unsafe NVO environment value: $name"; return 1;
		}
		seen[$name]=1; values[$name]=$value
	done <"$source"
	[[ $in_section == true ]] || { labctl_die 'NVO Development section is missing'; return 1; }
	ip=$(labctl_incus_instance_ip "$ticket") || return 1
	labctl_config_is_ipv4 "$ip" || { labctl_die 'sandbox has no valid routed IP'; return 1; }
	umask 077
	: >"$output"
	for name in "${labctl_nvo_env_allowed[@]}"; do
		[[ ${values[$name]+present} ]] || continue
		printf 'export %s=' "$name" >>"$output"
		labctl_nvo_env_quote "${values[$name]}" >>"$output"
		printf '\n' >>"$output"
	done
	for name in XIQ_HOST_IP XIQ_MessageBusHost XIQ_HiveMiddlewareHost XIQ_GrpcCommonServiceHost XIQ_GrpcHmwebHost CapWap_GrpcHost; do
		printf 'export %s=' "$name" >>"$output"; labctl_nvo_env_quote "$ip" >>"$output"; printf '\n' >>"$output"
	done
	printf 'export ApplicationName=' >>"$output"; labctl_nvo_env_quote "${LABCTL_INSTANCE_USER}:$(hostname):${ip}" >>"$output"; printf '\n' >>"$output"
	printf 'export XIQ_THREAD_POOL=100\n' >>"$output"
	chmod 600 "$output"
}
