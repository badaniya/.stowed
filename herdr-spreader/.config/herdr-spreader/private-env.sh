#!/usr/bin/env bash
# Sourced helpers for private work settings.
#
# Repository names, ticket prefixes and clone URLs are internal, so they live
# in ~/.private_work.env (KEY=value lines), not in this public repo. Quick
# actions run without the private profile, so the file is read directly; an
# exported variable of the same name takes precedence.

# Print KEY from the environment or ~/.private_work.env.
private_env() {
	local key=$1 value file="${HOME}/.private_work.env" line
	value=${!key:-}
	if [[ -z $value && -r $file ]]; then
		while IFS= read -r line; do
			[[ $line =~ ^(export[[:space:]]+)?${key}=[\"\']?([^\"\']*)[\"\']?$ ]] && value=${BASH_REMATCH[2]}
		done <"$file"
	fi
	[[ -n $value ]] || {
		printf 'Error: set %s in %s\n' "$key" "$file" >&2
		return 1
	}
	printf '%s\n' "$value"
}

# Print a private setting that names a directory, branch part or ticket prefix.
private_env_name() {
	local value
	value=$(private_env "$1") || return 1
	[[ $value =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || {
		printf 'Error: %s must be a plain name\n' "$1" >&2
		return 1
	}
	printf '%s\n' "$value"
}

# Monorepo directory name under <workspace>/master and each ticket root.
monorepo_name() { private_env_name MONOREPO_NAME; }
