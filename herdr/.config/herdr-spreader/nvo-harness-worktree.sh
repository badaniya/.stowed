#!/usr/bin/env bash
# nvo-harness-worktree — like nvo-worktree.sh, but sets up a multi-repo
# "harness" style workspace: one top-level <JIRA#> project directory with a
# git worktree for each of GoDCApp, PlatformCommonModels, PlatformServices,
# and PlatformServicesCommon, all on the same upstream version, mirroring the
# layout of ~/workspace/<owner>/Extreme-AI-Harness.
#
# Usage:
#   nvo-harness-worktree.sh '<jira> <upstream-version> [--restore-harness]'
#   nvo-harness-worktree.sh NVO-15650 25.16.0 --restore-harness
#
# What it does, for each of the four repos:
#   1. git worktree add off the shared bare repo at
#      ~/workspace/<owner>/master/<repo>, based on <upstream-version>
#   2. New worktree lands at ~/workspace/<owner>/<jira>/<repo> on a new
#      branch named <owner>/<repo>/<jira>, tracking origin/<upstream-version>
# Then:
#   3. If --restore-harness is passed (or HARNESS_SNAPSHOT is set to a real
#      path), restores the AI Harness into the new workspace from the local
#      snapshot (~/harness-snapshots/<version>/ or ~/harness-snapshots/latest.tar.gz).
#      A version worktree does NOT carry the harness — the install lives on the
#      harness/setup branches, and the parent-root artifacts are in no repo at
#      all — so without this step every new workspace starts with no CLAUDE.md,
#      no invariants, and no agents. Without the flag, the restore is skipped
#      entirely (the common case — most worktrees are not harness work).
#      Override the resolved snapshot with HARNESS_SNAPSHOT=<path>; force a
#      skip even with the flag set via HARNESS_SNAPSHOT=none.
#   4. Looks up the Jira ticket title (falls back to "NVO Workspace")
#   5. Renders the herdr-spreader template (root = ~/workspace/<owner>/<jira>)
#      and applies it

set -euo pipefail

REPOS=(GoDCApp PlatformCommonModels PlatformServices PlatformServicesCommon)
CONTEXT_DIRS=(.agents .claude)
CONTEXT_MARKER=.herdr-aggregate-context

has_non_directory_ancestor() {
	local root=$1 path=$2

	while [[ $path != "$root" ]]; do
		if [[ -L $path || (-e $path && ! -d $path) ]]; then
			return 0
		fi
		path=$(dirname "$path")
	done
	return 1
}

