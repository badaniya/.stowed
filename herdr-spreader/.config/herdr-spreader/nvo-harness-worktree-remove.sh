#!/usr/bin/env bash
# nvo-harness-worktree-remove — undo nvo-harness-worktree.sh: closes the
# matching herdr workspace(s) and removes the git worktree + local branch for
# each of GoDCApp, PlatformCommonModels, PlatformServices,
# PlatformServicesCommon under ~/workspace/badaniya/<jira>, then removes the
# now-empty project directory.
#
# Usage:
#   nvo-harness-worktree-remove.sh '<jira>'
#   nvo-harness-worktree-remove.sh 'NVO-15650'
#   nvo-harness-worktree-remove.sh 'NVO-15650 --force'   # skip clean checks
#
# Safety: refuses to remove a worktree that has uncommitted changes, or a
# branch that has commits not present on its upstream, unless --force is
# passed. --force still requires each repo's worktree to actually exist.

set -euo pipefail

REPOS=(GoDCApp PlatformCommonModels PlatformServices PlatformServicesCommon)

if [[ $# -lt 1 ]]; then
  echo "Usage: nvo-harness-worktree-remove.sh <jira> [--force]" >&2
  exit 1
fi

# The herdr-plus form passes everything as a single quoted string; support
# both that and separate positional args.
FORCE=0
if [[ $# -ge 2 ]]; then
  JIRA="${1}"
  [[ "${2:-}" == "--force" ]] && FORCE=1
else
  read -r JIRA REST <<<"${1}"
  [[ "${REST:-}" == "--force" ]] && FORCE=1
fi

if [[ -z "${JIRA:-}" ]]; then
  echo "Usage: nvo-harness-worktree-remove.sh <jira> [--force]" >&2
  exit 1
fi

PROJECT_DIR="${HOME}/workspace/badaniya/${JIRA}"

if [[ ! -d "${PROJECT_DIR}" ]]; then
  echo "Error: no project directory at ${PROJECT_DIR}" >&2
  exit 1
fi

# ── The harness's own footprint ─────────────────────────────────────────────
# nvo-harness-worktree.sh restores the AI Harness into every workspace, which
# leaves each repo permanently dirty: ~40 untracked context files plus a few
# tracked ones the harness overwrites (.gitignore blocks, Orchestration's card).
# None of that is the developer's work. Without this, the uncommitted-changes
# guard below can NEVER pass, and --force becomes the only way to remove a
# workspace — which also skips the unpushed-commits check, the one that
# actually protects something. So: subtract the snapshot's paths, then judge
# what is left.
#
# Two sources, because neither alone is sufficient:
#   1. The union of every snapshot's paths — exact, but frozen at capture time.
#   2. A pattern allowlist — covers what a later `harness-update` installs that
#      no snapshot has seen. This is not hypothetical: harness-update adds
#      .claude/hooks/*, .claude/settings.json and a .gitignore block at each
#      REPO ROOT, none of which appear in the 2026-09-15 snapshot.
# Anything matching either is the harness's, not the developer's.
HARNESS_PATHS=$(mktemp)
trap 'rm -f "${HARNESS_PATHS}"' EXIT
for SNAP in "${HOME}"/harness-snapshots/*/*.tar.gz; do
  [[ -f "${SNAP}" ]] || continue
  tar -tzf "${SNAP}" 2>/dev/null | sed 's|^\./||' | grep -v '/$'
done | sort -u > "${HARNESS_PATHS}"

# Paths the harness owns by shape. Deliberately excludes anything under src/,
# so product code can never be waved through.
harness_owned() {
  local p="$1"
  case "${p}" in
    .claude/*|*/.claude/*)                                   return 0 ;;  # agents, skills, hooks, settings
    behavioral-contract.md|*/behavioral-contract.md)         return 0 ;;
    invariants.md|*/invariants.md)                           return 0 ;;
    CLAUDE.md|*/CLAUDE.md)                                   return 0 ;;
    HARNESS.md|*/HARNESS.md)                                 return 0 ;;
    .gitignore|*/.gitignore)                                 return 0 ;;  # harness appends a block
    features/_harness/*|harness_templates/*|shared-contracts/*) return 0 ;;
    .harness-*|*/.harness-*)                                 return 0 ;;  # cache, output, staging, markers
    new-feature-harness-profile.yaml*)                       return 0 ;;
    backlog.md)                                              return 0 ;;
  esac
  return 1
}

