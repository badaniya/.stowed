#!/usr/bin/env bash
# Real Git integration tests; only GitHub, Jira, Herdr and Incus are external doubles.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$REPO_ROOT/herdr/.config/herdr-spreader/nvo-review.sh"
fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}
contains() { rg -Fq -- "$1" "$2" || fail "missing '$1' in $2"; }
not_contains() { if rg -Fq -- "$1" "$2"; then fail "unexpected '$1' in $2"; fi; }
branch_is() {
  local actual
  actual=$(git -C "$1" symbolic-ref --quiet --short HEAD || printf detached)
  [[ $actual == "$2" ]] || fail "$1: expected branch $2, got $actual"
}
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
export HOME="$TEST_ROOT/home" XDG_CONFIG_HOME="$TEST_ROOT/home/.config" XDG_STATE_HOME="$TEST_ROOT/state"
export NVO_WORKSPACE_OWNER=reviewer NVO_WORKSPACE_ROOT="$TEST_ROOT/workspace"
export TEST_LOG="$TEST_ROOT/commands.log" TEST_COUNTER="$TEST_ROOT/counter"
export GIT_CONFIG_NOSYSTEM=1 GIT_ALLOW_PROTOCOL=file
unset NVO_HARNESS_SANDBOX_BOOTSTRAP_WORKER NVO_REVIEW_BRANCH NVO_REVIEW_REPO NVO_REVIEW_PR_NUMBER NVO_REVIEW_GH_HOST
mkdir -p "$HOME/.config/herdr-spreader" "$HOME/.local/bin" "$TEST_ROOT/bin" "$NVO_WORKSPACE_ROOT/master" "$TEST_ROOT/remotes"
export PATH="$TEST_ROOT/bin:$PATH"
: >"$TEST_LOG"
printf '0\n' >"$TEST_COUNTER"
git config --global user.name 'Review Test'
git config --global user.email review@example.invalid
git config --global init.defaultBranch 25.16.0
git config --global "url.file://$TEST_ROOT/remotes/.insteadOf" https://github.extremenetworks.com/Engineering/
for name in nvo-review.sh nvo-harness-worktree-sandbox-base.sh nvo-harness-worktree-sandbox.sh; do
  ln -s "$REPO_ROOT/herdr/.config/herdr-spreader/$name" "$HOME/.config/herdr-spreader/$name"
done

# A real pinned submodule ensures the review setup does not skip PS prerequisites.
git init -q "$TEST_ROOT/remotes/casdoor"
printf 'casdoor fixture\n' >"$TEST_ROOT/remotes/casdoor/README"
git -C "$TEST_ROOT/remotes/casdoor" add .
git -C "$TEST_ROOT/remotes/casdoor" commit -qm initial
for repo in GoDCApp PlatformCommonModels PlatformServices PlatformServicesCommon; do
  seed="$TEST_ROOT/seed/$repo"
  git init -q "$seed"
  mkdir -p "$seed/.agents/skills/$repo" "$seed/.claude/commands" "$seed/scripts/development" "$seed/NVO/scripts/development"
  printf '%s\n' "$repo" >"$seed/.agents/skills/$repo/SKILL.md"
  printf '%s\n' "$repo" >"$seed/.claude/commands/$repo.md"
  printf 'base\n' >"$seed/README"
  if [[ $repo == PlatformServices ]]; then
    git -C "$seed" submodule add -q "file://$TEST_ROOT/remotes/casdoor" IAM/authn/casdoor
  fi
  git -C "$seed" add .
  git -C "$seed" commit -qm initial
  git -C "$seed" switch -qc 25.17.0
  printf 'newer version\n' >"$seed/README"
  git -C "$seed" commit -qam 'newer base'
  git -C "$seed" switch -q 25.16.0
  for branch in alice/CFD-18711-feature bob/CFD-18711-related bob/CFD-18711-conflict alice/NVO-123-feature alice/no-ticket; do
    git -C "$seed" switch -qc "$branch" 25.16.0
    printf '%s\n' "$branch" >"$seed/README"
    git -C "$seed" commit -qam 'private PR change'
  done
  git -C "$seed" switch -q 25.16.0
  git clone -q --bare "$seed" "$TEST_ROOT/remotes/$repo"
  git clone -q --bare "$TEST_ROOT/remotes/$repo" "$NVO_WORKSPACE_ROOT/master/$repo"
  git -C "$NVO_WORKSPACE_ROOT/master/$repo" config remote.origin.url "https://github.extremenetworks.com/Engineering/$repo"
  git -C "$NVO_WORKSPACE_ROOT/master/$repo" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
