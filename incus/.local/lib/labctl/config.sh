#!/usr/bin/env bash
# Private configuration loading and validation for labctl.
set -euo pipefail

labctl_config_required_vars=(
	LABCTL_WORKSPACE_ROOT LABCTL_MASTER_ROOT LABCTL_AGENT_BRIDGE
	LABCTL_AGENT_CIDR LABCTL_AGENT_GATEWAY LABCTL_IP_POOL_START
	LABCTL_IP_POOL_END LABCTL_LAB_ROUTE_GATEWAY LABCTL_INSTANCE_IMAGE
	LABCTL_INSTANCE_USER LABCTL_GO_VERSION
	LABCTL_INTERNAL_INSECURE_REGISTRIES LABCTL_DOCKER_DNS_SERVERS LABCTL_DEVICE_TCP_PORTS LABCTL_STACK_UP_COMMAND
	LABCTL_STACK_DOWN_COMMAND LABCTL_STACK_HEALTH_COMMAND
	LABCTL_WORKTREE_CREATE_HOOK LABCTL_WORKTREE_REMOVE_HOOK
	LABCTL_HARNESS_REPO_NAMES LABCTL_GIT_HOST
)

labctl_config_optional_vars=(
	LABCTL_GIT_CREDENTIAL_NAME
)

labctl_config_validate_credential_name() {
	local name=$1
	[[ $name =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$ ]] || {
		labctl_die "invalid systemd credential name: $name"
		return 1
	}
}

