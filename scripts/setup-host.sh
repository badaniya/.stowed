#!/usr/bin/env bash
# Safe first-run deployment. Never adopts or deletes existing config.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
profile=public
mode=apply
case "${1:-}" in
  --check) mode=check; shift ;;
  "") ;;
  --profile) ;;
  *) printf 'usage: setup-host.sh [--check] [--profile public|work]\n' >&2; exit 2 ;;
esac
if [[ ${1:-} == --profile ]]; then profile=${2:?profile required}; shift 2; fi
[[ $# == 0 && ( $profile == public || $profile == work ) ]] || exit 2
if [[ $mode == check ]]; then
  exec python3 "$repo_root/scripts/herdr-doctor.py" --profile "$profile"
fi
for tool in git stow python3; do command -v "$tool" >/dev/null || { printf 'Install prerequisite: %s\n' "$tool" >&2; exit 1; }; done
# Recognize only the obsolete link produced by this repo's previous layout.
link="$HOME/.config/herdr-spreader"
if [[ -L $link && ! -e $link && $(readlink "$link") == ../.stowed/herdr/.config/herdr-spreader ]]; then
  cp -P "$link" "$link.backup-$(date +%s)"
  ln -sfn "$repo_root/herdr-spreader/.config/herdr-spreader" "$link"
fi
stow --simulate --dir "$repo_root" --target "$HOME" herdr herdr-spreader herdr-app
stow --dir "$repo_root" --target "$HOME" herdr herdr-spreader herdr-app
bash "$repo_root/scripts/private-links.sh"
# One canonical quick-actions directory; preserve legacy standalone clients.
canonical="$HOME/.config/herdr/plugins/config/cloudmanic.herdr-plus/quick-actions"
fallback="$HOME/.config/herdr-plus/quick-actions"
if [[ -d $fallback && ! -L $fallback ]]; then
  # Only consolidate the old generated mirror, never an independently edited tree.
  for file in "$fallback"/*; do
    [[ -e $file || -L $file ]] || continue
    peer="$canonical/${file##*/}"
    [[ -L $file && -e $peer && $(readlink -f "$file") == "$(readlink -f "$peer")" ]] || {
      printf 'Refusing to replace independently managed fallback: %s\n' "$file" >&2; exit 1;
    }
  done
  mv "$fallback" "$fallback.backup-$(date +%s)"
fi
if [[ ! -e $fallback && ! -L $fallback ]]; then
  mkdir -p "$(dirname "$fallback")"
  ln -s "$canonical" "$fallback"
elif [[ $(readlink -f "$fallback") != "$(readlink -f "$canonical")" ]]; then
  printf 'Conflicting fallback directory: %s\n' "$fallback" >&2; exit 1
fi
printf 'Deployment complete. Run scripts/bootstrap.sh, then setup-host.sh --check --profile %s\n' "$profile"
