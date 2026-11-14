#!/usr/bin/env bash
# Open an incremental, multi-repository PR review and agent sandbox; Jira details are optional.
# Usage: nvo-review.sh '<branch> [repo]' (repo defaults to GoDCApp).
# Also sourced by the worktree creator and sandbox coordinator for review hooks.

review_error() {
  printf 'Error: %s\n' "$*" >&2
  return 1
}

review_repo_code() {
  case $1 in
  GoDCApp) printf 'GODCAPP\n' ;;
  PlatformCommonModels) printf 'PCM\n' ;;
  PlatformServices) printf 'PS\n' ;;
  PlatformServicesCommon) printf 'PSC\n' ;;
  *) review_error "unknown review repository: $1" ;;
  esac
}

review_write_state() {
  local path=$1 value=$2 temporary
  temporary=$(mktemp "${path}.XXXXXX") || return 1
  printf '%s\n' "$value" >"$temporary"
  mv -- "$temporary" "$path"
}

prepare_review_worktrees() {
  local project=$1 root=$2 base=$3 repo bare worktree common current selected recorded line other_path=''
  local metadata="$project/.nvo-review"
  shift 3
  local -a repos=("$@")
  # The base creator must not reset locally modified/advanced submodule work
  # when reopening a review or selecting a different related repository.
  export NVO_REVIEW_PRESERVE_CASDOOR=false
  [[ ! -L $project && ! -L $metadata ]] || {
    review_error 'review project/state must not be symlinks'
    return 1
  }
  if [[ -f $metadata/base ]]; then
    base=$(<"$metadata/base")
  fi
  git check-ref-format "refs/heads/$base" >/dev/null || {
    review_error 'invalid PR base branch'
    return 1
  }

  # Validate the whole set before adding any worktree or switching any branch.
  for repo in "${repos[@]}"; do
    bare="$root/master/$repo"
    worktree="$project/$repo"
    [[ -d $bare ]] || {
      review_error "shared repository is missing: $bare"
      return 1
    }
    [[ ! -L $worktree && ! -L $metadata/$repo && ! -L $metadata/base ]] || {
      review_error 'review worktree/state must not be symlinks'
      return 1
    }
    if [[ -f $metadata/$repo && ! -d $worktree ]]; then
      review_error "selected review worktree is missing: $worktree; restore it before reopening the project"
      return 1
    fi
    if [[ -e $worktree ]]; then
      common=$(git -C "$worktree" rev-parse --git-common-dir 2>/dev/null) || common=''
      [[ -f $worktree/.git && $common == "$bare" ]] || {
        review_error "$worktree does not belong to the expected shared repository: $bare"
        return 1
      }
      current=$(git -C "$worktree" symbolic-ref --quiet --short HEAD || true)
      if [[ $repo == PlatformServices && -n $(git -C "$worktree" status --porcelain -- IAM/authn/casdoor) ]]; then
        NVO_REVIEW_PRESERVE_CASDOOR=true
      fi
      if [[ -f $metadata/$repo ]]; then
        recorded=$(<"$metadata/$repo")
        [[ $current == "$recorded" ]] || {
          review_error "selected review branch changed outside the launcher: $repo"
          return 1
        }
      fi
    fi
    if [[ $repo == "$NVO_REVIEW_REPO" ]]; then
      if [[ -f $metadata/$repo ]]; then
        selected=$(<"$metadata/$repo")
        [[ $selected == "$NVO_REVIEW_BRANCH" ]] || {
          review_error "$repo already has a different review branch: $selected"
          return 1
        }
      fi
      if [[ -e $worktree && ${current:-} != "$NVO_REVIEW_BRANCH" ]]; then
        [[ -z $(git -C "$worktree" status --porcelain) ]] || {
          review_error "$repo has local changes; refusing to switch branches"
          return 1
        }
        [[ -z ${current:-} ]] || {
          review_error "$repo has an unmanaged branch; refusing to replace it"
          return 1
        }
      fi
      while IFS= read -r line; do
        case $line in
        'worktree '*) other_path=${line#worktree } ;;
        "branch refs/heads/$NVO_REVIEW_BRANCH")
          [[ $other_path == "$worktree" ]] || {
            review_error "branch is already checked out at $other_path"
            return 1
          }
          ;;
        esac
      done < <(git -C "$bare" worktree list --porcelain)
    fi
    git -C "$bare" fetch --all --quiet || return 1
    git -C "$bare" rev-parse --verify "refs/remotes/origin/$base^{commit}" >/dev/null || {
      review_error "$repo is missing PR base branch $base"
      return 1
    }
    if [[ $repo == "$NVO_REVIEW_REPO" ]]; then
      git -C "$bare" rev-parse --verify "refs/remotes/origin/$NVO_REVIEW_BRANCH^{commit}" >/dev/null || {
        review_error "review branch is missing: $NVO_REVIEW_BRANCH"
        return 1
      }
      if [[ ! -f $metadata/$repo ]] && git -C "$bare" show-ref --verify --quiet "refs/heads/$NVO_REVIEW_BRANCH"; then
        git -C "$bare" merge-base --is-ancestor "refs/heads/$NVO_REVIEW_BRANCH" "refs/remotes/origin/$NVO_REVIEW_BRANCH" || {
          review_error "local branch $NVO_REVIEW_BRANCH has commits not in the PR; refusing to replace it"
          return 1
        }
      fi
    fi
  done

  mkdir -p "$metadata"
  [[ -f $metadata/base ]] || review_write_state "$metadata/base" "$base"
  for repo in "${repos[@]}"; do
    worktree="$project/$repo"
    if [[ ! -d $worktree ]]; then
      git -C "$root/master/$repo" worktree add --detach "$worktree" "refs/remotes/origin/$base" || return 1
    fi
    [[ $repo == "$NVO_REVIEW_REPO" ]] || continue
    current=$(git -C "$worktree" symbolic-ref --quiet --short HEAD || true)
    if [[ $current != "$NVO_REVIEW_BRANCH" ]]; then
      if git -C "$worktree" show-ref --verify --quiet "refs/heads/$NVO_REVIEW_BRANCH"; then
        git -C "$worktree" switch "$NVO_REVIEW_BRANCH" || return 1
      else
        # Create only the local tracking counterpart of the supplied PR branch,
        # never a new owner/repo/ticket private branch.
        git -C "$worktree" switch --track -c "$NVO_REVIEW_BRANCH" "origin/$NVO_REVIEW_BRANCH" || return 1
      fi
    fi
    if [[ ! -f $metadata/$repo ]]; then
      git -C "$worktree" merge --ff-only "refs/remotes/origin/$NVO_REVIEW_BRANCH" || return 1
      git -C "$worktree" branch --set-upstream-to="origin/$NVO_REVIEW_BRANCH" "$NVO_REVIEW_BRANCH" || return 1
    fi
    review_write_state "$metadata/$repo" "$NVO_REVIEW_BRANCH" || return 1
  done
}

