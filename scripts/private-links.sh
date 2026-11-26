#!/usr/bin/env bash
# Link private files from ~/.private_* directories into stowed config dirs.
#
# Some config directories mix shared files with private ones: lab launchers
# and tool configs that name internal hosts, IPs or credentials. This repo is
# public, so those files live in ~/.private_* directories, like
# ~/.private_agents, and are symlinked into place here. Each link is listed in
# .git/info/exclude, a local file, so no tracked file names them.
#
# Usage:
#   private-links.sh [--check]
#
#   (none)    create missing links; safe to rerun
#   --check   change nothing; report missing or conflicting links
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exclude="$(git -C "$repo_root" rev-parse --git-path info/exclude)"
case "$exclude" in /*) ;; *) exclude="$repo_root/$exclude" ;; esac

# private dir -> repo dir it is linked into
links=(
  "$HOME/.private_herdr_spreader:herdr-spreader/.config/herdr-spreader"
  "$HOME/.private_herdr_quick_actions:herdr/.config/herdr/plugins/config/cloudmanic.herdr-plus/quick-actions"
  "$HOME/.private_herdr_quick_actions:$HOME/.config/herdr-plus/quick-actions"
  "$HOME/.private_herdr_reviewr:herdr/.config/herdr/plugins/config/persiyanov.reviewr"
  "$HOME/.private_herdr_spreader_workspaces:herdr/.config/herdr/plugins/config/herdr-spreader"
  "$HOME/.private_labctl:incus/.config/labctl"
  "$HOME/.private_copilot_config:copilot/.config/.copilot"
  "$HOME/.private_prompts:agents/.agents/prompts"
)

check_only=false
case "${1:-}" in
  "") ;;
  --check) check_only=true ;;
  *)
    printf 'usage: private-links.sh [--check]\n' >&2
    exit 2
    ;;
esac

problems=0
warn() {
  printf '   ! %s\n' "$*"
  problems=$((problems + 1))
}

mkdir -p "$(dirname "$exclude")"
touch "$exclude"

for pair in "${links[@]}"; do
  src_dir="${pair%%:*}"
  rel_dir="${pair#*:}"
  if [ ! -d "$src_dir" ]; then
    printf '   no %s (optional)\n' "$src_dir"
    continue
  fi
  linked=0
  for src in "$src_dir"/*; do
    [ -f "$src" ] || continue
    rel="$rel_dir/${src##*/}"
    # Handle absolute paths (starting with / or $HOME/)
    case "$rel_dir" in
      /*|$HOME/*) dest="$rel_dir/${src##*/}" ;;
      *) dest="$repo_root/$rel" ;;
    esac
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
      :
    elif [ -e "$dest" ] || [ -L "$dest" ]; then
      warn "$rel exists and is not a link to $src"
      continue
    elif $check_only; then
      warn "$rel not linked"
      continue
    else
      mkdir -p "$(dirname "$dest")"
      ln -s "$src" "$dest"
    fi
    if ! rg -qxF -- "/$rel" "$exclude"; then
      if $check_only; then
        warn "/$rel missing from $exclude"
      else
        printf '/%s\n' "$rel" >>"$exclude"
      fi
    fi
    linked=$((linked + 1))
  done
  printf '   %s: %d file(s) from %s\n' "$rel_dir" "$linked" "$src_dir"
done

[ "$problems" -eq 0 ]
