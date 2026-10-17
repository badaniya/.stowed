#!/usr/bin/env bash
# Lock-protected persistent sandbox registry.
set -euo pipefail

labctl_state_path() {
	printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}/labctl/sandboxes.json"
}

labctl_state_lock_path() {
	printf '%s.lock\n' "$(labctl_state_path)"
}

labctl_state_init() {
	local state lock directory
	state=$(labctl_state_path)
	lock=$(labctl_state_lock_path)
	directory=$(dirname "$state")
	mkdir -p "$directory"
	exec {lock_fd}>"$lock"
	flock "$lock_fd"
	if [[ ! -f $state ]]; then
		printf '%s\n' '{"schema_version":1,"sandboxes":{}}' >"$state"
	fi
	jq -e '.schema_version == 1 and (.sandboxes | type == "object")' "$state" >/dev/null || {
		labctl_die "invalid state registry: $state"
		return 1
	}
	flock -u "$lock_fd"
	exec {lock_fd}>&-
}

labctl_state_lookup() {
	local ticket state lock
	ticket=$(labctl_normalize_ticket "$1") || return 1
	state=$(labctl_state_path)
	lock=$(labctl_state_lock_path)
	labctl_state_init
	exec {lock_fd}>"$lock"
	flock -s "$lock_fd"
	jq -e --arg ticket "$ticket" '.sandboxes[$ticket]' "$state"
	flock -u "$lock_fd"
	exec {lock_fd}>&-
}

labctl_state_write() {
	local state lock temporary
	state=$(labctl_state_path)
	lock=$(labctl_state_lock_path)
	labctl_state_init
	exec {lock_fd}>"$lock"
	flock "$lock_fd"
	temporary=$(mktemp "${state}.tmp.XXXXXX")
	jq "$@" "$state" >"$temporary"
	mv -f -- "$temporary" "$state"
	flock -u "$lock_fd"
	exec {lock_fd}>&-
}

labctl_state_claim_ip() {
	local ticket ip=$2 state lock owner
	ticket=$(labctl_normalize_ticket "$1") || return 1
	state=$(labctl_state_path)
	lock=$(labctl_state_lock_path)
	labctl_state_init
	exec {lock_fd}>"$lock"
	flock "$lock_fd"
	owner=$(jq -r --arg ip "$ip" --arg ticket "$ticket" \
		'.sandboxes | to_entries[] | select(.key != $ticket and .value.ip == $ip) | .key' "$state" | head -n 1)
	if [[ -n $owner ]]; then
		flock -u "$lock_fd"
		exec {lock_fd}>&-
		labctl_die "IP address is already reserved by $owner: $ip"
		return 1
	fi
	flock -u "$lock_fd"
	exec {lock_fd}>&-
}

labctl_state_preview_ip() {
	local state candidate start end value
	state=$(labctl_state_path)
	start=$(labctl_config_ipv4_number "$LABCTL_IP_POOL_START")
	end=$(labctl_config_ipv4_number "$LABCTL_IP_POOL_END")
	for ((value = start; value <= end; value++)); do
		candidate=$(printf '%d.%d.%d.%d' "$((value >> 24 & 255))" "$((value >> 16 & 255))" "$((value >> 8 & 255))" "$((value & 255))")
		if [[ ! -f $state ]] || ! jq -e --arg ip "$candidate" '[.sandboxes[] | select(.ip == $ip)] | length > 0' "$state" >/dev/null; then
			printf '%s\n' "$candidate"
			return 0
		fi
	done
	labctl_die 'no available sandbox IP addresses'
}

