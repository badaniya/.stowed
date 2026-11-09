#!/usr/bin/env bash
# Real local Git regression: no GitHub/Jira/Herdr/Incus or sandbox startup.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$REPO_ROOT/herdr/.config/herdr-spreader/nvo-harness-worktree-sandbox-base.sh"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
export HOME="$TEST_ROOT/home" XDG_CONFIG_HOME="$TEST_ROOT/home/.config" TMPDIR="$TEST_ROOT/tmp"
export NVO_WORKSPACE_OWNER=fixture NVO_WORKSPACE_ROOT="$TEST_ROOT/workspace"
export GIT_CONFIG_NOSYSTEM=1 GIT_ALLOW_PROTOCOL=file NVO_HARNESS_DEFER_WORKSPACE=true
unset NVO_REVIEW_BRANCH NVO_REVIEW_REPO NVO_REVIEW_PRESERVE_CASDOOR HARNESS_SNAPSHOT
mkdir -p "$HOME" "$TEST_ROOT/bin" "$TMPDIR" "$NVO_WORKSPACE_ROOT/master" "$TEST_ROOT/remotes"
export PATH="$TEST_ROOT/bin:$PATH"
git config --global user.name 'Worktree Test'
git config --global user.email worktree@example.invalid
git config --global init.defaultBranch 25.16.0
git init -q "$TEST_ROOT/remotes/casdoor"
printf 'fixture\n' >"$TEST_ROOT/remotes/casdoor/README"
git -C "$TEST_ROOT/remotes/casdoor" add .
git -C "$TEST_ROOT/remotes/casdoor" commit -qm initial
REPOS=(GoDCApp PlatformCommonModels PlatformServices PlatformServicesCommon)
for repo in "${REPOS[@]}"; do
  seed="$TEST_ROOT/seed/$repo"
  git init -q "$seed"
  printf 'old\n' >"$seed/README"
  if [[ $repo == PlatformServices ]]; then
    git -C "$seed" submodule add -q "file://$TEST_ROOT/remotes/casdoor" IAM/authn/casdoor
  fi
  git -C "$seed" add .
  git -C "$seed" commit -qm initial
  git -C "$seed" switch -qc 25.17.0
  printf 'release\n' >"$seed/README"
  git -C "$seed" commit -qam release
  git -C "$seed" switch -q 25.16.0
  git clone -q --bare "$seed" "$TEST_ROOT/remotes/$repo"
  git clone -q --bare "$TEST_ROOT/remotes/$repo" "$NVO_WORKSPACE_ROOT/master/$repo"
  git -C "$NVO_WORKSPACE_ROOT/master/$repo" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
  # Reproduce a release branch created after the master bare clone: no local ref.
  git -C "$NVO_WORKSPACE_ROOT/master/$repo" update-ref -d refs/heads/25.17.0
done
printf '#!/usr/bin/env bash\nprintf '\''{"fields":{"summary":"Worktree fixture"}}\\n'\''\n' >"$TEST_ROOT/bin/jira"
chmod +x "$TEST_ROOT/bin/jira"

run_case() {
  local ticket=$1 upstream=$2 repo expected actual tracking
  if ! HARNESS_SNAPSHOT=none bash "$SCRIPT" "$ticket" "$upstream" >"$TEST_ROOT/output" 2>&1; then
    fail "creation from $upstream failed: $(<"$TEST_ROOT/output")"
  fi
  for repo in "${REPOS[@]}"; do
    expected=$(git -C "$TEST_ROOT/remotes/$repo" rev-parse refs/heads/25.17.0)
    actual=$(git -C "$NVO_WORKSPACE_ROOT/$ticket/$repo" rev-parse HEAD)
    [[ $actual == "$expected" ]] || fail "$repo used a stale/local base for $upstream"
    tracking=$(git -C "$NVO_WORKSPACE_ROOT/$ticket/$repo" rev-parse --symbolic-full-name '@{upstream}')
    [[ $tracking == refs/remotes/origin/25.17.0 ]] || fail "$repo has incorrect upstream $tracking"
  done
}
run_case NVO-100 25.17.0
run_case NVO-101 origin/25.17.0

# A stale local version branch must not take precedence over a fresh remote tip.
for repo in "${REPOS[@]}"; do
  git -C "$NVO_WORKSPACE_ROOT/master/$repo" update-ref refs/heads/25.17.0 "$(git -C "$TEST_ROOT/remotes/$repo" rev-parse refs/heads/25.16.0)"
done
run_case NVO-102 25.17.0

# Prefix normalization also applies to the version-keyed harness lookup.
mkdir -p "$HOME/harness-snapshots/25.17.0" "$TEST_ROOT/snapshot" "$NVO_WORKSPACE_ROOT/NVO-103"
printf '# Fixture harness\n' >"$TEST_ROOT/snapshot/CLAUDE.md"
cp "$TEST_ROOT/snapshot/CLAUDE.md" "$NVO_WORKSPACE_ROOT/NVO-103/CLAUDE.md"
tar -czf "$HOME/harness-snapshots/25.17.0/fixture.tar.gz" -C "$TEST_ROOT/snapshot" CLAUDE.md
bash "$SCRIPT" 'NVO-103 origin/25.17.0 --restore-harness' >"$TEST_ROOT/output" 2>&1 || fail "prefixed snapshot lookup failed"
rg -Fq 'Harness snapshot for 25.17.0: fixture.tar.gz' "$TEST_ROOT/output" || fail 'snapshot lookup retained origin prefix'
if rg -Fq 'origin/origin/' "$TEST_ROOT/output"; then fail 'origin prefix doubled'; fi
printf 'PASS: remote-only, origin-prefixed, stale-local and snapshot cases\n'