done
# The bare clone has an older local branch: fetch must not review that stale tip.
git -C "$TEST_ROOT/seed/GoDCApp" switch -q alice/CFD-18711-feature
printf 'latest PR commit\n' >>"$TEST_ROOT/seed/GoDCApp/README"
git -C "$TEST_ROOT/seed/GoDCApp" commit -qam 'latest PR commit'
git -C "$TEST_ROOT/seed/GoDCApp" push -q "$TEST_ROOT/remotes/GoDCApp" alice/CFD-18711-feature
cat >"$TEST_ROOT/bin/gh" <<'GH'
#!/usr/bin/env bash
printf 'gh host=%s cwd=%s %s\n' "${GH_HOST:-}" "$PWD" "$*" >>"$TEST_LOG"
[[ $1 == pr && $2 == list ]] || exit 2
if [[ -n ${TEST_PR_JSON:-} ]]; then
  printf '%s\n' "$TEST_PR_JSON"
else
  printf '%s\n' '[{"number":32941,"baseRefName":"25.16.0","headRefName":"alice/CFD-18711-feature"}]'
fi
GH
cat >"$TEST_ROOT/bin/jira" <<'JIRA'
#!/usr/bin/env bash
printf 'jira %s\n' "$*" >>"$TEST_LOG"
[[ $1 == issue && $2 == view && $3 =~ ^(CFD|NVO)-[0-9]+$ && $4 == --raw ]] || exit 2
printf '%s\n' '{"fields":{"summary":"Review fixture"}}'
JIRA
cat >"$HOME/.local/bin/labctl" <<'LABCTL'
#!/usr/bin/env bash
printf 'labctl %s\n' "$*" >>"$TEST_LOG"
case $1 in
  create) [[ ${TEST_DELAY_CREATE:-false} != true ]] || sleep 1 ;;
  instance-user) printf 'reviewer\n' ;;
  instance-project) printf 'agent-sandbox\n' ;;
  stage) [[ ${TEST_FAIL_STAGE:-} != "$3" ]] || exit 1 ;;
esac
LABCTL
cat >"$TEST_ROOT/bin/sg" <<'SG'
#!/usr/bin/env bash
[[ $1 == incus-admin && $2 == -c ]] || exit 2
bash -c "$3"
SG
cat >"$TEST_ROOT/bin/incus" <<'INCUS'
#!/usr/bin/env bash
[[ $1 == --project && $2 == agent-sandbox && $3 == list && $4 == nvo-review-* && $5 == --format && $6 == json ]] || exit 2
printf '%s\n' '[{"state":{"network":{"eth0":{"addresses":[{"family":"inet","scope":"global","address":"10.42.0.41"}]}}}}]'
INCUS
cat >"$TEST_ROOT/bin/herdr" <<'HERDR'
#!/usr/bin/env bash
printf 'herdr %s\n' "$*" >>"$TEST_LOG"
case "$1 $2" in
  'workspace create' | 'tab create' | 'pane split')
    n=$(<"$TEST_COUNTER"); n=$((n + 1)); printf '%s\n' "$n" >"$TEST_COUNTER"
    printf '{"result":{"workspace":{"workspace_id":"w1"},"tab":{"tab_id":"w1:t%s"},"root_pane":{"pane_id":"w1:p%s"},"pane":{"pane_id":"w1:p%s"}}}\n' "$n" "$n" "$n"
    ;;
  'pane run' | 'pane rename' | 'tab rename') : ;;
  *) exit 2 ;;
esac
HERDR
chmod +x "$TEST_ROOT/bin/"* "$HOME/.local/bin/labctl"

