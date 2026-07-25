#!/usr/bin/env bash

#
# setVersion.sh — apply a version across the extension repository.
#
# Applies a version (and its derived variants) to every relevant file:
#
#   Build/Scripts/runTests.sh   COMPOSER_ROOT_VERSION
#   composer.json               extra.typo3/cms.version, extra.branch-alias
#   ext_emconf.php              'version'
#   VERSION                     the plain version file
#   functional test fixtures    Tests/Functional/Fixtures/Extensions/*:
#                               ext_emconf.php version and, when the fixture
#                               requires the extension itself, its composer
#                               constraint
#
# The fixture extensions are discovered dynamically — nothing about them is
# hardcoded here, and no fixture extension has to exist.
#
# Usage:
#   Build/Scripts/setVersion.sh <version> <type> [options]
#
#   <version>   MAJOR.MINOR.PATCH, e.g. 1.2.0
#   <type>      release | post-release | dev
#                 release      : tag/release version (X.Y.Z, no branch-alias)
#                 post-release : next dev version (X.Y.W-dev, branch-alias
#                                X.Y.x-dev) — the version passed is already the
#                                next version, no "+1" happens here
#                 dev          : force a plain dev version everywhere
#                                (X.Y.Z-dev), thin variant of post-release for
#                                branching and forced minor/major bumps
#
# Options:
#   --source-branch=<name>   git branch the branch-alias is keyed to (default: main)
#   --dry-run                print every change without touching a file
#   -h, --help               show this help
#
# This script only edits working-tree files. It performs no git or network
# operations — the orchestration (branch/commit/pull request/tag) lives in
# Build/Scripts/release.sh.
#

set -euo pipefail

# ---------------------------------------------------------------------------
# Always operate from the repository root. This script lives in
# <root>/Build/Scripts, so the repository root is two directories up.
# ---------------------------------------------------------------------------
THIS_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
ROOT_DIR="$(cd -- "${THIS_SCRIPT_DIR}/../.." >/dev/null && pwd)"
cd "${ROOT_DIR}"

DRY_RUN=0

info() { printf '>> %s\n' "$*"; }
step() { printf '   [%s] %s\n' "$1" "$2"; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
    sed -n '3,43p' "${BASH_SOURCE[0]}" | sed 's/^#\{0,1\} \{0,1\}//'
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
PASSED_VERSION=""
TYPE=""
SOURCE_BRANCH="main"

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)          DRY_RUN=1 ;;
        --source-branch=*)  SOURCE_BRANCH="${1#*=}" ;;
        --source-branch)    shift; SOURCE_BRANCH="${1:-}" ;;
        -h|--help)          usage; exit 0 ;;
        -*)                 die "Unknown option: $1 (see --help)" ;;
        *)
            if [ -z "${PASSED_VERSION}" ]; then
                PASSED_VERSION="$1"
            elif [ -z "${TYPE}" ]; then
                TYPE="$1"
            else
                die "Unexpected extra argument: $1 (see --help)"
            fi
            ;;
    esac
    shift
done

if [ -z "${PASSED_VERSION}" ]; then
    die "Missing <version> argument (see --help)"
fi
if [ -z "${TYPE}" ]; then
    die "Missing <type> argument (see --help)"
fi

# ---------------------------------------------------------------------------
# Validate version + type
# ---------------------------------------------------------------------------
if ! [[ "${PASSED_VERSION}" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    die "Invalid version '${PASSED_VERSION}': expected MAJOR.MINOR.PATCH (e.g. 1.2.0)"
fi
MAJOR="${BASH_REMATCH[1]}"
MINOR="${BASH_REMATCH[2]}"
PATCH="${BASH_REMATCH[3]}"

case "${TYPE}" in
    release|post-release|dev) : ;;
    *) die "Invalid type '${TYPE}': expected release | post-release | dev" ;;
esac

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
resolve_bin PHP php
resolve_bin SED sed

if [ ! -f composer.json ]; then
    die "No composer.json found in ${ROOT_DIR}."
fi

# ---------------------------------------------------------------------------
# composer.json access.
#
# php rather than jq, for the same reason Build/Scripts/initializeRepository.sh
# uses it: the container images of Build/Scripts/runTests.sh ship no jq, so a
# script depending on it cannot be run through the wrapper — and this one is,
# with "-s setVersion", so a host without php can release as well.
#
# Values are decoded into objects, not associative arrays, so an empty JSON
# object survives the round trip as "{}" instead of turning into "[]".
# ---------------------------------------------------------------------------
composer_json_name() {
    "${PHP}" -r '
        $data = json_decode((string)file_get_contents($argv[1]));
        if (!$data instanceof stdClass) {
            fwrite(STDERR, $argv[1] . " does not contain a JSON object." . PHP_EOL);
            exit(1);
        }
        echo $data->name ?? "", PHP_EOL;
    ' -- "$1"
}

