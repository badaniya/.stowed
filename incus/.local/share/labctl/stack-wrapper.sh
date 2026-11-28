#!/usr/bin/env bash
set -euo pipefail
# stack_command is supplied through stdin by the host, never argv or a file.
ticket_root=$1
git_host=$3
instance_user=$4
user_uid=$(id -u "$instance_user")
user_gid=$(id -g "$instance_user")
[[ $user_uid =~ ^[1-9][0-9]*$ && $user_gid =~ ^[1-9][0-9]*$ ]] || exit 1
unset GIT_ASKPASS LABCTL_GIT_CREDENTIAL_FILE
export GIT_TERMINAL_PROMPT=0
export GOPRIVATE="$git_host"
export GONOSUMDB="$git_host"
cd -- "$ticket_root"
printf '%s\n' "$stack_command" | setpriv --reuid "$user_uid" --regid "$user_gid" --init-groups env \
  HOME="/home/$instance_user" USER="$instance_user" LOGNAME="$instance_user" \
  PATH="/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
  /usr/bin/python3 -I /usr/local/libexec/labctl-memory-git run --name monorepo-environment