run_review() { bash "$SCRIPT" "$@" >"$TEST_ROOT/output" 2>&1 || {
  read_output
  fail 'review launch failed'
}; }
read_output() { while IFS= read -r line; do printf '%s\n' "$line" >&2; done <"$TEST_ROOT/output"; }
expect_failure() {
  if bash "$SCRIPT" "$@" >"$TEST_ROOT/output" 2>&1; then fail "unexpected success: $*"; fi
}
wait_bootstrap() {
  local key=$1 marker=${2:-NVO_SANDBOX_BOOTSTRAP_SUCCESS} attempts=150
  local log="$XDG_STATE_HOME/herdr-spreader/$key.log"
  until rg -Fq "$marker" "$log" 2>/dev/null; do
    ((attempts-- > 0)) || {
      read_output
      fail "bootstrap did not produce $marker"
    }
    sleep 0.05
  done
  # Marker precedes worker exit; wait for its inherited project lock as well.
  flock -w 5 "$XDG_STATE_HOME/herdr-spreader/$key.lock" true || fail 'worker kept project lock'
}

# Break caught: launching the legacy fixed-root action instead of four linked worktrees.
[[ -f $SCRIPT ]] || fail 'tracked Jira-scoped review launcher is missing'
run_review 'alice/CFD-18711-feature'
wait_bootstrap NVO-REVIEW-CFD-18711
project="$NVO_WORKSPACE_ROOT/NVO-REVIEW-CFD-18711"
for repo in GoDCApp PlatformCommonModels PlatformServices PlatformServicesCommon; do
  [[ -f $project/$repo/.git ]] || fail "$repo is not a linked worktree"
  [[ $(git -C "$project/$repo" rev-parse --git-common-dir) == "$NVO_WORKSPACE_ROOT/master/$repo" ]] || fail "$repo uses wrong bare repository"
  [[ -L $project/.agents/skills/$repo/SKILL.md && -L $project/.claude/commands/$repo.md ]] || fail "$repo context is not aggregated"
done
branch_is "$project/GoDCApp" alice/CFD-18711-feature
contains 'latest PR commit' "$project/GoDCApp/README"
[[ $(git -C "$project/GoDCApp" rev-parse HEAD) == "$(git -C "$NVO_WORKSPACE_ROOT/master/GoDCApp" rev-parse refs/remotes/origin/alice/CFD-18711-feature)" ]] || fail 'review checked out stale local PR branch'
contains 'base' "$project/PlatformCommonModels/README"
not_contains 'newer version' "$project/PlatformCommonModels/README"
branch_is "$project/PlatformServices" detached
branch_is "$project/PlatformCommonModels" detached
branch_is "$project/PlatformServicesCommon" detached
[[ -f $project/PlatformServices/IAM/authn/casdoor/README ]] || fail 'pinned PS submodule was not initialized'
contains 'gh host=github.extremenetworks.com' "$TEST_LOG"
contains 'jira issue view CFD-18711 --raw' "$TEST_LOG"
contains '1 - Agent' "$TEST_LOG"
contains '2 - JIRA/PR' "$TEST_LOG"
contains '3 - Diff' "$TEST_LOG"
contains '4 - Build' "$TEST_LOG"
contains "cd $project/GoDCApp/NVO && pi" "$TEST_LOG"
contains 'pi' "$TEST_LOG"
contains 'tuicr pr 32941' "$TEST_LOG"
contains 'labctl create NVO-REVIEW-CFD-18711' "$TEST_LOG"
contains 'labctl stage NVO-REVIEW-CFD-18711 godcapp-services' "$TEST_LOG"
contains 'exec_agent_sandbox nvo-review-cfd-18711 --command' "$TEST_LOG"
contains "$project/PlatformCommonModels/scripts/development" "$TEST_LOG"
contains "$project/PlatformServices/scripts/development" "$TEST_LOG"
contains "$project/GoDCApp/NVO/scripts/development" "$TEST_LOG"
not_contains '2 - Build' "$TEST_LOG"
not_contains 'reviewer/GoDCApp/CFD-18711' "$TEST_LOG"
[[ ! -e $NVO_WORKSPACE_ROOT/NVO-REVIEW ]] || fail 'legacy shared root was created'