# Whether a section of a composer.json requires a package. Answered by the exit
# code, so it reads like the "jq -e" test it replaces.
composer_json_requires() {
    "${PHP}" -r '
        $data = json_decode((string)file_get_contents($argv[1]));
        $section = $data instanceof stdClass ? ($data->{$argv[2]} ?? null) : null;
        exit($section instanceof stdClass && property_exists($section, $argv[3]) ? 0 : 1);
    ' -- "$1" "$2" "$3"
}

# ---------------------------------------------------------------------------
# Derive the per-type version variants.
#
#   RUNTESTS_VERSION      -> Build/Scripts/runTests.sh COMPOSER_ROOT_VERSION
#   COMPOSER_VERSION      -> composer.json extra.typo3/cms.version
#   VERSION_FILE_VALUE    -> the VERSION file
#   EMCONF_VERSION        -> ext_emconf.php 'version'
#   FIXTURE_CONSTRAINT    -> composer constraint of fixture extensions
#                            requiring the extension itself
#   BRANCH_ALIAS          -> extra.branch-alias.dev-<source-branch>
# ---------------------------------------------------------------------------
BRANCH_ALIAS="${MAJOR}.${MINOR}.x-dev"

if [ "${TYPE}" = "release" ]; then
    RELEASE_VERSION="${MAJOR}.${MINOR}.${PATCH}"
    RUNTESTS_VERSION="${RELEASE_VERSION}"
    COMPOSER_VERSION="${RELEASE_VERSION}"
    VERSION_FILE_VALUE="${RELEASE_VERSION}"
    EMCONF_VERSION="${RELEASE_VERSION}"
    FIXTURE_CONSTRAINT="${RELEASE_VERSION}@dev"
    SET_BRANCH_ALIAS=0
else
    # post-release and dev share the -dev derivation; the passed version is the
    # dev version to apply directly (no "+1" here).
    DEV_VERSION="${MAJOR}.${MINOR}.${PATCH}"
    RUNTESTS_VERSION="${DEV_VERSION}-dev"
    COMPOSER_VERSION="${DEV_VERSION}-dev"
    VERSION_FILE_VALUE="${DEV_VERSION}-dev"
    EMCONF_VERSION="${DEV_VERSION}"
    FIXTURE_CONSTRAINT="~${DEV_VERSION}@dev"
    SET_BRANCH_ALIAS=1
fi

PACKAGE_NAME="$(composer_json_name composer.json)"
if [ -z "${PACKAGE_NAME}" ]; then
    die "No 'name' found in composer.json."
fi

info "setVersion ${PASSED_VERSION} (${TYPE})$([ "${DRY_RUN}" -eq 1 ] && echo '  [DRY-RUN]')"
step "info" "package                        = ${PACKAGE_NAME}"
step "info" "runTests COMPOSER_ROOT_VERSION = ${RUNTESTS_VERSION}"
step "info" "composer extension version     = ${COMPOSER_VERSION}"
step "info" "ext_emconf version             = ${EMCONF_VERSION}"
step "info" "VERSION file                   = ${VERSION_FILE_VALUE}"
if [ "${SET_BRANCH_ALIAS}" -eq 1 ]; then
    step "info" "branch-alias dev-${SOURCE_BRANCH} = ${BRANCH_ALIAS}"
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Execute a command, or in dry-run mode only print it.
run() {
    if [ "${DRY_RUN}" -eq 1 ]; then
        printf '   [dry-run] %s\n' "$*"
        return 0
    fi
    "$@"
}

# Rewrite a composer.json in place. The modes are the three writes a release
# needs, rather than a general purpose filter:
#
#   extension-version <file> <version>
#   branch-alias      <file> <key> <alias>
#   requirement       <file> <section> <package> <constraint>
#
# Encoding with these flags and a trailing newline is byte identical to the
# "jq --indent 4" this replaces, so a release produces no formatting diff.
apply_composer_json() {
    local mode="$1" file="$2"
    shift 2
    if [ "${DRY_RUN}" -eq 1 ]; then
        return 0
    fi
    "${PHP}" -r '
        $mode = $argv[1];
        $file = $argv[2];
        $data = json_decode((string)file_get_contents($file));
        if (!$data instanceof stdClass) {
            fwrite(STDERR, $file . " does not contain a JSON object." . PHP_EOL);
            exit(1);
        }
        switch ($mode) {
            case "extension-version":
                $data->extra ??= new stdClass();
                $data->extra->{"typo3/cms"} ??= new stdClass();
                $data->extra->{"typo3/cms"}->version = $argv[3];
                break;
            case "branch-alias":
                // Replaced rather than merged: a package has one source branch,
                // and a stale alias of a renamed branch would linger forever.
                $data->extra ??= new stdClass();
                $data->extra->{"branch-alias"} = (object)[$argv[3] => $argv[4]];
                break;
            case "requirement":
                $section = $data->{$argv[3]} ?? null;
                if (!$section instanceof stdClass || !property_exists($section, $argv[4])) {
                    fwrite(STDERR, $file . " has no " . $argv[3] . "." . $argv[4] . "." . PHP_EOL);
                    exit(1);
                }
                $section->{$argv[4]} = $argv[5];
                break;
            default:
                fwrite(STDERR, "Unknown composer.json write: " . $mode . PHP_EOL);
                exit(1);
        }
        $encoded = json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        file_put_contents($file, $encoded . PHP_EOL);
    ' -- "${mode}" "${file}" "$@"
}