labctl_state_reserve_ip() {
	local ticket state lock existing candidate start end value temporary
	ticket=$(labctl_normalize_ticket "$1") || return 1
	state=$(labctl_state_path)
	lock=$(labctl_state_lock_path)
	labctl_state_init
	exec {lock_fd}>"$lock"
	flock "$lock_fd"
	existing=$(jq -r --arg ticket "$ticket" '.sandboxes[$ticket].ip // empty' "$state")
	if [[ -n $existing ]]; then
		printf '%s\n' "$existing"
		flock -u "$lock_fd"
		exec {lock_fd}>&-
		return 0
	fi
	start=$(labctl_config_ipv4_number "$LABCTL_IP_POOL_START")
	end=$(labctl_config_ipv4_number "$LABCTL_IP_POOL_END")
	for ((value = start; value <= end; value++)); do
		candidate=$(printf '%d.%d.%d.%d' "$((value >> 24 & 255))" "$((value >> 16 & 255))" "$((value >> 8 & 255))" "$((value & 255))")
		if ! jq -e --arg ip "$candidate" '[.sandboxes[] | select(.ip == $ip)] | length > 0' "$state" >/dev/null; then
			temporary=$(mktemp "${state}.tmp.XXXXXX")
			# shellcheck disable=SC2016 # jq variables are intentionally literal.
			jq --arg ticket "$ticket" --arg ip "$candidate" \
				'.sandboxes[$ticket] = {ticket: $ticket, instance: $ticket, ip: $ip, workspace_type: "unknown", mount_roots: {}, created_at: (now | todateiso8601), updated_at: (now | todateiso8601), status: "reserved"}' \
				"$state" >"$temporary"
			mv -f -- "$temporary" "$state"
			printf '%s\n' "$candidate"
			flock -u "$lock_fd"
			exec {lock_fd}>&-
			return 0
		fi
	done
	flock -u "$lock_fd"
	exec {lock_fd}>&-
	labctl_die 'no available sandbox IP addresses'
}

labctl_state_record() {
	local ticket instance ip=$3 workspace_type=$4 ticket_root state lock owner temporary
	ticket=$(labctl_normalize_ticket "$1") || return 1
	instance=$(labctl_normalize_ticket "$2") || return 1
	ticket_root=$(realpath -m -- "${LABCTL_WORKSPACE_ROOT}/${ticket}") || return 1
	state=$(labctl_state_path)
	lock=$(labctl_state_lock_path)
	labctl_state_init
	exec {lock_fd}>"$lock"
	flock "$lock_fd"
	owner=$(jq -r --arg ip "$ip" --arg ticket "$ticket" \
		'.sandboxes | to_entries[] | select(.key != $ticket and .value.ip == $ip) | .key' "$state" | head -n 1)
	if [[ -n $owner ]]; then
		flock -u "$lock_fd"
		exec {lock_fd}>&-
		labctl_die "IP address is already reserved by $owner: $ip"
		return 1
	fi
	temporary=$(mktemp "${state}.tmp.XXXXXX")
	# shellcheck disable=SC2016 # jq variables are intentionally literal.
	jq --arg ticket "$ticket" --arg instance "$instance" --arg ip "$ip" --arg workspace_type "$workspace_type" \
		--arg workspace_root "$ticket_root" --arg master_root "$LABCTL_MASTER_ROOT" \
		'.sandboxes[$ticket] = ((.sandboxes[$ticket] // {created_at: (now | todateiso8601)}) + {ticket: $ticket, instance: $instance, ip: $ip, workspace_type: $workspace_type, mount_roots: {workspace: $workspace_root, master: $master_root}, updated_at: (now | todateiso8601), status: "created"})' \
		"$state" >"$temporary"
	mv -f -- "$temporary" "$state"
	flock -u "$lock_fd"
	exec {lock_fd}>&-
}
labctl_state_remove() {
	local ticket
	ticket=$(labctl_normalize_ticket "$1") || return 1
	# shellcheck disable=SC2016 # jq variable is intentionally literal.
	labctl_state_write --arg ticket "$ticket" 'del(.sandboxes[$ticket])'
}

labctl_state_set_status() {
	local ticket=$1 status=$2
	ticket=$(labctl_normalize_ticket "$ticket") || return 1
	# shellcheck disable=SC2016 # jq variables are intentionally literal.
	labctl_state_write --arg ticket "$ticket" --arg status "$status" \
		'.sandboxes[$ticket] = ((.sandboxes[$ticket] // error("sandbox is not registered")) + {status: $status, updated_at: (now | todateiso8601)})'
}

labctl_state_ip_for() {
	local ticket
	ticket=$(labctl_normalize_ticket "$1") || return 1
	labctl_state_lookup "$ticket" | jq -r '.ip // empty'
}
