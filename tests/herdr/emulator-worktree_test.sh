#!/usr/bin/env bash
# Real Git fixtures only; the fixed GitHub URL is redirected to a local remote.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
HELPER="$REPO_ROOT/herdr-spreader/.config/herdr-spreader/emulator-worktree.sh"
fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}
[[ -f $HELPER ]] || fail 'cloudemu worktree helper is missing'
# shellcheck source=/dev/null
source "$HELPER"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
export HOME="$TEST_ROOT/home" GIT_CONFIG_NOSYSTEM=1 GIT_ALLOW_PROTOCOL=file
export GIT_CONFIG_GLOBAL="$HOME/.gitconfig" XDG_CONFIG_HOME="$HOME/.config"
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR
mkdir -p "$HOME" "$TEST_ROOT/workspace/master"
git config --global user.name Fixture
git config --global user.email fixture@example.invalid
git config --global init.defaultBranch master
git init -q "$TEST_ROOT/seed"
printf 'initial\n' >"$TEST_ROOT/seed/README"
mkdir -p "$TEST_ROOT/seed/.agents/skills/cloudemu" "$TEST_ROOT/seed/.claude"
printf 'cloudemu skill\n' >"$TEST_ROOT/seed/.agents/skills/cloudemu/SKILL.md"
printf 'cloudemu context\n' >"$TEST_ROOT/seed/.claude/cloudemu.md"
git -C "$TEST_ROOT/seed" add .
git -C "$TEST_ROOT/seed" commit -qm initial
git clone -q --bare "$TEST_ROOT/seed" "$TEST_ROOT/remote"
git config --global url."file://$TEST_ROOT/remote".insteadOf https://github.extremenetworks.com/thomma/cloudemu.git
root="$TEST_ROOT/workspace"
run_prepare() { emulator_worktree_prepare "$root" fixture "$1" >"$TEST_ROOT/output" 2>&1 || fail "prepare $1: $(<"$TEST_ROOT/output")"; }
reject_prepare() {
  if emulator_worktree_prepare "$root" fixture "$1" >"$TEST_ROOT/output" 2>&1; then fail "accepted unsafe state for $1"; fi
  rg -q '^Error:' "$TEST_ROOT/output" || fail "unsafe state for $1 failed without an explanation"
}
run_prepare EMULATOR-10
bare="$root/master/cloudemu"
worktree="$root/EMULATOR-10/cloudemu"
[[ $(git -C "$bare" rev-parse --is-bare-repository) == true ]] || fail 'shared clone is not bare'
[[ $(git -C "$worktree" branch --show-current) == fixture/cloudemu/EMULATOR-10 ]] || fail 'wrong ticket branch'
[[ $(git -C "$worktree" rev-parse --symbolic-full-name '@{upstream}') == refs/remotes/origin/master ]] || fail 'wrong upstream'
initial=$(git -C "$worktree" rev-parse HEAD)
[[ $initial == "$(git -C "$TEST_ROOT/remote" rev-parse master)" ]] || fail 'wrong master tip'
# Dirty reuse must not reset HEAD or edits when the remote advances.
printf 'uncommitted\n' >"$worktree/local-changes"
printf 'new tip\n' >"$TEST_ROOT/seed/README"
git -C "$TEST_ROOT/seed" commit -qam advance
git -C "$TEST_ROOT/seed" push -q "$TEST_ROOT/remote" master
run_prepare EMULATOR-10
[[ $(git -C "$worktree" rev-parse HEAD) == "$initial" && -f $worktree/local-changes ]] || fail 'reuse lost local work'
# A stale local master must not override the freshly fetched origin/master.
run_prepare EMULATOR-11
[[ $(git -C "$root/EMULATOR-11/cloudemu" rev-parse HEAD) == "$(git -C "$TEST_ROOT/remote" rev-parse master)" ]] || fail 'used stale local master'
# Retry a ticket branch left behind before worktree creation.
git -C "$bare" branch -q --track fixture/cloudemu/EMULATOR-12 refs/remotes/origin/master
run_prepare EMULATOR-12
# Refuse an existing wrong branch even in the correct shared repository.
git -C "$root/EMULATOR-12/cloudemu" switch -qc unexpected
reject_prepare EMULATOR-12
[[ $(git -C "$root/EMULATOR-12/cloudemu" branch --show-current) == unexpected ]] || fail 'changed wrong branch'
# An unrelated directory and a symlink must never be treated as reusable worktrees.
mkdir -p "$root/EMULATOR-13/cloudemu"
printf 'keep\n' >"$root/EMULATOR-13/cloudemu/sentinel"
reject_prepare EMULATOR-13
[[ -f $root/EMULATOR-13/cloudemu/sentinel ]] || fail 'removed unrelated directory'
mkdir -p "$root/EMULATOR-14"
ln -s "$worktree" "$root/EMULATOR-14/cloudemu"
reject_prepare EMULATOR-14
ln -s "$root/EMULATOR-10" "$root/EMULATOR-15"
reject_prepare EMULATOR-15
# Refuse a real worktree from a different repository.
git init -q "$TEST_ROOT/unrelated"
git -C "$TEST_ROOT/unrelated" commit -qm empty --allow-empty
mkdir -p "$root/EMULATOR-16"
git -C "$TEST_ROOT/unrelated" worktree add -q -b fixture/cloudemu/EMULATOR-16 "$root/EMULATOR-16/cloudemu"
reject_prepare EMULATOR-16
# Refuse wrong shared-clone identity before fetching or creating ticket state.
git -C "$bare" remote set-url origin https://github.com/other/cloudemu.git
reject_prepare EMULATOR-17
[[ ! -e $root/EMULATOR-17 ]] || fail 'wrong origin created ticket state'
git -C "$bare" remote set-url origin https://github.extremenetworks.com/thomma/cloudemu.git
# Invalid inputs cannot escape the root or form branch/path fragments.
for ticket in '../escape' 'NVO-123' 'EMULATOR-1/escape'; do reject_prepare "$ticket"; done
# Shared clones must be bare and physical directories, not arbitrary checkouts.
other_root="$TEST_ROOT/non-bare"
mkdir -p "$other_root/master"
git clone -q "$TEST_ROOT/remote" "$other_root/master/cloudemu"
git -C "$other_root/master/cloudemu" remote set-url origin https://github.extremenetworks.com/thomma/cloudemu.git
if emulator_worktree_prepare "$other_root" fixture EMULATOR-20 >"$TEST_ROOT/output" 2>&1; then fail 'accepted non-bare shared clone'; fi
symlink_root="$TEST_ROOT/symlink-root"
mkdir -p "$symlink_root/master"
ln -s "$bare" "$symlink_root/master/cloudemu"
if emulator_worktree_prepare "$symlink_root" fixture EMULATOR-21 >"$TEST_ROOT/output" 2>&1; then fail 'accepted symlink shared clone'; fi
# Failed clones leave neither published metadata nor temporary clone directories.
failed_root="$TEST_ROOT/failed-clone"
mkdir -p "$failed_root/master"
git config --global --unset-all url."file://$TEST_ROOT/remote".insteadOf
git config --global url."file://$TEST_ROOT/missing-remote".insteadOf https://github.extremenetworks.com/thomma/cloudemu.git
if emulator_worktree_prepare "$failed_root" fixture EMULATOR-23 >"$TEST_ROOT/output" 2>&1; then fail 'missing remote clone succeeded'; fi
[[ ! -e $failed_root/master/cloudemu && ! -e $failed_root/EMULATOR-23 ]] || fail 'failed clone published partial state'
[[ -z $(find "$failed_root/master" -mindepth 1 -maxdepth 1 -print -quit) ]] || fail 'failed clone left temporary state'
git config --global --unset-all url."file://$TEST_ROOT/missing-remote".insteadOf
git config --global url."file://$TEST_ROOT/remote".insteadOf https://github.extremenetworks.com/thomma/cloudemu.git
# A pre-existing bare clone may lack remote fetch mappings (git clone --bare).
git -C "$bare" config --unset-all remote.origin.fetch
run_prepare EMULATOR-22
[[ $(git -C "$root/EMULATOR-22/cloudemu" rev-parse --symbolic-full-name '@{upstream}') == refs/remotes/origin/master ]] || fail 'existing bare clone lacks tracking setup'
# Removal must reject an unexpected upstream before removing any files.
git -C "$bare" branch --unset-upstream fixture/cloudemu/EMULATOR-22
if emulator_worktree_remove "$root" fixture EMULATOR-22 >"$TEST_ROOT/output" 2>&1; then fail 'removed branch with unknown upstream'; fi
[[ -f $root/EMULATOR-22/cloudemu/.git ]] || fail 'upstream validation happened after worktree deletion'
git -C "$bare" branch -u origin/master fixture/cloudemu/EMULATOR-22 >/dev/null
# Publishing a ticket changes its upstream from master to its own origin branch.
# Destructive removal must still discard tracked, untracked and ignored residue.
run_prepare EMULATOR-24
published_branch=fixture/cloudemu/EMULATOR-24
published_worktree="$root/EMULATOR-24/cloudemu"
git -C "$bare" config --add remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
git -C "$published_worktree" push -qu origin "$published_branch"
[[ $(git -C "$published_worktree" rev-parse --symbolic-full-name '@{upstream}') == "refs/remotes/origin/$published_branch" ]] || fail 'fixture does not track published ticket'
printf 'modified\n' >>"$published_worktree/README"
mkdir -p "$published_worktree/untracked/nested" "$published_worktree/build"
printf 'untracked\n' >"$published_worktree/untracked/nested/artifact"
printf 'build/\n' >"$published_worktree/.gitignore"
printf 'ignored\n' >"$published_worktree/build/artifact"
emulator_worktree_remove "$root" fixture EMULATOR-24 >"$TEST_ROOT/output" 2>&1 || fail "published dirty ticket removal: $(<"$TEST_ROOT/output")"
[[ ! -e $published_worktree ]] || fail 'published worktree residue not removed'
if git -C "$bare" show-ref --verify --quiet "refs/heads/$published_branch"; then fail 'published local ticket branch not removed'; fi
git -C "$TEST_ROOT/remote" show-ref --verify --quiet "refs/heads/$published_branch" || fail 'cleanup deleted published remote branch'
# Tracking another ticket must still fail before removing files.
git -C "$bare" branch -u "origin/$published_branch" fixture/cloudemu/EMULATOR-22 >/dev/null
if emulator_worktree_remove "$root" fixture EMULATOR-22 >"$TEST_ROOT/output" 2>&1; then fail 'removed branch tracking another ticket'; fi
[[ -f $root/EMULATOR-22/cloudemu/.git ]] || fail 'removed worktree tracking another ticket'
git -C "$bare" branch -u origin/master fixture/cloudemu/EMULATOR-22 >/dev/null
# Removal uses the same identity guards; force is owned by the sandbox action.
declare -F emulator_worktree_remove >/dev/null || fail 'cloudemu removal helper is missing'
emulator_worktree_remove "$root" fixture EMULATOR-10
[[ ! -e $worktree ]] || fail 'registered worktree not removed'
if git -C "$bare" show-ref --verify --quiet refs/heads/fixture/cloudemu/EMULATOR-10; then fail 'ticket branch not removed'; fi
# Retrying an already completed removal must be harmless.
emulator_worktree_remove "$root" fixture EMULATOR-10
# An orphaned ticket branch may be cleaned, but never one checked out elsewhere.
git -C "$bare" branch -q --track fixture/cloudemu/EMULATOR-30 refs/remotes/origin/master
emulator_worktree_remove "$root" fixture EMULATOR-30
if git -C "$bare" show-ref --verify --quiet refs/heads/fixture/cloudemu/EMULATOR-30; then fail 'orphaned branch not removed'; fi
git -C "$bare" worktree add -q --track -b fixture/cloudemu/EMULATOR-31 "$TEST_ROOT/elsewhere" refs/remotes/origin/master
if emulator_worktree_remove "$root" fixture EMULATOR-31 >"$TEST_ROOT/output" 2>&1; then fail 'removed branch checked out elsewhere'; fi
[[ -f $TEST_ROOT/elsewhere/.git ]] || fail 'changed worktree outside ticket root'
for ticket in EMULATOR-12 EMULATOR-13 EMULATOR-14 EMULATOR-15 EMULATOR-16; do
  if emulator_worktree_remove "$root" fixture "$ticket" >"$TEST_ROOT/output" 2>&1; then fail "unsafe removal accepted for $ticket"; fi
done
[[ -f $root/EMULATOR-13/cloudemu/sentinel ]] || fail 'cleanup removed unrelated data'
printf 'PASS: cloudemu clone, refs, reuse, retry, identity and removal guards\n'