# Set the 'version' of an ext_emconf.php.
apply_emconf_version() {
    local file="$1"
    step "${file}" "version = ${EMCONF_VERSION}"
    run "${SED}" -i -E \
        "s/('version'[[:space:]]*=>[[:space:]]*)'[^']*'/\\1'${EMCONF_VERSION}'/" \
        "${file}"
}

# ---------------------------------------------------------------------------
# 1. Build/Scripts/runTests.sh COMPOSER_ROOT_VERSION
# ---------------------------------------------------------------------------
info "Build/Scripts/runTests.sh"
step "Build/Scripts/runTests.sh" "COMPOSER_ROOT_VERSION = ${RUNTESTS_VERSION}"
run "${SED}" -i \
    "s/^COMPOSER_ROOT_VERSION=.*/COMPOSER_ROOT_VERSION=\"${RUNTESTS_VERSION}\"/" \
    Build/Scripts/runTests.sh

# ---------------------------------------------------------------------------
# 2. Root composer.json: extension version and branch-alias.
# ---------------------------------------------------------------------------
info "composer.json"
step "composer.json" "extra.typo3/cms.version = ${COMPOSER_VERSION}"
apply_composer_json extension-version composer.json "${COMPOSER_VERSION}"

if [ "${SET_BRANCH_ALIAS}" -eq 1 ]; then
    step "composer.json" "extra.branch-alias.dev-${SOURCE_BRANCH} = ${BRANCH_ALIAS}"
    apply_composer_json branch-alias composer.json "dev-${SOURCE_BRANCH}" "${BRANCH_ALIAS}"
else
    # Left untouched for a release: composer ignores the branch-alias for a
    # tagged version anyway, and rewriting it would only churn the key order.
    step "composer.json" "extra.branch-alias unchanged (release version)"
fi

# ---------------------------------------------------------------------------
# 3. ext_emconf.php and VERSION of the extension itself.
# ---------------------------------------------------------------------------
info "Extension version files"
if [ -f ext_emconf.php ]; then
    apply_emconf_version ext_emconf.php
fi

step "VERSION" "= ${VERSION_FILE_VALUE}"
if [ "${DRY_RUN}" -eq 1 ]; then
    printf '   [dry-run] printf %%s %s > VERSION\n' "${VERSION_FILE_VALUE}"
else
    printf '%s\n' "${VERSION_FILE_VALUE}" > VERSION
fi

# ---------------------------------------------------------------------------
# 4. Functional test fixture extensions. Discovered dynamically; none has to
#    exist. Their ext_emconf.php version is aligned, and a composer requirement
#    on the extension itself is updated to the matching constraint.
# ---------------------------------------------------------------------------
FIXTURE_BASE_DIR="Tests/Functional/Fixtures/Extensions"
declare -a FIXTURE_DIRS=()
if [ -d "${FIXTURE_BASE_DIR}" ]; then
    while IFS= read -r fixtureDir; do
        FIXTURE_DIRS+=("${fixtureDir}")
    done < <(find "${FIXTURE_BASE_DIR}" -mindepth 1 -maxdepth 1 -type d | sort)
fi

info "Functional test fixture extensions (${#FIXTURE_DIRS[@]} found)"
for dir in "${FIXTURE_DIRS[@]}"; do
    if [ -f "${dir}/ext_emconf.php" ]; then
        apply_emconf_version "${dir}/ext_emconf.php"
    fi
    if [ ! -f "${dir}/composer.json" ]; then
        continue
    fi
    for section in require require-dev; do
        if ! composer_json_requires "${dir}/composer.json" "${section}" "${PACKAGE_NAME}"; then
            continue
        fi
        step "${dir}/composer.json" "${section}.${PACKAGE_NAME} = ${FIXTURE_CONSTRAINT}"
        apply_composer_json requirement "${dir}/composer.json" \
            "${section}" "${PACKAGE_NAME}" "${FIXTURE_CONSTRAINT}"
    done
done

info "Finished setVersion ${PASSED_VERSION} (${TYPE})"