# Break caught: adding a related repo resets a selected branch or moves fallback repos.
printf 'local review notes\n' >"$project/GoDCApp/untracked-notes"
printf 'dirty fallback\n' >>"$project/PlatformCommonModels/README"
fallback_commit=$(git -C "$project/PlatformServicesCommon" rev-parse HEAD)
TEST_PR_JSON='[{"number":32942,"baseRefName":"25.17.0","headRefName":"bob/CFD-18711-related"}]' run_review 'bob/CFD-18711-related PlatformServices'
wait_bootstrap NVO-REVIEW-CFD-18711
branch_is "$project/PlatformServices" bob/CFD-18711-related
branch_is "$project/GoDCApp" alice/CFD-18711-feature
[[ -f $project/GoDCApp/untracked-notes ]] || fail 'existing dirty selected repo was modified'
contains 'dirty fallback' "$project/PlatformCommonModels/README"
[[ $(git -C "$project/PlatformServicesCommon" rev-parse HEAD) == "$fallback_commit" ]] || fail 'original fallback base moved'
contains 'tuicr pr 32942' "$TEST_LOG"
contains "--cwd $project/PlatformServices" "$TEST_LOG"

# Reopening must also preserve locally advanced/dirty PS submodule work, not
# silently detach it back to the superproject's pinned commit.
casdoor="$project/PlatformServices/IAM/authn/casdoor"
printf 'local submodule review work\n' >>"$casdoor/README"
git -C "$casdoor" commit -qam 'local submodule review work'
casdoor_commit=$(git -C "$casdoor" rev-parse HEAD)

# Reopening the exact selected branch preserves tracked and untracked changes.
printf 'local changes\n' >>"$project/GoDCApp/README"
run_review alice/CFD-18711-feature GoDCApp
wait_bootstrap NVO-REVIEW-CFD-18711
contains 'local changes' "$project/GoDCApp/README"
[[ $(git -C "$casdoor" rev-parse HEAD) == "$casdoor_commit" ]] || fail 'local PS submodule commit was reset'
expect_failure bob/CFD-18711-conflict GoDCApp
contains 'different review branch' "$TEST_ROOT/output"
branch_is "$project/GoDCApp" alice/CFD-18711-feature

# Dirty fallback must not be switched to a related branch.
expect_failure bob/CFD-18711-related PlatformCommonModels
contains 'local changes' "$TEST_ROOT/output"
branch_is "$project/PlatformCommonModels" detached

# Unavailable PR, malformed input, absent ticket and missing base cannot create worktrees.
TEST_PR_JSON='[]' expect_failure alice/NVO-123-feature
[[ ! -e $NVO_WORKSPACE_ROOT/NVO-REVIEW-NVO-123 ]] || fail 'missing PR created project'
expect_failure alice/no-ticket
expect_failure alice/NVO-123-feature UnknownRepo
expect_failure 'alice/NVO-123-feature GoDCApp unexpected'
TEST_PR_JSON='[{"number":1,"baseRefName":"missing-version","headRefName":"alice/NVO-123-feature"}]' expect_failure alice/NVO-123-feature
[[ ! -e $NVO_WORKSPACE_ROOT/NVO-REVIEW-NVO-123/GoDCApp ]] || fail 'missing base created worktree'

# A branch in use elsewhere must fail without forcing a second checkout.
git -C "$NVO_WORKSPACE_ROOT/master/GoDCApp" worktree add -q "$TEST_ROOT/elsewhere" alice/NVO-123-feature
expect_failure alice/NVO-123-feature
contains 'already checked out' "$TEST_ROOT/output"
[[ ! -e $NVO_WORKSPACE_ROOT/NVO-REVIEW-NVO-123/GoDCApp ]] || fail 'branch conflict created worktree'
git -C "$NVO_WORKSPACE_ROOT/master/GoDCApp" worktree remove "$TEST_ROOT/elsewhere"

# Validate all four base refs before creating the first worktree.
base_commit=$(git -C "$TEST_ROOT/remotes/PlatformServicesCommon" rev-parse refs/heads/25.16.0)
git -C "$TEST_ROOT/remotes/PlatformServicesCommon" update-ref -d refs/heads/25.16.0
git -C "$NVO_WORKSPACE_ROOT/master/PlatformServicesCommon" update-ref -d refs/remotes/origin/25.16.0
expect_failure alice/NVO-123-feature
contains 'PlatformServicesCommon is missing PR base' "$TEST_ROOT/output"
[[ ! -e $NVO_WORKSPACE_ROOT/NVO-REVIEW-NVO-123/GoDCApp ]] || fail 'partial base failure created worktree'
git -C "$TEST_ROOT/remotes/PlatformServicesCommon" update-ref refs/heads/25.16.0 "$base_commit"

