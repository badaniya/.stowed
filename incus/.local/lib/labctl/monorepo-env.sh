#!/usr/bin/env bash
# Literal-only rendering of one section of a private shell profile into the
# sandbox environment. Which section and which variables are project-specific,
# so they come from the private labctl configuration:
#   LABCTL_MONOREPO_ENV_SOURCE_PATH      profile to read (owner-only, absolute)
#   LABCTL_MONOREPO_ENV_SECTION          header text of the '# <section>' block
#   LABCTL_MONOREPO_ENV_ALLOWED          variables copied verbatim
#   LABCTL_MONOREPO_ENV_SKIPPED          variables ignored (host-only secrets)
#   LABCTL_MONOREPO_ENV_HOST_IP_VARS     variables set to the sandbox IP
#   LABCTL_MONOREPO_ENV_INSTANCE_ID_VAR  variable set to user:host:ip
#   LABCTL_MONOREPO_ENV_FIXED            literal NAME=value pairs appended last
# shellcheck disable=SC2016,SC2129

labctl_monorepo_env_list() {
	local -n list=$1
	# shellcheck disable=SC2034 # nameref assigns the caller's array.
	read -r -a list <<<"${2:-}"
}

labctl_monorepo_env_in() {
	local name=$1 item
	shift
	for item in "$@"; do [[ $name == "$item" ]] && return 0; done
	return 1
}