# ── Safety checks (skipped entirely if --force) ─────────────────────────────
if [[ "${FORCE}" -ne 1 ]]; then
  for REPO in "${REPOS[@]}"; do
    WORKTREE_DIR="${PROJECT_DIR}/${REPO}"
    [[ -d "${WORKTREE_DIR}" ]] || continue

    # Dirty paths, expanded: a status line for an untracked DIRECTORY ends in
    # '/' and stands for every file under it, so compare file-by-file or a
    # harness-only directory looks like unknown work.
    DIRTY=$(git -C "${WORKTREE_DIR}" status --porcelain -uall 2>/dev/null \
              | sed 's/^...//' | sed 's/^"\(.*\)"$/\1/' | sort -u)

    NON_HARNESS=""
    if [[ -n "${DIRTY}" ]]; then
      while IFS= read -r p; do
        [[ -z "${p}" ]] && continue
        # Snapshot paths are workspace-relative (e.g. GoDCApp/NVO/...), status
        # paths are repo-relative — prefix before comparing.
        grep -qxF "${REPO}/${p}" "${HARNESS_PATHS}" && continue
        harness_owned "${p}" && continue
        NON_HARNESS+="${p}"$'\n'
      done <<< "${DIRTY}"
    fi

    HARNESS_COUNT=$(( $(echo "${DIRTY}" | grep -c . || true) - $(echo "${NON_HARNESS}" | grep -c . || true) ))

    if [[ -n "${NON_HARNESS//[[:space:]]/}" ]]; then
      echo "Error: ${WORKTREE_DIR} has uncommitted changes that are NOT the harness install." >&2
      echo "${NON_HARNESS}" | grep . | head -20 | sed 's|^|         |' >&2
      [[ "${HARNESS_COUNT}" -gt 0 ]] && \
        echo "       (${HARNESS_COUNT} further dirty path(s) are harness files and were ignored)" >&2
      echo "       Commit/stash, or re-run with --force to discard." >&2
      exit 1
    fi

    [[ "${HARNESS_COUNT}" -gt 0 ]] && \
      echo "→ ${REPO}: ${HARNESS_COUNT} dirty path(s), all harness install — ignoring."

    UPSTREAM=$(git -C "${WORKTREE_DIR}" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
    if [[ -n "${UPSTREAM}" ]]; then
      AHEAD=$(git -C "${WORKTREE_DIR}" rev-list --count "${UPSTREAM}..HEAD" 2>/dev/null || echo 0)
      if [[ "${AHEAD}" -gt 0 ]]; then
        echo "Error: ${WORKTREE_DIR} has ${AHEAD} commit(s) not on ${UPSTREAM}. Push them, or re-run with --force to discard." >&2
        exit 1
      fi
    fi
  done
fi

# Look up the matching herdr workspace(s) now (by label prefix "<jira> ", as
# rendered by nvo-harness-worktree.sh: "<jira> - <jira title>", or an exact
# label of just "<jira>"), but close them LAST — if this script is itself
# running inside a pane of that workspace, closing it early would kill this
# script before it finishes removing the worktrees.
WORKSPACE_IDS=$(herdr workspace list 2>/dev/null | python3 -c "
import json, sys
jira = sys.argv[1]
data = json.load(sys.stdin)
for w in data['result']['workspaces']:
    label = w['label']
    if label == jira or label.startswith(jira + ' '):
        print(w['workspace_id'])
" "${JIRA}" || true)

# ── Remove worktrees and local branches ─────────────────────────────────────
for REPO in "${REPOS[@]}"; do
  BARE_REPO="${HOME}/workspace/badaniya/master/${REPO}"
  WORKTREE_DIR="${PROJECT_DIR}/${REPO}"
  BRANCH="badaniya/${REPO}/${JIRA}"

  if [[ ! -d "${WORKTREE_DIR}" ]]; then
    echo "→ No worktree at ${WORKTREE_DIR}, skipping"
    continue
  fi

  echo "→ Removing worktree ${WORKTREE_DIR}…"
  git -C "${BARE_REPO}" worktree remove --force "${WORKTREE_DIR}"

  if git -C "${BARE_REPO}" show-ref --verify --quiet "refs/heads/${BRANCH}"; then
    echo "→ Deleting local branch ${BRANCH}…"
    git -C "${BARE_REPO}" branch -D "${BRANCH}"
  fi
done

# ── Sweep the harness's project-root footprint ──────────────────────────────
# nvo-harness-worktree.sh restores the harness into PROJECT_DIR itself, not
# just into the four repos: CLAUDE.md, HARNESS.md, .claude/, docs/, features/,
# harness_templates/, shared-contracts/, backlog.md, and the rest of the
# ~19-entry root footprint live outside every git repo (PROJECT_DIR is not a
# git repo). The safety checks above only run `git status` inside each REPO
# worktree, so none of this is ever seen there, and the empty-dir check below
# would never fire for a harness-restored workspace without removing it here
# first. Same two sources as the per-repo check: the union of every
# snapshot's top-level entries, plus the harness_owned() pattern allowlist for
# files a snapshot never saw (e.g. .harness-version-mismatch).
ROOT_HARNESS_TOPLEVEL=$(cut -d/ -f1 "${HARNESS_PATHS}" | sort -u)
shopt -s dotglob nullglob
for ENTRY in "${PROJECT_DIR}"/*; do
  NAME=$(basename "${ENTRY}")
  # never touch a repo worktree/directory — that's the loop above's job
  case " ${REPOS[*]} " in *" ${NAME} "*) continue ;; esac
  if harness_owned "${NAME}" || grep -qxF "${NAME}" <<<"${ROOT_HARNESS_TOPLEVEL}"; then
    echo "→ Removing harness artifact ${ENTRY}"
    find "${ENTRY}" -depth -delete
  fi
done
shopt -u dotglob nullglob

# ── Remove project directory if now empty ───────────────────────────────────
if [[ -d "${PROJECT_DIR}" ]] && [[ -z "$(ls -A "${PROJECT_DIR}")" ]]; then
  rmdir "${PROJECT_DIR}"
  echo "→ Removed empty project directory ${PROJECT_DIR}"
else
  echo "Note: ${PROJECT_DIR} left in place (not empty)"
fi

# ── Close matching herdr workspace(s) last ──────────────────────────────────
if [[ -n "${WORKSPACE_IDS}" ]]; then
  while IFS= read -r WID; do
    [[ -z "${WID}" ]] && continue
    echo "→ Closing herdr workspace ${WID}…"
    herdr workspace close "${WID}" >/dev/null
  done <<<"${WORKSPACE_IDS}"
else
  echo "Warning: no open herdr workspace found for '${JIRA}', skipping close" >&2
fi

echo "Done."
