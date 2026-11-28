#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$ROOT/incus/.local/lib/labctl/config.sh"
source "$ROOT/incus/.local/lib/labctl/host-setup.sh"
labctl_die() { printf '%s\n' "$*" >&2; return 1; }
command() {
  if [[ $1 == -v && ( $2 == lxc || $2 == multipass ) ]]; then return 1; fi
  builtin command "$@"
}
labctl_incus_require_commands
LABCTL_AGENT_BRIDGE=agentbr0
LABCTL_AGENT_CIDR=10.42.0.0/24
export LABCTL_AGENT_GATEWAY=10.42.0.1
ip() {
  case "$*" in
    'link show agentbr0') return 0 ;;
    'route show') printf '10.42.0.0/24 dev agentbr0 proto kernel scope link src 10.42.0.1\n' ;;
  esac
}
incus() {
  case "$*" in
    'network show agentbr0') return 0 ;;
    'network get agentbr0 ipv4.address') printf '10.42.0.1/24\n' ;;
    *) return 1 ;;
  esac
}
labctl_incus_reject_network_conflicts
printf '%s\n' 'PASS: optional legacy providers and owned bridge route'
