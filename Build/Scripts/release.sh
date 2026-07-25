#!/usr/bin/env bash

#
# release.sh — orchestrate the two-phase GitHub release of this extension.
#
# Given a single release version (e.g. 1.2.0) this drives the full workflow:
#
#   PHASE 1 (release)
#     - branch release-X.Y.Z off the source branch
#     - Build/Scripts/setVersion.sh X.Y.Z release
#     - commit "[RELEASE] X.Y.Z", push, open pull request, wait for the checks,
#       admin-merge
#     - refresh the source branch, tag X.Y.Z, push the tag
#
#   PHASE 2 (post-release, next patch W = Z+1)
#     - branch set-version-X.Y.W off the merged source branch
#     - Build/Scripts/setVersion.sh X.Y.W post-release
#     - commit "[TASK] Set version X.Y.W", push, open pull request, checks,
#       admin-merge
#
# The version-applying work is delegated to Build/Scripts/setVersion.sh; this
# script owns only the git and GitHub (gh) operations.
#
# Safety model (two independent gates):
#   --dry-run   Print EVERYTHING, touch nothing (local and remote alike).
#   --execute   Actually perform the remote/irreversible operations (git push,
#               gh pr create/checks/merge, git tag + tag push). WITHOUT
#               --execute the local branch/commit/setVersion steps run for real
#               but every remote/irreversible operation is only PRINTED. So a
#               bare run can never mutate the remote or create tags.
#
# Usage:
#   Build/Scripts/release.sh <release-version> [options]
#
#   <release-version>        MAJOR.MINOR.PATCH, e.g. 1.2.0
#
# Options:
#   --source-branch=<name>   base/source branch (default: main)
#   --dry-run                print the whole plan, change nothing
#   --execute                enable remote/irreversible operations
#   -h, --help               show this help
#

set -euo pipefail

# ---------------------------------------------------------------------------
# Always operate from the repository root. This script lives in
# <root>/Build/Scripts, so the repository root is two directories up.
# ---------------------------------------------------------------------------
THIS_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
ROOT_DIR="$(cd -- "${THIS_SCRIPT_DIR}/../.." >/dev/null && pwd)"
cd "${ROOT_DIR}"

SET_VERSION_BIN="${THIS_SCRIPT_DIR}/setVersion.sh"

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
DRY_RUN=0
EXECUTE=0

info() { printf '\n>> %s\n' "$*"; }
note() { printf '   %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
    sed -n '3,42p' "${BASH_SOURCE[0]}" | sed 's/^#\{0,1\} \{0,1\}//'
}

# Local, reversible operations: executed unless --dry-run.
run() {
    if [ "${DRY_RUN}" -eq 1 ]; then
        printf '   [dry-run]  %s\n' "$*"
        return 0
    fi
    printf '   [run]      %s\n' "$*"
    "$@"
}

# Remote / irreversible operations: executed ONLY with --execute (and not
# --dry-run). Otherwise merely printed. This is the hard guardrail.
run_remote() {
    if [ "${DRY_RUN}" -eq 1 ]; then
        printf '   [dry-run]  %s\n' "$*"
        return 0
    fi
    if [ "${EXECUTE}" -eq 0 ]; then
        printf '   [skipped]  (needs --execute) %s\n' "$*"
        return 0
    fi
    printf '   [remote]   %s\n' "$*"
    "$@"
}

# Invoke Build/Scripts/setVersion.sh, forwarding --dry-run when appropriate.
run_set_version() {
    local version="$1" type="$2"
    local -a cmd=("${SET_VERSION_BIN}" "${version}" "${type}" "--source-branch=${SOURCE_BRANCH}")
    if [ "${DRY_RUN}" -eq 1 ]; then
        cmd+=("--dry-run")
        printf '   [dry-run]  %s\n' "${cmd[*]}"
        "${cmd[@]}"
        return 0
    fi
    printf '   [run]      %s\n' "${cmd[*]}"
    "${cmd[@]}"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
PASSED_VERSION=""
SOURCE_BRANCH="main"

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)          DRY_RUN=1 ;;
        --execute)          EXECUTE=1 ;;
        --source-branch=*)  SOURCE_BRANCH="${1#*=}" ;;
        --source-branch)    shift; SOURCE_BRANCH="${1:-}" ;;
        -h|--help)          usage; exit 0 ;;
        -*)                 die "Unknown option: $1 (see --help)" ;;
        *)
            if [ -n "${PASSED_VERSION}" ]; then
                die "Unexpected extra argument: $1 (see --help)"
            fi
            PASSED_VERSION="$1"
            ;;
    esac
    shift
done

if [ -z "${PASSED_VERSION}" ]; then
    die "Missing <release-version> argument (see --help)"
fi

if [ "${DRY_RUN}" -eq 1 ] && [ "${EXECUTE}" -eq 1 ]; then
    die "--dry-run and --execute are mutually exclusive."
fi

# ---------------------------------------------------------------------------
# Validate the version and derive the next dev (post-release) version.
# ---------------------------------------------------------------------------
if ! [[ "${PASSED_VERSION}" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    die "Invalid version '${PASSED_VERSION}': expected MAJOR.MINOR.PATCH (e.g. 1.2.0)"
fi
MAJOR="${BASH_REMATCH[1]}"
MINOR="${BASH_REMATCH[2]}"
PATCH="${BASH_REMATCH[3]}"

RELEASE_VERSION="${MAJOR}.${MINOR}.${PATCH}"
NEXT_DEV_VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))"