# Local commits on an unselected PR branch must never be reset or mixed into the PR.
local_ref=refs/heads/alice/NVO-123-feature
local_tip=$(git -C "$NVO_WORKSPACE_ROOT/master/GoDCApp" rev-parse "$local_ref")
local_commit=$(printf 'local-only commit\n' | git -C "$NVO_WORKSPACE_ROOT/master/GoDCApp" commit-tree "$local_ref^{tree}" -p "$local_tip")
git -C "$NVO_WORKSPACE_ROOT/master/GoDCApp" update-ref "$local_ref" "$local_commit"
expect_failure alice/NVO-123-feature
contains 'commits not in the PR' "$TEST_ROOT/output"
[[ $(git -C "$NVO_WORKSPACE_ROOT/master/GoDCApp" rev-parse "$local_ref") == "$local_commit" ]] || fail 'local commits were overwritten'
git -C "$NVO_WORKSPACE_ROOT/master/GoDCApp" update-ref "$local_ref" "$local_tip"

# Selecting a remote-only related branch creates its exact local tracking name.
git -C "$NVO_WORKSPACE_ROOT/master/PlatformServicesCommon" update-ref -d refs/heads/bob/CFD-18711-related
TEST_PR_JSON='[{"number":32943,"baseRefName":"25.16.0"}]' run_review bob/CFD-18711-related PlatformServicesCommon
wait_bootstrap NVO-REVIEW-CFD-18711
branch_is "$project/PlatformServicesCommon" bob/CFD-18711-related
[[ $(git -C "$project/PlatformServicesCommon" rev-parse --abbrev-ref '@{upstream}') == origin/bob/CFD-18711-related ]] || fail 'wrong tracking branch'

# A missing previously selected worktree must not silently return on the base version.
git -C "$project/PlatformServicesCommon" worktree remove "$project/PlatformServicesCommon"
if bash "$SCRIPT" alice/CFD-18711-feature >"$TEST_ROOT/output" 2>&1; then
  wait_bootstrap NVO-REVIEW-CFD-18711
  fail 'missing selected worktree was silently recreated on the fallback base'
fi
contains 'selected review worktree is missing' "$TEST_ROOT/output"

# A second Jira gets its own project and instance; same fallback ref can be shared.
TEST_PR_JSON='[{"number":123,"baseRefName":"25.16.0","headRefName":"alice/NVO-123-feature"}]' run_review alice/NVO-123-feature
wait_bootstrap NVO-REVIEW-NVO-123
other="$NVO_WORKSPACE_ROOT/NVO-REVIEW-NVO-123"
branch_is "$other/GoDCApp" alice/NVO-123-feature
contains 'labctl create NVO-REVIEW-NVO-123' "$TEST_LOG"
branch_is "$project/GoDCApp" alice/CFD-18711-feature

# Refuse to reset bootstrap logs or change repositories while that Jira is building.
TEST_DELAY_CREATE=true run_review alice/NVO-123-feature
expect_failure alice/NVO-123-feature
contains 'already preparing' "$TEST_ROOT/output"
wait_bootstrap NVO-REVIEW-NVO-123

# Existing directory must be a worktree of the expected shared bare repository.
git -C "$other/PlatformServicesCommon" worktree remove --force "$other/PlatformServicesCommon"
git init -q "$other/PlatformServicesCommon"
TEST_PR_JSON='[{"number":123,"baseRefName":"25.16.0","headRefName":"alice/NVO-123-feature"}]' expect_failure alice/NVO-123-feature
contains 'expected shared repository' "$TEST_ROOT/output"

# The shared creator must retain ordinary development-worktree branch policy.
NVO_HARNESS_DEFER_WORKSPACE=true bash "$HOME/.config/herdr-spreader/nvo-harness-worktree-sandbox-base.sh" 'NVO-999 25.16.0' >"$TEST_ROOT/output" 2>&1 || {
  read_output
  fail 'ordinary worktree creation regressed'
}
for repo in GoDCApp PlatformCommonModels PlatformServices PlatformServicesCommon; do
  branch_is "$NVO_WORKSPACE_ROOT/NVO-999/$repo" "reviewer/$repo/NVO-999"
done

printf 'PASS: Jira-scoped multi-repository review worktrees and sandbox\n'
