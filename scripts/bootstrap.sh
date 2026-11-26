#!/usr/bin/env bash
# Rebuild the per-machine state this repo deliberately does not track.
#
# Run after cloning and stowing (README "Run Stow Command" steps). The repo
# keeps only declared intent; everything below is regenerated from it:
#   - git filter config for files whose tools stamp versions into them
#   - Claude settings.json from settings.base.json, then its marketplaces and
#     plugins (marketplace clones and plugin caches are gitignored)
#   - the Pi runtime and the packages listed in Pi's settings.json
#   - Herdr plugins listed in herdr/.config/herdr/plugins.txt
#   - links to private files kept in ~/.private_* dirs (scripts/private-links.sh)
#
# Usage:
#   bootstrap.sh [--check]
#
#   (none)    set up or repair everything; safe to rerun
#   --check   change nothing; report what is missing
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
claude_dir="$repo_root/claude/.claude"
pi_settings="$repo_root/pi/.pi/agent/settings.json"
pi_bin="${PI_LAUNCHER:-$HOME/.pi/agent/bin/pi}"
private_profile="$HOME/.private_bash_profile"
private_mcp="$HOME/.config/mcp/mcp.json"

check_only=false
case "${1:-}" in
  "") ;;
  --check) check_only=true ;;
  *)
    printf 'usage: bootstrap.sh [--check]\n' >&2
    exit 2
    ;;
esac

problems=0
step() { printf '\n== %s\n' "$*"; }
note() { printf '   %s\n' "$*"; }
warn() {
  printf '   ! %s\n' "$*"
  problems=$((problems + 1))
}

step "Required tools"
for tool in git jq rg stow; do
  command -v "$tool" >/dev/null || warn "$tool is not installed"
done
[ "$problems" -eq 0 ] || {
  printf '\nbootstrap: install the missing tools first\n' >&2
  exit 1
}
note "ok"

step "Git filters"
pi_filter="jq 'del(.lastChangelogVersion, .extensionChangelogVersions)'"
if [ "$(git -C "$repo_root" config --get filter.pi-settings.clean || true)" = "$pi_filter" ]; then
  note "pi-settings filter configured"
elif $check_only; then
  warn "pi-settings filter missing: Pi version stamps will show as changes"
else
  git -C "$repo_root" config filter.pi-settings.clean "$pi_filter"
  note "configured pi-settings filter"
fi

step "Private settings"
if [ -f "$private_profile" ]; then
  before=$problems
  for var in LANGFUSE_PUBLIC_KEY LANGFUSE_SECRET_KEY LANGFUSE_BASE_URL; do
    rg -q "^export $var=" "$private_profile" || warn "$var not exported in $private_profile (Langfuse tracing disabled)"
  done
  [ "$problems" -ne "$before" ] || note "ok"
  # Internal MCP servers live outside the repo; pi-mcp-adapter merges this file
  # under the tracked ~/.pi/agent/mcp*.json (lowest precedence, per server).
  if [ -f "$private_mcp" ]; then
    note "private MCP servers: $(jq -r '.mcpServers // {} | keys | join(", ")' "$private_mcp")"
  else
    note "no $private_mcp (optional: internal MCP servers go there)"
  fi
else
  warn "$private_profile missing: secrets (Langfuse keys) belong there, not in tracked files"
fi
# Work-specific names used by the herdr-spreader sandbox scripts and labctl.
private_work="$HOME/.private_work.env"
if [ -f "$private_work" ]; then
  for var in MONOREPO_NAME MONOREPO_GH_USER MONOREPO_CONTEXT_SOURCES; do
    rg -q "^(export )?$var=" "$private_work" || warn "$var not set in $private_work (monorepo sandbox actions fail)"
  done
else
  note "no $private_work (optional: monorepo/multirepo sandbox actions need it)"
fi

step "Private file links"
if $check_only; then
  "$repo_root/scripts/private-links.sh" --check || warn "private file links incomplete"
else
  "$repo_root/scripts/private-links.sh" || warn "private file links incomplete"
fi

step "Claude settings"
if $check_only; then
  "$repo_root/scripts/claude-settings.sh" check || warn "settings.json differs from settings.base.json"
else
  "$repo_root/scripts/claude-settings.sh" apply
fi

step "Claude marketplaces and plugins"
if ! command -v claude >/dev/null; then
  note "claude is not installed; skipping plugins (optional)"
else
  known="$(claude plugin marketplace list --json 2>/dev/null | jq -r '.[].name' || true)"
  while IFS=$'\t' read -r name repo; do
    if printf '%s\n' "$known" | rg -qx -- "$name"; then
      note "marketplace $name present"
    elif $check_only; then
      warn "marketplace $name not added"
    else
      claude plugin marketplace add "$repo"
    fi
  done < <(jq -r '.extraKnownMarketplaces // {} | to_entries[]
    | select(.value.source.source == "github") | [.key, .value.source.repo] | @tsv' "$claude_dir/settings.json")

  installed="$(claude plugin list --json 2>/dev/null | jq -r '.[].id' || true)"
  while IFS= read -r plugin; do
    if printf '%s\n' "$installed" | rg -qxF -- "$plugin"; then
      note "plugin $plugin installed"
    elif $check_only; then
      warn "plugin $plugin not installed"
    else
      claude plugin install "$plugin"
    fi
  done < <(jq -r '.enabledPlugins // {} | to_entries[] | select(.value) | .key' "$claude_dir/settings.json")

  # Installing can rewrite settings.json; put the declared state back.
  $check_only || "$repo_root/scripts/claude-settings.sh" apply
fi

step "Pi runtime and packages"
if $check_only; then
  "$repo_root/scripts/pi-bootstrap.sh" --check || warn "Pi runtime not runnable"
else
  "$repo_root/scripts/pi-bootstrap.sh"
fi
if [ -x "$pi_bin" ]; then
  listed="$("$pi_bin" list 2>/dev/null | sed 's/^ *//' || true)"
  while IFS= read -r pkg; do
    if printf '%s\n' "$listed" | rg -qxF -- "$pkg"; then
      note "package $pkg installed"
    elif $check_only; then
      warn "package $pkg not installed"
    else
      "$pi_bin" install "$pkg"
    fi
  done < <(jq -r '.packages[]?' "$pi_settings")
fi

step "Herdr plugins"
if ! command -v herdr >/dev/null; then
  note "herdr is not installed; skipping plugins"
else
  herdr_listed="$(herdr plugin list 2>/dev/null || true)"
  while read -r kind src ref; do
    case "$kind" in
      github) marker="[github:$src@" ;;
      local)
        src="$repo_root/$src"
        marker="[local:$src]"
        ;;
      *) continue ;;
    esac
    if printf '%s\n' "$herdr_listed" | rg -qF -- "$marker"; then
      note "plugin $src installed"
    elif $check_only; then
      warn "herdr plugin $src not installed"
    elif [ "$kind" = github ]; then
      herdr plugin install --yes ${ref:+--ref "$ref"} "$src"
    else
      herdr plugin link "$src"
    fi
  done < <(rg -v '^\s*(#|$)' "$repo_root/herdr/.config/herdr/plugins.txt")
fi

printf '\n'
if [ "$problems" -gt 0 ]; then
  printf 'bootstrap: %d problem(s) found\n' "$problems"
  exit 1
fi
printf 'bootstrap: done\n'