RELEASE_BRANCH="release-${RELEASE_VERSION}"
POST_BRANCH="set-version-${NEXT_DEV_VERSION}"
RELEASE_COMMIT="[RELEASE] ${RELEASE_VERSION}"
POST_COMMIT="[TASK] Set version ${NEXT_DEV_VERSION}"

# ---------------------------------------------------------------------------
# Resolve + verify tooling.
# ---------------------------------------------------------------------------
resolve_bin() {
    local var="$1" name="$2" path
    path="$(command -v "${name}" 2>/dev/null || true)"
    if [ -z "${path}" ]; then
        die "Required tool '${name}' not found on PATH."
    fi
    printf -v "${var}" '%s' "${path}"
}
resolve_bin GIT git
resolve_bin GH  gh

if [ ! -x "${SET_VERSION_BIN}" ]; then
    die "Build/Scripts/setVersion.sh not found or not executable at ${SET_VERSION_BIN}"
fi

# ---------------------------------------------------------------------------
# Mode banner
# ---------------------------------------------------------------------------
MODE="default (local runs, remote SKIPPED — needs --execute)"
[ "${DRY_RUN}" -eq 1 ] && MODE="dry-run (nothing is changed)"
[ "${EXECUTE}" -eq 1 ] && MODE="EXECUTE (remote operations WILL run)"

info "release ${RELEASE_VERSION}"
note "source branch      : ${SOURCE_BRANCH}"
note "release branch     : ${RELEASE_BRANCH}     commit \"${RELEASE_COMMIT}\""
note "post-release branch: ${POST_BRANCH}   commit \"${POST_COMMIT}\""
note "next dev version   : ${NEXT_DEV_VERSION}"
note "mode               : ${MODE}"

# ---------------------------------------------------------------------------
# Pre-flight guards.
#  - work tree / repository sanity: always required.
#  - clean working tree + no existing tag: a dirty tree or an existing tag is
#    fatal with --execute; otherwise only a warning, so the flow can still be
#    rehearsed.
# ---------------------------------------------------------------------------
info "Pre-flight checks"
"${GIT}" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Not inside a git work tree."

if "${GIT}" rev-parse -q --verify "refs/tags/${RELEASE_VERSION}" >/dev/null 2>&1; then
    die "Tag '${RELEASE_VERSION}' already exists — refusing to re-release."
fi
note "no local tag '${RELEASE_VERSION}' — ok"

if [ -n "$("${GIT}" status --porcelain)" ]; then
    if [ "${EXECUTE}" -eq 1 ]; then
        die "Working tree is not clean — commit or stash before an --execute release."
    fi
    warn "Working tree is not clean (tolerated because this is not an --execute run)."
else
    note "working tree clean — ok"
fi

# ---------------------------------------------------------------------------
# Refresh the source branch.
# ---------------------------------------------------------------------------
info "Refresh source branch '${SOURCE_BRANCH}'"
run "${GIT}" checkout "${SOURCE_BRANCH}"
run_remote "${GIT}" fetch --all --prune
run_remote "${GIT}" pull --rebase

# ---------------------------------------------------------------------------
# PHASE 1 — release
# ---------------------------------------------------------------------------
info "PHASE 1 — release ${RELEASE_VERSION}"
run "${GIT}" checkout -b "${RELEASE_BRANCH}" "${SOURCE_BRANCH}"
run_set_version "${RELEASE_VERSION}" release
run "${GIT}" add -A
run "${GIT}" commit -m "${RELEASE_COMMIT}"

info "PHASE 1 — publish (remote)"
run_remote "${GIT}" push -u origin "${RELEASE_BRANCH}"
run_remote "${GH}" pr create --fill --base "${SOURCE_BRANCH}" --title "${RELEASE_COMMIT}"
run_remote sleep 10
run_remote "${GH}" pr checks --watch --interval 10 --fail-fast
run_remote sleep 10
run_remote "${GH}" pr merge --rebase --delete-branch --admin
run_remote "${GIT}" remote prune origin

info "PHASE 1 — tag ${RELEASE_VERSION}"
run "${GIT}" checkout "${SOURCE_BRANCH}"
run_remote "${GIT}" pull --ff-only origin "${SOURCE_BRANCH}"
run_remote "${GIT}" tag "${RELEASE_VERSION}"
run_remote "${GIT}" push origin "${RELEASE_VERSION}"

# ---------------------------------------------------------------------------
# PHASE 2 — post-release (set the next dev version)
# ---------------------------------------------------------------------------
info "PHASE 2 — post-release ${NEXT_DEV_VERSION}"
run "${GIT}" checkout "${SOURCE_BRANCH}"
run "${GIT}" checkout -b "${POST_BRANCH}" "${SOURCE_BRANCH}"
run_set_version "${NEXT_DEV_VERSION}" post-release
run "${GIT}" add -A
run "${GIT}" commit -m "${POST_COMMIT}"

info "PHASE 2 — publish (remote)"
run_remote "${GIT}" push -u origin "${POST_BRANCH}"
run_remote "${GH}" pr create --fill --base "${SOURCE_BRANCH}" --title "${POST_COMMIT}"
run_remote sleep 10
run_remote "${GH}" pr checks --watch --interval 10 --fail-fast
run_remote sleep 10
run_remote "${GH}" pr merge --rebase --delete-branch --admin
run_remote "${GIT}" remote prune origin

info "Finished release ${RELEASE_VERSION} (next dev ${NEXT_DEV_VERSION})"
if [ "${EXECUTE}" -eq 0 ] && [ "${DRY_RUN}" -eq 0 ]; then
    note "Remote operations were SKIPPED. Re-run with --execute to publish."
fi
