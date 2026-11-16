#!/usr/bin/env bash
# Open a PR review + agent sandbox for the xcloud-platform-services monorepo.
# Usage: nvo-review-mono.sh '<branch>'
# The worktree is ~/workspace/<owner>/NVO-REVIEW-<JIRA|PR-#> checked out on the PR branch
# (tracking origin/<branch>; no private branch). Also sourced by the mono sandbox
# coordinator for review_create_tabs.

review_error() {
  printf 'Error: %s\n' "$*" >&2
  return 1
}

# gh/git-lfs for the EMU monorepo must use the EMU account, not a stale GH_TOKEN.
review_gh_token_expr() {
  # shellcheck disable=SC2016 # The review pane expands this expression at runtime.
  printf '%s' '"$(env -u GH_TOKEN -u GITHUB_TOKEN gh auth token --hostname github.com --user ${NVO_MONO_GH_USER:-BADANIYA_extr})"'
}

review_create_tabs() {
  local workspace=$1 agent_tab=$2 agent_pane=$3 project=$4 state=$5 key=$6 jira=$7
  local tab_json pane split_json split_pane command dash_config auth
  auth="GH_TOKEN=$(review_gh_token_expr)"
  herdr tab rename "$agent_tab" '1 - Agent'
  printf -v command 'cd %q && pi' "$project"
  herdr pane run "$agent_pane" "$command"

  dash_config="$state/${key}.gh-dash.yml"
  jq -n --arg branch "$NVO_REVIEW_BRANCH" '{prSections: [{title: $branch, filters: ("is:pr head:" + $branch)}]}' >"$dash_config"
  if [[ ${NVO_REVIEW_JIRA_AVAILABLE:-false} == true ]]; then
    tab_json=$(herdr tab create --workspace "$workspace" --cwd "$project" --label '2 - JIRA/PR' --no-focus)
    pane=$(jq -er '.result.root_pane.pane_id' <<<"$tab_json")
    printf -v command 'jira issue view %q' "$jira"
    herdr pane run "$pane" "$command"
  else
    tab_json=$(herdr tab create --workspace "$workspace" --cwd "$project" --label '2 - PR' --no-focus)
    pane=$(jq -er '.result.root_pane.pane_id' <<<"$tab_json")
  fi
  split_json=$(herdr pane split "$pane" --direction right --ratio 0.5 --cwd "$project" --no-focus)
  split_pane=$(jq -er '.result.pane.pane_id' <<<"$split_json")
  printf -v command '%s gh dash --config %q' "$auth" "$dash_config"
  herdr pane run "$split_pane" "$command"

  tab_json=$(herdr tab create --workspace "$workspace" --cwd "$project" --label '3 - Diff' --no-focus)
  pane=$(jq -er '.result.root_pane.pane_id' <<<"$tab_json")
  printf -v command '%s tuicr pr %q' "$auth" "$NVO_REVIEW_PR_NUMBER"
  herdr pane run "$pane" "$command"
  split_json=$(herdr pane split "$pane" --direction down --ratio 0.5 --cwd "$project" --no-focus)
  split_pane=$(jq -er '.result.pane.pane_id' <<<"$split_json")
  # shellcheck disable=SC2016 # Expanded by the pane's shell at runtime.
  printf -v command '%s bash -c %q _ %q' "$auth" \
    'mapfile -t files < <(gh pr diff "$1" --name-only); exec nvim -- "${files[@]}"' "$NVO_REVIEW_PR_NUMBER"
  herdr pane run "$split_pane" "$command"
}

review_main() {
  local -a input
  if (($# == 1)); then read -r -a input <<<"$1"; else input=("$@"); fi
  ((${#input[@]} == 1)) || {
    review_error 'Usage: nvo-review-mono.sh <branch>'
    return 1
  }
  export NVO_REVIEW_BRANCH=${input[0]#origin/} NVO_REVIEW_REPO=xcloud-platform-services
  git check-ref-format --branch "$NVO_REVIEW_BRANCH" >/dev/null || {
    review_error 'invalid review branch'
    return 1
  }
  local jira='' jira_json='' jira_title='' key root bare pr_json base state token
  if [[ $NVO_REVIEW_BRANCH =~ ([A-Z][A-Z0-9]+-[0-9]+) ]]; then
    jira=${BASH_REMATCH[1]}
  fi
  root=${NVO_WORKSPACE_ROOT:-"$HOME/workspace/${NVO_WORKSPACE_OWNER:-${USER:?}}"}
  root=$(cd "$root" && pwd -P) || return 1
  export NVO_WORKSPACE_ROOT=$root
  bare="$root/master/xcloud-platform-services"
  [[ -d $bare ]] || {
    review_error "shared repository is missing: $bare"
    return 1
  }
  token=$(env -u GH_TOKEN -u GITHUB_TOKEN gh auth token --hostname github.com --user "${NVO_MONO_GH_USER:-BADANIYA_extr}") || return 1
  pr_json=$(cd "$bare" && GH_TOKEN=$token gh pr list --repo "$(git config --get remote.origin.url)" --head "$NVO_REVIEW_BRANCH" --state open --json number,baseRefName) || return 1
  unset token
  jq -e 'type == "array" and length == 1 and (.[0].number | type == "number" and . > 0 and floor == .) and (.[0].baseRefName | type == "string" and length > 0)' >/dev/null <<<"$pr_json" || {
    review_error 'expected exactly one open PR with a base branch for this review branch'
    return 1
  }
  NVO_REVIEW_PR_NUMBER=$(jq -r '.[0].number' <<<"$pr_json")
  base=$(jq -r '.[0].baseRefName' <<<"$pr_json")
  NVO_REVIEW_JIRA_AVAILABLE=false
  NVO_REVIEW_JIRA_TITLE=''
  if [[ -n $jira ]]; then
    key="NVO-REVIEW-$jira"
    if jira_json=$(jira issue view "$jira" --raw 2>/dev/null) && jq -e 'type == "object" and (.fields | type == "object")' >/dev/null 2>&1 <<<"$jira_json"; then
      NVO_REVIEW_JIRA_AVAILABLE=true
      jira_title=$(jq -r '.fields.summary // empty' <<<"$jira_json" 2>/dev/null || true)
      NVO_REVIEW_JIRA_TITLE=${jira_title//$'\n'/ }
    fi
  else
    key="NVO-REVIEW-PR-${NVO_REVIEW_PR_NUMBER}"
  fi
  export NVO_REVIEW_MODE=true MONO_REVIEW_MODE=true NVO_REVIEW_KEY="$key" NVO_REVIEW_JIRA_TICKET="$jira"
  export NVO_REVIEW_JIRA_AVAILABLE NVO_REVIEW_JIRA_TITLE NVO_REVIEW_PR_NUMBER NVO_REVIEW_PR_BASE="$base"
  state="${XDG_STATE_HOME:-$HOME/.local/state}/herdr-spreader"
  mkdir -p "$state"
  exec 9>"$state/$key.lock"
  flock -n 9 || {
    review_error "$key is already preparing/building; retry after bootstrap finishes"
    return 1
  }
  exec bash "$HOME/.config/herdr-spreader/nvo-mono-worktree-sandbox.sh" "$key" "$NVO_REVIEW_BRANCH"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  set -euo pipefail
  review_main "$@"
fi
