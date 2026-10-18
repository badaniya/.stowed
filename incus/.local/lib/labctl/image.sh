#!/usr/bin/env bash
# Private, local-only golden image lifecycle for the agent-sandbox project.
set -euo pipefail

LABCTL_GOLDEN_IMAGE_BASE=${LABCTL_GOLDEN_IMAGE_BASE:-images:ubuntu/24.04}

labctl_image_validate_version() {
	[[ $1 =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[1-9][0-9]*$ ]] || {
		labctl_die 'golden image version must use YYYY-MM-DD-N'
		return 1
	}
}

labctl_image_alias() {
	local version=$1
	labctl_image_validate_version "$version" || return 1
	printf 'golden:%s\n' "$version"
}

labctl_image_builder_name() {
	local version=$1
	labctl_image_validate_version "$version" || return 1
	printf 'golden-builder-%s\n' "${version//[^0-9]/-}"
}

labctl_image_scrub_command() {
	cat <<'SCRIPT'
set -euo pipefail
systemctl stop docker || true
docker system prune --all --volumes --force || true
rm -rf /var/lib/docker /var/lib/containerd /var/lib/cloud
rm -rf /var/log/* /tmp/* /var/tmp/*
rm -rf /root/.cache /root/.config /home/*/.cache /home/*/.config/nvo /home/*/.private-nvo-loggo.tpl
rm -rf /workspace /workspaces
find /home -maxdepth 2 -name '.bash_history' -delete
find /etc/ssh -type f -name 'ssh_host_*_key*' -delete
rm -f /etc/machine-id /var/lib/dbus/machine-id
: >/etc/machine-id
apt-get clean
rm -rf /var/lib/apt/lists/* /root/go/pkg/mod /root/.cache/go-build
find / -xdev -type f \( -name '*credential*' -o -name 'sandbox.env' \) -delete
SCRIPT
}

labctl_image_verify_command() {
	cat <<'SCRIPT'
set -euo pipefail
for path in /var/lib/docker /var/lib/containerd /var/lib/cloud /workspace /workspaces; do
	[[ ! -e $path ]] || { printf 'forbidden golden-image state: %s\n' "$path" >&2; exit 1; }
done
! find /home /root -xdev \( -name '.bash_history' -o -name 'sandbox.env' -o -name '.private-nvo-loggo.tpl' \) -print -quit | grep -q .
! find /etc/ssh -maxdepth 1 -name 'ssh_host_*_key*' -print -quit | grep -q .
SCRIPT
}

labctl_image_provision_command() {
	cat <<SCRIPT
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y build-essential ca-certificates curl git gzip jq make net-tools openssh-client ripgrep screen sudo tar wget docker.io docker-compose-v2
rm -rf /usr/local/go
curl -fsSL https://go.dev/dl/go${LABCTL_GO_VERSION}.linux-amd64.tar.gz -o /tmp/labctl-go.tar.gz
tar -C /usr/local -xzf /tmp/labctl-go.tar.gz
rm -f /tmp/labctl-go.tar.gz
ln -sf /usr/local/go/bin/go /usr/local/bin/go
HOME=/root GOPATH=/root/go GOCACHE=/root/.cache/go-build GOBIN=/usr/local/bin /usr/local/go/bin/go install github.com/badaniya/loggo@6dba9bab7c9491890349935da50c14f2f346912d
HOME=/root GOPATH=/root/go GOCACHE=/root/.cache/go-build GOBIN=/usr/local/bin /usr/local/go/bin/go install github.com/jesseduffield/lazydocker@v0.25.2
printf '%s\\n' 'export PATH="/usr/local/go/bin:\$PATH"' >/etc/profile.d/labctl-go.sh
systemctl enable docker
SCRIPT
}

labctl_image_build() {
	local version=$1 alias builder cleanup=false
	alias=$(labctl_image_alias "$version") || return 1
	builder=$(labctl_image_builder_name "$version") || return 1
	incus --project "$LABCTL_INCUS_PROJECT" info "$builder" >/dev/null 2>&1 && {
		labctl_die "golden image builder already exists: $builder"
		return 1
	}
	cleanup=true
	trap 'if [[ $cleanup == true ]]; then incus --project "$LABCTL_INCUS_PROJECT" delete "$builder" --force >/dev/null 2>&1 || true; fi' ERR RETURN
	labctl_run incus --project "$LABCTL_INCUS_PROJECT" init "$LABCTL_GOLDEN_IMAGE_BASE" "$builder" --profile default --profile "$LABCTL_INCUS_PROFILE"
	labctl_run incus --project "$LABCTL_INCUS_PROJECT" start "$builder"
	labctl_run incus --project "$LABCTL_INCUS_PROJECT" exec "$builder" -- bash -s <<<"$(labctl_image_provision_command)"
	labctl_run incus --project "$LABCTL_INCUS_PROJECT" exec "$builder" -- bash -s <<<"$(labctl_image_scrub_command)"
	labctl_run incus --project "$LABCTL_INCUS_PROJECT" exec "$builder" -- bash -s <<<"$(labctl_image_verify_command)"
	labctl_run incus --project "$LABCTL_INCUS_PROJECT" stop "$builder"
	labctl_run incus --project "$LABCTL_INCUS_PROJECT" publish "$builder" --alias "$alias"
	labctl_run incus --project "$LABCTL_INCUS_PROJECT" delete "$builder"
	cleanup=false
	trap - ERR RETURN
}