review_create_tabs() {
  local workspace=$1 agent_tab=$2 agent_pane=$3 project=$4 state=$5 key=$6 jira=$7 agent_dir
  local repo_dir="$project/$NVO_REVIEW_REPO"
  local tab_json pane split_json split_pane command dash_config
  agent_dir=$repo_dir
  [[ $NVO_REVIEW_REPO != GoDCApp ]] || agent_dir="$repo_dir/NVO"
  herdr tab rename "$agent_tab" '1 - Agent'
  printf -v command 'cd %q && pi' "$agent_dir"
  herdr pane run "$agent_pane" "$command"

  dash_config="$state/${key}.${NVO_REVIEW_REPO}.gh-dash.yml"
  # JSON is a YAML subset and safely quotes branch names in gh-dash config.
  jq -n --arg branch "$NVO_REVIEW_BRANCH" '{prSections: [{title: $branch, filters: ("is:pr head:" + $branch)}]}' >"$dash_config"
  if [[ ${NVO_REVIEW_JIRA_AVAILABLE:-false} == true ]]; then
    tab_json=$(herdr tab create --workspace "$workspace" --cwd "$repo_dir" --label '2 - JIRA/PR' --no-focus)
    pane=$(jq -er '.result.root_pane.pane_id' <<<"$tab_json")
    printf -v command 'jira issue view %q' "$jira"
    herdr pane run "$pane" "$command"
  else
    tab_json=$(herdr tab create --workspace "$workspace" --cwd "$repo_dir" --label '2 - PR' --no-focus)
    pane=$(jq -er '.result.root_pane.pane_id' <<<"$tab_json")
  fi
  split_json=$(herdr pane split "$pane" --direction right --ratio 0.5 --cwd "$repo_dir" --no-focus)
  split_pane=$(jq -er '.result.pane.pane_id' <<<"$split_json")
  printf -v command 'GH_HOST=%q gh dash --config %q' "$NVO_REVIEW_GH_HOST" "$dash_config"
  herdr pane run "$split_pane" "$command"

  tab_json=$(herdr tab create --workspace "$workspace" --cwd "$repo_dir" --label '3 - Diff' --no-focus)
  pane=$(jq -er '.result.root_pane.pane_id' <<<"$tab_json")
  printf -v command 'GH_HOST=%q tuicr pr %q' "$NVO_REVIEW_GH_HOST" "$NVO_REVIEW_PR_NUMBER"
  herdr pane run "$pane" "$command"
  split_json=$(herdr pane split "$pane" --direction down --ratio 0.5 --cwd "$repo_dir" --no-focus)
  split_pane=$(jq -er '.result.pane.pane_id' <<<"$split_json")
  # Bash array parsing preserves filenames containing spaces in the nvim view.
  # shellcheck disable=SC2016 # The generated Bash command expands these at pane runtime.
  printf -v command 'GH_HOST=%q bash -c %q _ %q' "$NVO_REVIEW_GH_HOST" \
    'mapfile -t files < <(gh pr diff "$1" --name-only); exec nvim -- "${files[@]}"' "$NVO_REVIEW_PR_NUMBER"
  herdr pane run "$split_pane" "$command"
}

