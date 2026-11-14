#!/usr/bin/env bash
# Prompts collect arguments only; root backend owns validation and confirmation.
set -euo pipefail
[[ $# -ge 1 && $# -le 2 &&
  ( $1 == list || ( $1 =~ ^xiqfwd(0|[1-9][0-9]*)$ && ${#1} -le 15 ) ) &&
  ( $# -eq 1 || ( $1 != list && $2 =~ ^(create|update|delete|status|list|adopt)$ ) ) ]] || {
  printf 'Usage: sandbox-exposure-dialog.sh <xiqfwdN> [create|update|delete|status|list|adopt] | list\n' >&2
  exit 1
}
name=$1
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
backend="$script_dir/sandbox-exposure.py"
if [[ $name == list ]]; then
  printf 'Sandbox exposures:\n\n'
  choice=5
elif [[ $# -eq 2 ]]; then
  printf 'Sandbox exposure: %s — %s\n\n' "$name" "$2"
  case $2 in
  create) choice=1 ;;
  update) choice=2 ;;
  delete) choice=3 ;;
  status) choice=4 ;;
  list) choice=5 ;;
  adopt) choice=6 ;;
  esac
else
  printf 'Sandbox exposure: %s\n\n' "$name"
  printf '1) Create (new owned macvlan + DHCP + forward)\n2) Update target/ports\n3) Delete\n4) Status\n5) List\n6) Adopt existing legacy exposure (preserve IP/forward)\nq) Cancel\n'
  IFS= read -r -p 'Choose: ' choice || exit 0
fi
args=()
case $choice in
1 | 6)
  IFS= read -r -p 'Lab parent NIC: ' parent || exit 0
  IFS= read -r -p 'Incus bridge network [agentbr0]: ' network || exit 0
  IFS= read -r -p 'Network project [default] (not the sandbox instance project): ' project || exit 0
  IFS= read -r -p 'Sandbox IPv4 target: ' target || exit 0
  printf 'WARNING: all exposes every port/protocol reachable in the sandbox.\n'
  IFS= read -r -p 'Ports (explicit all or tcp:443,udp:5000-5002): ' ports || exit 0
  [[ -n $parent && -n $target && -n $ports ]] || {
    printf 'Cancelled: required input missing.\n'
    exit 1
  }
  operation=create
  [[ $choice != 6 ]] || operation=adopt
  args=("$operation" "$name" --parent "$parent" --network "${network:-agentbr0}" --project "${project:-default}" --target "$target" --ports "$ports")
  if [[ $choice == 6 ]]; then
    printf 'Enter the existing target/ports exactly; adoption must not retarget traffic.\n'
    IFS= read -r -p 'Verified legacy DHCP PID: ' legacy_pid || exit 0
    [[ $legacy_pid =~ ^[1-9][0-9]{0,9}$ ]] || {
      printf 'Cancelled: invalid DHCP PID.\n'
      exit 1
    }
    args+=(--legacy-dhcp-pid "$legacy_pid")
  fi
  ;;
2)
  IFS= read -r -p 'New sandbox IPv4 target (blank preserves): ' target || exit 0
  IFS= read -r -p 'Ports (blank preserves; all or tcp:443,udp:5000-5002): ' ports || exit 0
  args=(update "$name")
  [[ -z $target ]] || args+=(--target "$target")
  [[ -z $ports ]] || args+=(--ports "$ports")
  ;;
3) args=(delete "$name") ;;
4) args=(status "$name") ;;
5) args=(list) ;;
*)
  printf 'Cancelled.\n'
  exit 0
  ;;
esac
# No eval, shell command strings, confirmation bypass, or sudoers changes.
result=0
# This operation runs after the launcher has returned. Own its failure report
# here, before replacing the dialog with its inspection shell.
HERDR_ACTION_ERROR_ACTIVE=0 HERDR_PLUGIN_ENTRYPOINT_ID=dialog \
  python3 "$script_dir/herdr-action-errors.py" run \
  --name "Sandbox Exposure: ${args[0]} $name" -- \
  sudo -- python3 "$backend" "${args[@]}" || result=$?
printf '\nExposure command exited with status %d.\n' "$result"
if [[ -t 0 ]]; then
  printf 'Leaving this pane open for inspection.\n'
  exec bash -i
fi
exit "$result"
