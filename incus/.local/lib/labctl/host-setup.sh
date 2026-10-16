#!/usr/bin/env bash
# Read-only Incus coexistence checks and the narrowly scoped host setup actions.
set -euo pipefail

labctl_incus_required_commands=(incus jq flock docker ip sysctl df lxc multipass)

labctl_incus_require_commands() {
	local command
	for command in "${labctl_incus_required_commands[@]}"; do
		command -v "$command" >/dev/null 2>&1 || {
			labctl_die "required command is unavailable: $command"
			return 1
		}
	done
}

labctl_incus_cidr_overlaps() {
	local left=$1 right=$2 left_ip left_prefix right_ip right_prefix left_number right_number left_mask right_mask
	left_ip=${left%/*}
	left_prefix=${left#*/}
	right_ip=${right%/*}
	right_prefix=${right#*/}
	labctl_config_is_ipv4 "$left_ip" && labctl_config_is_ipv4 "$right_ip" || return 1
	[[ $left_prefix =~ ^[0-9]+$ && $right_prefix =~ ^[0-9]+$ ]] || return 1
	((10#$left_prefix >= 0 && 10#$left_prefix <= 32 && 10#$right_prefix >= 0 && 10#$right_prefix <= 32)) || return 1
	left_number=$(labctl_config_ipv4_number "$left_ip")
	right_number=$(labctl_config_ipv4_number "$right_ip")
	left_mask=$(((0xFFFFFFFF << (32 - 10#$left_prefix)) & 0xFFFFFFFF))
	right_mask=$(((0xFFFFFFFF << (32 - 10#$right_prefix)) & 0xFFFFFFFF))
	(((left_number & right_mask) == (right_number & right_mask) || (right_number & left_mask) == (left_number & left_mask)))
}

labctl_incus_inventory() {
	local inventory_name=$1 output
	shift
	if ! output=$("$@" 2>&1); then
		labctl_die "unable to inventory $inventory_name; inspect the service and retry"
		return 1
	fi
	printf '%s\n' "$output"
}

labctl_incus_reject_external_name_conflicts() {
	local name output resource
	local -a inventories

	output=$(labctl_incus_inventory 'LXD networks' lxc network list --format csv -c n) || return 1
	inventories+=("$output")
	output=$(labctl_incus_inventory 'LXD storage pools' lxc storage list --format csv -c n) || return 1
	inventories+=("$output")
	output=$(labctl_incus_inventory 'LXD profiles' lxc profile list --format csv -c n) || return 1
	inventories+=("$output")
	output=$(labctl_incus_inventory 'LXD instances' lxc list --format csv -c n) || return 1
	inventories+=("$output")
	output=$(labctl_incus_inventory 'Multipass instances' multipass list --format csv) || return 1
	inventories+=("$output")

	for name in "$LABCTL_AGENT_BRIDGE" "$LABCTL_INCUS_PROFILE" "$LABCTL_INCUS_STORAGE_POOL"; do
		for output in "${inventories[@]}"; do
			while IFS=, read -r resource _; do
				resource=${resource%$'\r'}
				resource=${resource#\"}
				resource=${resource%\"}
				[[ $resource == "$name" ]] || continue
				labctl_die "configured Incus name conflicts with existing LXD or Multipass resource: $name"
				return 1
			done <<<"$output"
		done
	done
}

labctl_incus_reject_network_conflicts() {
	local route destination routes
	if ip link show "$LABCTL_AGENT_BRIDGE" >/dev/null 2>&1 && ! incus network show "$LABCTL_AGENT_BRIDGE" >/dev/null 2>&1; then
		labctl_die "configured Incus bridge conflicts with an existing host bridge: $LABCTL_AGENT_BRIDGE"
		return 1
	fi
	routes=$(ip route show 2>&1) || {
		labctl_die 'unable to inventory host routes; inspect the host network and retry'
		return 1
	}
	while IFS= read -r route; do
		destination=${route%% *}
		[[ $destination == */* ]] || continue
		if labctl_incus_cidr_overlaps "$LABCTL_AGENT_CIDR" "$destination"; then
			labctl_die "configured agent subnet overlaps an existing host, LXD, or Multipass route: $destination"
			return 1
		fi
	done <<<"$routes"
}

labctl_incus_preflight() {
	local info profile_json available forwarding route
	labctl_incus_require_commands || return 1
	incus info >/dev/null 2>&1 || {
		labctl_die 'current user cannot access the Incus daemon'
		return 1
	}
	info=$(incus info --format json) || {
		labctl_die 'unable to inspect Incus capabilities'
		return 1
	}
	jq -e '.environment.kernel_features.idmapped_mounts == true or .environment.kernel_features.idmapped_mounts == "true"' >/dev/null <<<"$info" || {
		labctl_die 'Incus does not report idmapped mount support'
		return 1
	}
	available=$(df -Pk "$LABCTL_WORKSPACE_ROOT" | awk 'NR == 2 { print $4 }')
	[[ $available =~ ^[0-9]+$ && $available -gt 0 ]] || {
		labctl_die 'no usable storage is available for the workspace filesystem'
		return 1
	}
	forwarding=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || true)
	[[ $forwarding == 1 ]] || {
		labctl_die 'IPv4 forwarding must be enabled before provisioning sandboxes'
		return 1
	}
	route=$(ip route get "$LABCTL_LAB_ROUTE_GATEWAY" 2>/dev/null || true)
	[[ -n $route ]] || {
		labctl_die "configured lab route gateway is not routable: $LABCTL_LAB_ROUTE_GATEWAY"
		return 1
	}
	labctl_incus_reject_network_conflicts || return 1
	labctl_incus_reject_external_name_conflicts || return 1
	if profile_json=$(incus profile show "$LABCTL_INCUS_PROFILE" --format json 2>/dev/null); then
		if labctl_incus_profile_is_unsafe "$profile_json"; then
			labctl_die "active Incus profile has privileged, host-network, proxy, Docker socket, or host-device passthrough behavior: $LABCTL_INCUS_PROFILE"
			return 1
		fi
	fi
	printf '%s\n' 'labctl: operator prerequisite pending: install external-device static route for the agent subnet'
	printf '%s\n' 'labctl: operator prerequisite pending: permit only documented device TCP ports in the host firewall'
}

labctl_incus_setup_host() {
	local prefix gateway_cidr
	labctl_incus_preflight || return 1
	[[ ${LABCTL_ASSUME_YES:-false} == true ]] || {
		labctl_die 'setup-host requires --yes because it changes Incus resources'
		return 1
	}
	prefix=${LABCTL_AGENT_CIDR#*/}
	gateway_cidr=$LABCTL_AGENT_GATEWAY/$prefix
	if ! incus network show "$LABCTL_AGENT_BRIDGE" >/dev/null 2>&1; then
		labctl_run incus network create "$LABCTL_AGENT_BRIDGE" ipv4.address="$gateway_cidr" ipv4.nat=true ipv4.dhcp=true dns.mode=managed
	else
		labctl_run incus network set "$LABCTL_AGENT_BRIDGE" ipv4.address="$gateway_cidr"
		labctl_run incus network set "$LABCTL_AGENT_BRIDGE" ipv4.nat=true
		labctl_run incus network set "$LABCTL_AGENT_BRIDGE" ipv4.dhcp=true
		labctl_run incus network set "$LABCTL_AGENT_BRIDGE" dns.mode=managed
	fi
	labctl_incus_ensure_profile
}