review_main() {
  local -a input
  if (($# == 1)); then read -r -a input <<<"$1"; else input=("$@"); fi
  ((${#input[@]} >= 1 && ${#input[@]} <= 2)) || {
    review_error 'Usage: nvo-review.sh <branch> [GoDCApp|PlatformServices|PlatformServicesCommon|PlatformCommonModels]'
    return 1
  }
  export NVO_REVIEW_BRANCH=${input[0]} NVO_REVIEW_REPO=${input[1]:-GoDCApp}
  case $NVO_REVIEW_REPO in
  GoDCApp | PlatformServices | PlatformServicesCommon | PlatformCommonModels) ;;
  *)
    review_error "unknown review repository: $NVO_REVIEW_REPO"
    return 1
    ;;
  esac
  git check-ref-format --branch "$NVO_REVIEW_BRANCH" >/dev/null || {
    review_error 'invalid review branch'
    return 1
  }
  local jira='' jira_json='' jira_title='' repo_code
  if [[ $NVO_REVIEW_BRANCH =~ ([A-Z][A-Z0-9]+-[0-9]+) ]]; then
    jira=${BASH_REMATCH[1]}
  fi
  local key root bare remote host pr_json base state
  if [[ -n $jira ]]; then
    key="NVO-REVIEW-$jira"
  fi
  root=${NVO_WORKSPACE_ROOT:-"$HOME/workspace/${NVO_WORKSPACE_OWNER:-${USER:?}}"}
  # Canonical absolute paths are required by both linked Git metadata and labctl.
  root=$(cd "$root" && pwd -P) || return 1
  export NVO_WORKSPACE_ROOT=$root
  bare="$root/master/$NVO_REVIEW_REPO"
  [[ -d $bare ]] || {
    review_error "shared repository is missing: $bare"
    return 1
  }
  remote=$(git -C "$bare" config --get remote.origin.url) || return 1
  case $remote in
  https://* | http://* | ssh://*)
    host=${remote#*://}
    host=${host#*@}
    host=${host%%/*}
    host=${host%%:*}
    ;;
  *@*:*)
    host=${remote#*@}
    host=${host%%:*}
    ;;
  *)
    review_error "cannot determine GitHub host from remote: $remote"
    return 1
    ;;
  esac
  [[ $host =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]] || {
    review_error 'invalid GitHub host'
    return 1
  }
  export NVO_REVIEW_GH_HOST=$host
  pr_json=$(cd "$bare" && GH_HOST="$host" gh pr list --head "$NVO_REVIEW_BRANCH" --state open --json number,baseRefName) || return 1
  jq -e 'type == "array" and length == 1 and (.[0].number | type == "number" and . > 0 and floor == .) and (.[0].baseRefName | type == "string" and length > 0)' >/dev/null <<<"$pr_json" || {
    review_error 'expected exactly one open PR with a base branch for this review branch'
    return 1
  }
  NVO_REVIEW_PR_NUMBER=$(jq -r '.[0].number' <<<"$pr_json")
  base=$(jq -r '.[0].baseRefName' <<<"$pr_json")
  NVO_REVIEW_JIRA_AVAILABLE=false
  NVO_REVIEW_JIRA_TITLE=''
  if [[ -n $jira ]]; then
    if jira_json=$(jira issue view "$jira" --raw 2>/dev/null) && jq -e 'type == "object" and (.fields | type == "object")' >/dev/null 2>&1 <<<"$jira_json"; then
      NVO_REVIEW_JIRA_AVAILABLE=true
      jira_title=$(jq -r '.fields.summary // empty' <<<"$jira_json" 2>/dev/null || true)
      NVO_REVIEW_JIRA_TITLE=${jira_title//$'\n'/ }
    fi
  else
    repo_code=$(review_repo_code "$NVO_REVIEW_REPO") || return 1
    key="NVO-REVIEW-${repo_code}-PR-${NVO_REVIEW_PR_NUMBER}"
  fi
  git check-ref-format "refs/heads/$base" >/dev/null || {
    review_error 'invalid PR base branch'
    return 1
  }

  export NVO_REVIEW_MODE=true NVO_REVIEW_KEY="$key" NVO_REVIEW_JIRA_TICKET="$jira"
  export NVO_REVIEW_JIRA_AVAILABLE NVO_REVIEW_JIRA_TITLE NVO_REVIEW_PR_NUMBER NVO_REVIEW_PR_BASE="$base"
  state="${XDG_STATE_HOME:-$HOME/.local/state}/herdr-spreader"
  mkdir -p "$state"
  # The detached bootstrap inherits fd 9, so another invocation cannot change
  # this project's source or truncate its live stage logs until it completes.
  exec 9>"$state/$key.lock"
  flock -n 9 || {
    review_error "$key is already preparing/building; retry after bootstrap finishes"
    return 1
  }
  exec bash "$HOME/.config/herdr-spreader/nvo-harness-worktree-sandbox.sh" "$key" "$base"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  set -euo pipefail
  review_main "$@"
fi