labctl_config_is_ipv4() {
	local ip=$1 octet IFS=.
	local -a parts
	read -r -a parts <<<"$ip"
	((${#parts[@]} == 4)) || return 1
	for octet in "${parts[@]}"; do
		[[ $octet =~ ^[0-9]+$ ]] && ((10#$octet <= 255)) || return 1
	done
}

labctl_config_ipv4_number() {
	local ip=$1 a b c d IFS=.
	read -r a b c d <<<"$ip"
	printf '%u\n' "$((10#$a * 16777216 + 10#$b * 65536 + 10#$c * 256 + 10#$d))"
}

labctl_config_validate_registry_endpoint() {
	local endpoint=$1 host port
	[[ $endpoint == *:* ]] || return 1
	host=${endpoint%:*}
	port=${endpoint##*:}
	[[ -n $host && $port =~ ^[0-9]+$ ]] || return 1
	((10#$port >= 1 && 10#$port <= 65535)) || return 1
	labctl_config_is_ipv4 "$host" || [[ $host =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]
}

labctl_config_validate() {
	local name value mode cidr_ip prefix network mask start end
	for name in "${labctl_config_required_vars[@]}"; do
		value=${!name:-}
		[[ -n $value ]] || {
			labctl_die "missing required configuration: $name"
			return 1
		}
		[[ $value != *'REPLACE'* && $value != *'CHANGE_ME'* && $value != '<'* && $value != *'YOUR_'* ]] || {
			labctl_die "placeholder configuration is not allowed: $name"
			return 1
		}
	done

	[[ $LABCTL_WORKSPACE_ROOT == /* && $LABCTL_MASTER_ROOT == /* ]] || {
		labctl_die 'workspace and master roots must be absolute paths'
		return 1
	}
	[[ $LABCTL_MASTER_ROOT == "$LABCTL_WORKSPACE_ROOT"/* ]] || {
		labctl_die 'master root must be inside workspace root'
		return 1
	}
	[[ $LABCTL_GO_VERSION =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || {
		labctl_die 'Go version must use numeric semantic version format: MAJOR.MINOR.PATCH'
		return 1
	}
	[[ $LABCTL_GIT_HOST =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?(:[0-9]{1,5})?$ ]] || {
		labctl_die 'Git host must be an HTTPS host name with an optional port'
		return 1
	}
	if [[ -n ${LABCTL_GIT_CREDENTIAL_NAME:-} ]] && ! labctl_config_validate_credential_name "$LABCTL_GIT_CREDENTIAL_NAME"; then
		return 1
	fi
	[[ $LABCTL_AGENT_CIDR == */* ]] || {
		labctl_die 'invalid agent CIDR'
		return 1
	}
	cidr_ip=${LABCTL_AGENT_CIDR%/*}
	prefix=${LABCTL_AGENT_CIDR#*/}
	if ! labctl_config_is_ipv4 "$cidr_ip" || ! [[ $prefix =~ ^[0-9]+$ ]] || ! ((10#$prefix >= 1 && 10#$prefix <= 30)); then
		labctl_die 'invalid agent CIDR'
		return 1
	fi
	for name in LABCTL_AGENT_GATEWAY LABCTL_IP_POOL_START LABCTL_IP_POOL_END LABCTL_LAB_ROUTE_GATEWAY; do
		labctl_config_is_ipv4 "${!name}" || {
			labctl_die "invalid IPv4 address: $name"
			return 1
		}
	done
	network=$(labctl_config_ipv4_number "$cidr_ip")
	mask=$(((0xFFFFFFFF << (32 - 10#$prefix)) & 0xFFFFFFFF))
	start=$(labctl_config_ipv4_number "$LABCTL_IP_POOL_START")
	end=$(labctl_config_ipv4_number "$LABCTL_IP_POOL_END")
	((start <= end && (start & mask) == (network & mask) && (end & mask) == (network & mask))) || {
		labctl_die 'invalid IPv4 pool range'
		return 1
	}
	local endpoint dns_server port
	local -a endpoints dns_servers ports
	local -A seen_endpoints=() seen_dns_servers=() seen_ports=()
	[[ $LABCTL_INTERNAL_INSECURE_REGISTRIES =~ ^[^,]+(,[^,]+)*$ ]] || {
		labctl_die 'internal insecure registry list must contain comma-separated host:port endpoints'
		return 1
	}
	IFS=, read -r -a endpoints <<<"$LABCTL_INTERNAL_INSECURE_REGISTRIES"
	for endpoint in "${endpoints[@]}"; do
		labctl_config_validate_registry_endpoint "$endpoint" || {
			labctl_die 'internal insecure registry endpoints must be host:port values with valid ports'
			return 1
		}
		[[ ! ${seen_endpoints[$endpoint]+present} ]] || {
			labctl_die 'duplicate internal insecure registry endpoint'
			return 1
		}
		seen_endpoints[$endpoint]=1
	done
	[[ $LABCTL_DOCKER_DNS_SERVERS =~ ^[^,]+(,[^,]+)*$ ]] || {
		labctl_die 'Docker DNS server list must contain comma-separated IPv4 addresses'
		return 1
	}
	IFS=, read -r -a dns_servers <<<"$LABCTL_DOCKER_DNS_SERVERS"
	for dns_server in "${dns_servers[@]}"; do
		labctl_config_is_ipv4 "$dns_server" || {
			labctl_die 'Docker DNS servers must be valid IPv4 addresses'
			return 1
		}
		[[ ! ${seen_dns_servers[$dns_server]+present} ]] || {
			labctl_die 'duplicate Docker DNS server'
			return 1
		}
		seen_dns_servers[$dns_server]=1
	done
	[[ $LABCTL_DEVICE_TCP_PORTS =~ ^[0-9]+(,[0-9]+)*$ ]] || {
		labctl_die 'device TCP port list must not be empty and must contain comma-separated ports'
		return 1
	}
	IFS=, read -r -a ports <<<"$LABCTL_DEVICE_TCP_PORTS"
	for port in "${ports[@]}"; do
		((10#$port >= 1 && 10#$port <= 65535)) || {
			labctl_die "invalid device TCP port: $port"
			return 1
		}
		[[ ! ${seen_ports[$port]+present} ]] || {
			labctl_die "duplicate device TCP port: $port"
			return 1
		}
		seen_ports[$port]=1
	done
}

labctl_config_load() {
	local path=${1:-"${XDG_CONFIG_HOME:-$HOME/.config}/labctl/config.env"} mode
	[[ -f $path && -r $path ]] || {
		labctl_die "configuration is missing or unreadable: $path"
		return 1
	}
	[[ -O $path ]] || {
		labctl_die "configuration must be owned by the current user: $path"
		return 1
	}
	mode=$(stat -c '%a' -- "$path") || {
		labctl_die "unable to inspect configuration permissions: $path"
		return 1
	}
	(((8#$mode & 0022) == 0)) || {
		labctl_die "configuration must not be group- or world-writable: $path"
		return 1
	}
	local line line_number=0 name value
	local -A seen_names=()
	for name in "${labctl_config_required_vars[@]}" "${labctl_config_optional_vars[@]}"; do
		unset "$name"
	done
	while IFS= read -r line || [[ -n $line ]]; do
		line_number=$((line_number + 1))
		line=${line%$'\r'}
		[[ -z $line || $line == \#* ]] && continue
		if [[ ! $line =~ ^([A-Z][A-Z0-9_]*)=(.*)$ ]]; then
			labctl_die "invalid configuration entry at $path:$line_number"
			return 1
		fi
		name=${BASH_REMATCH[1]}
		value=${BASH_REMATCH[2]}
		case " ${labctl_config_required_vars[*]} ${labctl_config_optional_vars[*]} " in
		*" $name "*) ;;
		*)
			labctl_die "unrecognized configuration variable at $path:$line_number: $name"
			return 1
			;;
		esac
		[[ ! ${seen_names[$name]+present} ]] || {
			labctl_die "duplicate configuration variable at $path:$line_number: $name"
			return 1
		}
		seen_names[$name]=1
		printf -v "$name" '%s' "$value"
	done <"$path"
	: "${LABCTL_GIT_CREDENTIAL_NAME:=git-module-token}"
	labctl_config_validate || return 1
	LABCTL_CONFIG_PATH=$path
	export LABCTL_CONFIG_PATH
}
