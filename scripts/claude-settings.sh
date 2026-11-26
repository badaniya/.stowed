#!/usr/bin/env bash
# Keep Claude Code's settings.json in step with the tracked settings.base.json.
#
# settings.json stays untracked. Claude writes machine-specific data into it:
# autoMode.environment lists internal hosts, repo paths and sensitive file
# names, and env can carry credentials. This repo is public, so only the keys
# that define the setup (plugins, marketplaces, hooks, statusline, permissions,
# style) are published, through settings.base.json.
#
# Usage:
#   claude-settings.sh apply    merge settings.base.json into settings.json
#   claude-settings.sh export   write settings.json's shared keys to settings.base.json
#   claude-settings.sh check    exit 1 if the two disagree, showing the diff
#
# apply replaces each shared key wholesale (so a plugin removed from the base is
# removed locally) except env, where local entries such as secrets are kept.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
claude_dir="${CLAUDE_SETTINGS_DIR:-$repo_root/claude/.claude}"
base="$claude_dir/settings.base.json"
live="$claude_dir/settings.json"

# An allowlist, not a denylist: a key Claude adds later stays local until it is
# reviewed and added here.
shared_keys='[
  "enabledPlugins", "extraKnownMarketplaces", "hooks", "statusLine", "permissions",
  "outputStyle", "theme", "model", "effortLevel", "modelSettings",
  "autoCompactWindow", "skipDangerousModePermissionPrompt", "env"
]'
# env names that look like credentials or endpoints never leave this machine.
# Export them from ~/.private_bash_profile instead.
secret_env_re='SECRET|TOKEN|PASSWORD|PASSWD|CREDENTIAL|_KEY$|_KEY_|URL'

die() {
  printf 'claude-settings: %s\n' "$*" >&2
  exit 1
}

command -v jq >/dev/null || die "jq is required"

# Print settings.json reduced to what may be published.
shared_view() {
  jq --argjson keys "$shared_keys" --arg re "$secret_env_re" '
    with_entries(select(.key as $k | $keys | index($k)))
    | if has("env") then .env |= with_entries(select(.key | test($re; "i") | not)) else . end
  ' "$live"
}

# Write stdin to $1 through a temp file so a jq failure never truncates it.
write_file() {
  local tmp
  tmp="$(mktemp "$1.XXXXXX")"
  cat >"$tmp"
  mv "$tmp" "$1"
}

cmd_apply() {
  [ -f "$base" ] || die "missing $base"
  local current='{}'
  [ -f "$live" ] && current="$(cat "$live")"
  jq --argjson local "$current" '
    . as $base
    | $local + ($base | del(.env))
    | .env = (($local.env // {}) + ($base.env // {}))
    | if .env == {} then del(.env) else . end
  ' "$base" | write_file "$live"
  printf 'claude-settings: applied %s\n' "${base#"$repo_root"/}"
}

cmd_export() {
  [ -f "$live" ] || die "missing $live"
  local view
  view="$(shared_view)"
  # Last line of defence for a public repo: refuse private addresses that a
  # hook or permission rule might have picked up.
  if printf '%s' "$view" | jq -r '.. | strings' |
    rg -q '(^|[^0-9.])(10\.[0-9]+|192\.168|172\.(1[6-9]|2[0-9]|3[01]))\.[0-9]+\.[0-9]+'; then
    die "refusing to export: settings contain a private IP address"
  fi
  printf '%s\n' "$view" | write_file "$base"
  printf 'claude-settings: exported to %s\n' "${base#"$repo_root"/}"
}

cmd_check() {
  [ -f "$live" ] || die "missing $live (run: $0 apply)"
  [ -f "$base" ] || die "missing $base"
  if diff -u --label settings.base.json --label 'settings.json (shared keys)' \
    <(jq -S . "$base") <(shared_view | jq -S .); then
    printf 'claude-settings: in sync\n'
  else
    printf '\nclaude-settings: run "%s apply" to take the base, or "%s export" to keep local\n' "$0" "$0" >&2
    return 1
  fi
}

case "${1:-}" in
  apply) cmd_apply ;;
  export) cmd_export ;;
  check) cmd_check ;;
  *) die "usage: claude-settings.sh {apply|export|check}" ;;
esac