labctl_monorepo_env_quote() {
	local value=$1
	value=${value//\'/\'\\\'}
	printf "'%s'" "$value"
}

labctl_monorepo_env_pass() {
	local reference=$1 automatic="$HOME/.local/bin/pass-auto-unlock"
	[[ ! -x $automatic ]] || "$automatic" --quiet || return 1
	PASSWORD_STORE_DIR="$HOME/.password-store" PASSWORD_STORE_GPG_OPTS='--batch --pinentry-mode error' /usr/bin/pass show "$reference"
}

labctl_monorepo_env_render() {
	local ticket=$1 output=$2 source mode line in_section=false section_header_separator_pending=false name value ip section pair render_fd
	local -A seen=() values=() references=() emitted=()
	local -a allowed=() skipped=() host_ip_vars=() fixed=() instance_id_var=() pass_pairs=() order=()
	labctl_monorepo_env_list allowed "${LABCTL_MONOREPO_ENV_ALLOWED:-}"
	labctl_monorepo_env_list skipped "${LABCTL_MONOREPO_ENV_SKIPPED:-}"
	labctl_monorepo_env_list host_ip_vars "${LABCTL_MONOREPO_ENV_HOST_IP_VARS:-}"
	labctl_monorepo_env_list fixed "${LABCTL_MONOREPO_ENV_FIXED:-}"
	labctl_monorepo_env_list instance_id_var "${LABCTL_MONOREPO_ENV_INSTANCE_ID_VAR:-}"
	labctl_monorepo_env_list pass_pairs "${LABCTL_MONOREPO_ENV_PASS_REFERENCES:-}"
	for pair in "${pass_pairs[@]}"; do
		[[ $pair =~ ^[A-Za-z_][A-Za-z0-9_]*=[A-Za-z0-9][A-Za-z0-9/_.-]*$ && ${pair#*=} != *..* ]] || { labctl_die 'invalid pass environment reference'; return 1; }
		name=${pair%%=*}
		labctl_monorepo_env_in "$name" "${allowed[@]}" || { labctl_die 'pass environment name is not allowlisted'; return 1; }
		! labctl_monorepo_env_in "$name" "${skipped[@]}" "${host_ip_vars[@]}" "${instance_id_var[@]}" || { labctl_die 'pass reference conflicts with a host-only or derived variable'; return 1; }
		[[ ! ${references[$name]+present} ]] || { labctl_die 'duplicate pass environment reference'; return 1; }
		references[$name]=${pair#*=}
	done
	section=${LABCTL_MONOREPO_ENV_SECTION:-}
	[[ -n $section && ${#allowed[@]} -gt 0 ]] || {
		labctl_die 'set LABCTL_MONOREPO_ENV_SECTION and LABCTL_MONOREPO_ENV_ALLOWED in the labctl configuration'
		return 1
	}
	for name in "${allowed[@]}" "${skipped[@]}" "${host_ip_vars[@]}" "${instance_id_var[@]}"; do
		[[ $name =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || {
			labctl_die "invalid monorepo environment variable name: $name"
			return 1
		}
	done
	for pair in "${fixed[@]}"; do
		[[ $pair =~ ^[A-Za-z_][A-Za-z0-9_]*=[A-Za-z0-9_.:/-]*$ ]] || {
			labctl_die "invalid LABCTL_MONOREPO_ENV_FIXED entry: $pair"
			return 1
		}
	done
	source=${LABCTL_MONOREPO_ENV_SOURCE_PATH:-}
	[[ $source == /* && -f $source && -r $source && -O $source ]] || {
		labctl_die 'monorepo environment source must be an absolute readable regular file owned by the current user'
		return 1
	}
	mode=$(stat -c '%a' -- "$source") || return 1
	(((8#$mode & 0077) == 0)) || {
		labctl_die 'monorepo environment source must not be group- or world-accessible'
		return 1
	}
	while IFS= read -r line || [[ -n $line ]]; do
		if [[ $line == '###############################################################################' ]]; then
			if [[ $in_section == true ]]; then
				if [[ $section_header_separator_pending == true ]]; then
					section_header_separator_pending=false
					continue
				fi
				break
			fi
			continue
		fi
		[[ $line == "# ${section}" ]] && {
			in_section=true
			section_header_separator_pending=true
			continue
		}
		[[ $in_section == true ]] || continue
		[[ -z $line || $line == \#* ]] && continue
		[[ $line =~ ^export[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]] || {
			labctl_die 'invalid monorepo environment entry'
			return 1
		}
		name=${BASH_REMATCH[1]}
		value=${BASH_REMATCH[2]}
		if [[ $value == \"*\" || $value == \'*\' ]]; then value=${value:1:${#value}-2}; fi
		if [[ ${references[$name]+present} ]] || labctl_monorepo_env_in "$name" "${skipped[@]}" "${host_ip_vars[@]}" "${instance_id_var[@]}"; then
			continue
		fi
		labctl_monorepo_env_in "$name" "${allowed[@]}" || {
			labctl_die "unapproved monorepo environment variable: $name"
			return 1
		}
		[[ ! ${seen[$name]+present} ]] || {
			labctl_die "duplicate monorepo environment variable: $name"
			return 1
		}
		[[ $value != *'$('* && $value != *'`'* && $value != *';'* && $value != *'|'* && $value != *'&'* ]] || {
			labctl_die "unsafe monorepo environment value: $name"
			return 1
		}
		seen[$name]=1
		values[$name]=$value
	done <"$source"
	[[ $in_section == true ]] || {
		labctl_die "monorepo environment section is missing: ${section}"
		return 1
	}
	for name in "${!references[@]}"; do
		value=$(labctl_monorepo_env_pass "${references[$name]}") || { labctl_die 'pass environment lookup failed'; return 1; }
		[[ $value != *$'\n'* && $value != *$'\r'* ]] || { labctl_die 'pass environment value must be single-line'; return 1; }
		values[$name]=$value
	done
	ip=$(labctl_incus_instance_ip "$ticket") || return 1
	labctl_config_is_ipv4 "$ip" || {
		labctl_die 'sandbox has no valid routed IP'
		return 1
	}
	umask 077
	if [[ $output == - ]]; then
		exec {render_fd}>&1
	else
		exec {render_fd}>"$output"
	fi
	order=("${allowed[@]}" "${host_ip_vars[@]}" "${instance_id_var[@]}")
	for name in "${host_ip_vars[@]}"; do values[$name]=$ip; done
	for name in "${instance_id_var[@]}"; do values[$name]="${LABCTL_INSTANCE_USER}:$(hostname):${ip}"; done
	for pair in "${fixed[@]}"; do
		name=${pair%%=*}
		values[$name]=${pair#*=}
		order+=("$name")
	done
	for name in "${order[@]}"; do
		[[ ${values[$name]+present} && ! ${emitted[$name]+present} ]] || continue
		emitted[$name]=1
		printf 'export %s=' "$name" >&"$render_fd"
		labctl_monorepo_env_quote "${values[$name]}" >&"$render_fd"
		printf '\n' >&"$render_fd"
	done
	exec {render_fd}>&-
	[[ $output == - ]] || chmod 600 "$output"
}