build_context_tree() {
	local project_dir=$1 context_dir=$2 destination=$3 repo source relative target destination_path

	mkdir -p "$destination"
	: >"$destination/$CONTEXT_MARKER"

	for repo in "${REPOS[@]}"; do
		source="$project_dir/$repo/$context_dir"
		[[ -d $source ]] || continue

		# Keep directories physical so entries from multiple repositories can merge.
		while IFS= read -r -d '' target; do
			relative=${target#"$source/"}
			destination_path="$destination/$relative"
			[[ -e $destination_path || -L $destination_path ]] && continue
			has_non_directory_ancestor "$destination" "$(dirname "$destination_path")" && continue
			mkdir -p "$destination_path"
		done < <(find "$source" -mindepth 1 -type d -print0)

		# The first repository that provides a leaf owns that path.
		while IFS= read -r -d '' target; do
			relative=${target#"$source/"}
			[[ $relative == "$CONTEXT_MARKER" ]] && continue
			destination_path="$destination/$relative"
			[[ -e $destination_path || -L $destination_path ]] && continue
			has_non_directory_ancestor "$destination" "$(dirname "$destination_path")" && continue
			mkdir -p "$(dirname "$destination_path")"
			ln -s "$target" "$destination_path"
		done < <(find "$source" -mindepth 1 \( -type f -o -type l \) -print0)
	done
}

aggregate_context_trees() {
	local project_dir=$1 context_dir root parent temp

	for context_dir in "${CONTEXT_DIRS[@]}"; do
		root="$project_dir/$context_dir"
		parent=$(dirname "$root")

		if [[ -e $root || -L $root ]]; then
			[[ ! -L $root && -d $root && -f $root/$CONTEXT_MARKER ]] ||
				{
					printf 'Error: refusing to replace unmanaged aggregate root: %s\n' "$root" >&2
					return 1
				}
		fi

		temp=$(mktemp -d "$parent/.${context_dir#.}.tmp.XXXXXX")
		build_context_tree "$project_dir" "$context_dir" "$temp"
		rm -rf "$root"
		mv "$temp" "$root"
	done
}

# Snapshots live under ~/harness-snapshots/<version>/, keyed by the NVO version
# branch they were captured against. Resolution happens after UPSTREAM_VERSION
# is known (see "Resolve the harness snapshot" below), and only when the
# restore is requested at all (see RESTORE_HARNESS below). Set HARNESS_SNAPSHOT
# to pin an explicit file (which also implies the restore is wanted), or to
# 'none' to force-skip regardless of --restore-harness.
HARNESS_SNAPSHOT="${HARNESS_SNAPSHOT:-}"
HARNESS_SNAPSHOT_DIR="${HOME}/harness-snapshots"

if [[ $# -lt 1 ]]; then
	echo "Usage: nvo-harness-worktree.sh <jira> <upstream-version> [--restore-harness]" >&2
	exit 1
fi

# The herdr-plus form passes everything as a single quoted string; support
# that, two-or-more separate positional args, and --restore-harness appearing
# anywhere among them.
if [[ $# -ge 2 ]]; then
	RAW_ARGS=("$@")
else
	read -r -a RAW_ARGS <<<"${1}"
fi

RESTORE_HARNESS=0
POSITIONAL=()
for ARG in "${RAW_ARGS[@]}"; do
	case "${ARG}" in
	--restore-harness) RESTORE_HARNESS=1 ;;
	*) POSITIONAL+=("${ARG}") ;;
	esac
done

JIRA="${POSITIONAL[0]:-}"
UPSTREAM_VERSION="${POSITIONAL[1]:-}"

if [[ -z "${JIRA:-}" || -z "${UPSTREAM_VERSION:-}" ]]; then
	echo "Usage: nvo-harness-worktree.sh <jira> <upstream-version> [--restore-harness]" >&2
	echo "  e.g. nvo-harness-worktree.sh NVO-15650 25.16.0 --restore-harness" >&2
	exit 1
fi

# An explicit HARNESS_SNAPSHOT override (anything but 'none') is itself a
# request to restore, even without the flag.
if [[ -n "${HARNESS_SNAPSHOT}" && "${HARNESS_SNAPSHOT}" != "none" ]]; then
	RESTORE_HARNESS=1
fi

# ── Paths ────────────────────────────────────────────────────────────────────
WORKSPACE_OWNER=${NVO_WORKSPACE_OWNER:-${USER:?}}
WORKSPACE_ROOT=${NVO_WORKSPACE_ROOT:-"${HOME}/workspace/${WORKSPACE_OWNER}"}
PROJECT_DIR="${WORKSPACE_ROOT}/${JIRA}"
TEMPLATE="${HOME}/.stowed/herdr/.config/herdr/plugins/config/herdr-spreader/nvo-harness-worktree.yaml.tpl"
TMP_CONFIG="/tmp/nvo-harness-worktree-${JIRA//\//-}.yaml"

mkdir -p "${PROJECT_DIR}"

for REPO in "${REPOS[@]}"; do
	BARE_REPO="${WORKSPACE_ROOT}/master/${REPO}"
	WORKTREE_DIR="${PROJECT_DIR}/${REPO}"
	NEW_BRANCH="${WORKSPACE_OWNER}/${REPO}/${JIRA}"

	if [[ ! -d "${BARE_REPO}" ]]; then
		echo "Error: bare repo not found at ${BARE_REPO}" >&2
		exit 1
	fi

	if [[ -d "${WORKTREE_DIR}" ]]; then
		echo "→ Worktree already exists at ${WORKTREE_DIR}, reusing it…"
		continue
	fi

	echo "→ Fetching ${BARE_REPO}…"
	git -C "${BARE_REPO}" fetch --all --quiet

	echo "→ Creating worktree for '${NEW_BRANCH}' (from '${UPSTREAM_VERSION}') at ${WORKTREE_DIR}…"
	git -C "${BARE_REPO}" worktree add "${WORKTREE_DIR}" -b "${NEW_BRANCH}" "${UPSTREAM_VERSION}"

	# Track the upstream version branch for diff/log purposes (best-effort — not
	# a push target, just so `git status`/`git log` compare against it).
	git -C "${WORKTREE_DIR}" branch --set-upstream-to="origin/${UPSTREAM_VERSION}" "${NEW_BRANCH}" 2>/dev/null || true
done

aggregate_context_trees "$PROJECT_DIR"
echo "→ Created aggregate .agents and .claude context trees."

# ── Restore the harness only when asked ─────────────────────────────────────
# Most worktrees are ordinary version work, not harness work, so the restore is
# opt-in: pass --restore-harness (or set HARNESS_SNAPSHOT to a real path) to
# get it. Without that, skip straight to the Jira/workspace steps.
if [[ "${RESTORE_HARNESS}" -ne 1 ]]; then
	echo "→ Skipping harness restore (pass --restore-harness to enable it)."
fi

# ── Resolve the harness snapshot for this version ───────────────────────────
# Snapshots are keyed by the NVO version branch they were captured against. A
# snapshot restored onto a different version gives correct harness structure but
# service cards whose measured facts — file counts, line numbers, CI builds, test
# baselines — describe different code. That reads as authoritative and is wrong,
# so a mismatch warns loudly rather than passing silently.
if [[ "${RESTORE_HARNESS}" -eq 1 && -z "${HARNESS_SNAPSHOT}" ]]; then
	VERSION_DIR="${HARNESS_SNAPSHOT_DIR}/${UPSTREAM_VERSION}"
	# newest tarball in the matching version directory
	# shellcheck disable=SC2012 # Timestamp ordering is intentional for this glob.
	HARNESS_SNAPSHOT=$(ls -t "${VERSION_DIR}"/*.tar.gz 2>/dev/null | head -1 || true)

	if [[ -n "${HARNESS_SNAPSHOT}" ]]; then
		echo "→ Harness snapshot for ${UPSTREAM_VERSION}: $(basename "${HARNESS_SNAPSHOT}")"
	elif [[ -e "${HARNESS_SNAPSHOT_DIR}/latest.tar.gz" ]]; then
		FALLBACK_VER=$(basename "$(dirname "$(readlink -f "${HARNESS_SNAPSHOT_DIR}/latest.tar.gz")")")
		echo "" >&2
		echo "  ⚠  NO HARNESS SNAPSHOT FOR ${UPSTREAM_VERSION}" >&2
		echo "     Falling back to latest.tar.gz, captured against ${FALLBACK_VER}." >&2
		echo "     Harness structure (agents, skills, contract) will be correct." >&2
		echo "     Service CLAUDE.md and invariants.md will cite file counts, line" >&2
		echo "     numbers and CI baselines measured against ${FALLBACK_VER} — treat" >&2
		echo "     every measured fact in them as unverified on ${UPSTREAM_VERSION}." >&2
		echo "     The install proceeds anyway; the workspace will be flagged so the" >&2
		echo "     first agent session runs harness-update before trusting the cards." >&2
		echo "" >&2
		HARNESS_SNAPSHOT="${HARNESS_SNAPSHOT_DIR}/latest.tar.gz"
		HARNESS_VERSION_MISMATCH="${FALLBACK_VER}"
	fi
fi

# ── Restore the AI Harness into the new workspace ───────────────────────────
# A fresh version worktree has no harness. The restore is inlined here rather
# than shelled out, so this script works on any machine that has a snapshot —
# no companion script to install, keep executable, or keep in sync.
#
# Clean target  -> extract straight in.
# Harness found -> do NOT overwrite; extract to scratch and report the diff, so
#                  re-running this script against a live workspace is harmless.
if [[ "${RESTORE_HARNESS}" -ne 1 ]]; then
	: # already reported above; nothing to do
elif [[ "${HARNESS_SNAPSHOT}" == "none" ]]; then
	echo "→ Skipping harness restore (HARNESS_SNAPSHOT=none)."
elif [[ ! -f "${HARNESS_SNAPSHOT}" ]]; then
	echo "Warning: harness snapshot not found at ${HARNESS_SNAPSHOT}" >&2
	echo "         Workspace will have NO harness context files." >&2
	echo "         Set HARNESS_SNAPSHOT=<path>, or drop a snapshot into" >&2
	echo "         ${HARNESS_SNAPSHOT_DIR}/${UPSTREAM_VERSION}/ and re-run." >&2
else
	# Any one of these at the workspace root means a harness is already installed.
	HARNESS_MARKERS=(CLAUDE.md HARNESS.md behavioral-contract.md new-feature-harness-profile.yaml)
	HARNESS_FOUND=()
	for m in "${HARNESS_MARKERS[@]}"; do
		[[ -e "${PROJECT_DIR}/${m}" ]] && HARNESS_FOUND+=("${m}")
	done

	if [[ ${#HARNESS_FOUND[@]} -gt 0 ]]; then
		echo "→ Harness already present at ${PROJECT_DIR} (found: ${HARNESS_FOUND[*]})."
		echo "  Not overwriting. Diffing the snapshot against it instead."
		SCRATCH=$(mktemp -d)
		tar -xzf "${HARNESS_SNAPSHOT}" -C "${SCRATCH}"
		SAME=0
		DIFFER=0
		ONLY=0
		while IFS= read -r f; do
			if [[ ! -e "${PROJECT_DIR}/${f}" ]]; then
				ONLY=$((ONLY + 1))
				echo "   ONLY-IN-SNAPSHOT  ${f}"
			elif cmp -s "${SCRATCH}/${f}" "${PROJECT_DIR}/${f}"; then
				SAME=$((SAME + 1))
			else
				DIFFER=$((DIFFER + 1))
				echo "   DIFFERS           ${f}"
			fi
		done < <(cd "${SCRATCH}" && find . -type f | sed 's|^\./||' | sort)
		echo "   identical: ${SAME}   differs: ${DIFFER}   only-in-snapshot: ${ONLY}"
		echo "   Scratch copy: ${SCRATCH}"
		HARNESS_RESTORED=no
	else
		echo "→ Restoring AI Harness from $(readlink -f "${HARNESS_SNAPSHOT}")…"
		tar -xzf "${HARNESS_SNAPSHOT}" -C "${PROJECT_DIR}"
		echo "   Restored $(tar -tzf "${HARNESS_SNAPSHOT}" | rg -vc '/$') files."
		HARNESS_RESTORED=yes
	fi
fi

if [[ "${HARNESS_RESTORED:-no}" == "yes" ]]; then

	# The restore writes over a handful of files that the version branch tracks.
	# Three are .gitignore (harness appends a block); NVO/Orchestration/CLAUDE.md
	# is a real replacement of the repo's own card. Surface them rather than
	# letting them turn up later as mystery modifications.
	for REPO in "${REPOS[@]}"; do
		CHANGED=$(git -C "${PROJECT_DIR}/${REPO}" status --porcelain -- . 2>/dev/null |
			rg -E '^ ?M' | awk '{print $2}' || true)
		if [[ -n "${CHANGED}" ]]; then
			echo "   ${REPO}: harness overwrote these tracked files —"
			while IFS= read -r changed_file; do
				printf '     %s\n' "$changed_file"
			done <<<"$CHANGED"
		fi
	done

	echo "   Reminder: copy .claude/settings.local.json.example → .claude/settings.local.json"
	echo "   in each repo and add your ingest token (excluded from the snapshot on purpose)."

	# ── Flag a version mismatch so the first agent session cannot miss it ──────
	# The restore succeeded, but the cards were measured against a different
	# version. A warning printed at workspace-creation time scrolls away and the
	# agent never sees it, so the signal goes into two places the agent DOES read:
	# a marker file, and the parent CLAUDE.md, which auto-loads every session.
	if [[ -n "${HARNESS_VERSION_MISMATCH:-}" ]]; then
		cat >"${PROJECT_DIR}/.harness-version-mismatch" <<MARKER
snapshot_version: ${HARNESS_VERSION_MISMATCH}
workspace_version: ${UPSTREAM_VERSION}
restored_from: $(readlink -f "${HARNESS_SNAPSHOT}")
restored_at: $(date -Iseconds)
action_required: run harness-update
MARKER

		BANNER="${PROJECT_DIR}/.harness-mismatch-banner.md"
		cat >"${BANNER}" <<BANNEREOF

---

> [!IMPORTANT]
> ## ⚠ Harness is stale for this workspace — run \`harness-update\` before trusting any service card
>
> This workspace is on **${UPSTREAM_VERSION}**. The harness restored into it was captured
> against **${HARNESS_VERSION_MISMATCH}**.
>
> **What is still correct:** the agent definitions, skills, behavioral contract, pipeline and
> gates. Harness structure does not depend on the product version.
>
> **What is NOT correct:** every *measured* fact in a service \`CLAUDE.md\` or \`invariants.md\` —
> file counts, line numbers, CI job and build numbers, test baselines, import-site counts,
> pinned module versions. Those were measured on ${HARNESS_VERSION_MISMATCH} and this is
> ${UPSTREAM_VERSION}. They read as authoritative and are not.
>
> **Do this first, before any other work:** invoke the \`harness-update\` skill. It re-measures
> the cards against this workspace's actual code.
>
> Until that is done: do not cite a line number, file count or CI baseline from a service card
> without re-checking it against the code in front of you. Treat the cards as orientation, not
> as evidence.
>
> Details: \`.harness-version-mismatch\` at this workspace root.
> Remove this banner and that file once \`harness-update\` has run.

---
BANNEREOF

		# Insert immediately after the first heading of the parent CLAUDE.md so it
		# is the first thing read, not buried at the bottom.
		if [[ -f "${PROJECT_DIR}/CLAUDE.md" ]]; then
			awk -v bf="${BANNER}" '
        NR==1 && /^# / { print; while ((getline line < bf) > 0) print line; next }
        { print }
      ' "${PROJECT_DIR}/CLAUDE.md" >"${PROJECT_DIR}/CLAUDE.md.tmp" &&
				mv "${PROJECT_DIR}/CLAUDE.md.tmp" "${PROJECT_DIR}/CLAUDE.md"
			echo "   ⚠  Flagged version mismatch in CLAUDE.md — first session must run harness-update."
		fi
		rm -f "${BANNER}"
	fi
fi

# ── Jira title lookup (best-effort) ─────────────────────────────────────────
TICKET=$(printf '%s\n' "$JIRA" | rg -o '([A-Z]+-[0-9]+)' | head -1 || true)
JIRA_TITLE=""
if [[ -n "${TICKET}" ]]; then
	JIRA_TITLE=$(jira issue view "${TICKET}" --raw 2>/dev/null | jq -r '.fields.summary // empty' 2>/dev/null || true)
fi

export WORKSPACE_NAME
if [[ -n "${JIRA_TITLE}" ]]; then
	# Escape double quotes so the rendered YAML value stays well-formed.
	WORKSPACE_NAME="${JIRA} - ${JIRA_TITLE//\"/\\\"}"
else
	echo "Warning: could not look up a Jira title for '${TICKET:-$JIRA}', using generic workspace name" >&2
	WORKSPACE_NAME="${JIRA} - NVO Workspace"
fi

export PROJECT_DIR

# ── Render the template and apply the layout ────────────────────────────────
# Sandbox callers own workspace construction because their Build tab may only
# open after the guest bootstrap and private-template lifecycle both complete.
if [[ ${NVO_HARNESS_DEFER_WORKSPACE:-false} == true ]]; then
	echo "→ Workspace rendering deferred to sandbox lifecycle."
	exit 0
fi

echo "→ Rendering workspace config to ${TMP_CONFIG}…"
# shellcheck disable=SC2016 # envsubst receives literal variable references.
envsubst '${WORKSPACE_NAME} ${PROJECT_DIR}' <"${TEMPLATE}" >"${TMP_CONFIG}"

echo "→ Launching herdr workspace '${WORKSPACE_NAME}'…"
herdr-spreader apply --file "${TMP_CONFIG}"
