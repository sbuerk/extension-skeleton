#!/usr/bin/env bash

# ----------------------------------------------------------------------------------------------------------------------
# sbuerk/extension-skeleton test runner based on docker/podman.
# Adopted from TYPO3 Core Development and extension based additions.
# ----------------------------------------------------------------------------------------------------------------------
if [ "${CI}" != "true" ]; then
    trap 'echo "runTests.sh SIGINT signal emitted";cleanUp;exit 2' SIGINT
fi

printSummary() {
    cleanUp

    # Print summary
    echo "" >&2
    echo "###########################################################################" >&2
    echo "Result of ${TEST_SUITE}" >&2
    echo "Container runtime: ${CONTAINER_BIN}" >&2
    echo "Container suffix: ${SUFFIX}"
    if [[ ${IS_CORE_CI} -eq 1 ]]; then
        echo "Environment: CI" >&2
    else
        echo "Environment: local" >&2
    fi
    echo "PHP: ${PHP_VERSION}" >&2
    echo "TYPO3: ${CORE_VERSION}" >&2
    if [[ ${TEST_SUITE} =~ ^(functional)$ ]]; then
        case "${DBMS}" in
            mariadb|mysql|postgres)
                echo "DBMS: ${DBMS}  version ${DBMS_VERSION}  driver ${DATABASE_DRIVER}" >&2
                ;;
            sqlite)
                echo "DBMS: ${DBMS}" >&2
                ;;
        esac
    fi
    if [[ ${SUITE_EXIT_CODE} -eq 0 ]]; then
        echo "SUCCESS" >&2
    else
        echo "FAILURE" >&2
    fi
    echo "###########################################################################" >&2
    echo "" >&2

    # Exit with code of test suite - This script return non-zero if the executed test failed.
    exit $SUITE_EXIT_CODE
}

waitFor() {
    local HOST=${1}
    local PORT=${2}
    local TESTCOMMAND="
        COUNT=0;
        while ! nc -z ${HOST} ${PORT}; do
            if [ \"\${COUNT}\" -gt 10 ]; then
              echo \"Can not connect to ${HOST} port ${PORT}. Aborting.\";
              exit 1;
            fi;
            sleep 1;
            COUNT=\$((COUNT + 1));
        done;
    "
    ${CONTAINER_BIN} run ${CONTAINER_COMMON_PARAMS} --name wait-for-${SUFFIX} ${XDEBUG_MODE} -e XDEBUG_CONFIG="${XDEBUG_CONFIG}" ${IMAGE_PHP} /bin/sh -c "${TESTCOMMAND}"
    if [[ $? -gt 0 ]]; then
        kill -SIGINT -$$
    fi
}

cleanUp() {
    ATTACHED_CONTAINERS=$(${CONTAINER_BIN} ps --filter network=${NETWORK} --format='{{.Names}}')
    for ATTACHED_CONTAINER in ${ATTACHED_CONTAINERS}; do
        ${CONTAINER_BIN} rm -f ${ATTACHED_CONTAINER} >/dev/null
    done
    ${CONTAINER_BIN} network rm -f ${NETWORK} >/dev/null
}

handleDbmsOptions() {
    # -a, -d, -i depend on each other. Validate input combinations and set defaults.
    case ${DBMS} in
        mariadb)
            [ -z "${DATABASE_DRIVER}" ] && DATABASE_DRIVER="mysqli"
            if [ "${DATABASE_DRIVER}" != "mysqli" ] && [ "${DATABASE_DRIVER}" != "pdo_mysql" ]; then
                echo "Invalid combination -d ${DBMS} -a ${DATABASE_DRIVER}" >&2
                echo >&2
                echo "Use \"Build/Scripts/runTests.sh -h\" to display help and valid options" >&2
                exit 1
            fi
            [ -z "${DBMS_VERSION}" ] && DBMS_VERSION="10.4"
            if ! [[ ${DBMS_VERSION} =~ ^(10.4|10.5|10.6|10.7|10.8|10.9|10.10|10.11|11.0|11.1|11.2|11.3|11.4|11.5|11.6|11.7|11.8)$ ]]; then
                echo "Invalid combination -d ${DBMS} -i ${DBMS_VERSION}" >&2
                echo >&2
                echo "Use \"Build/Scripts/runTests.sh -h\" to display help and valid options" >&2
                exit 1
            fi
            ;;
        mysql)
            [ -z "${DATABASE_DRIVER}" ] && DATABASE_DRIVER="mysqli"
            if [ "${DATABASE_DRIVER}" != "mysqli" ] && [ "${DATABASE_DRIVER}" != "pdo_mysql" ]; then
                echo "Invalid combination -d ${DBMS} -a ${DATABASE_DRIVER}" >&2
                echo >&2
                echo "Use \"Build/Scripts/runTests.sh -h\" to display help and valid options" >&2
                exit 1
            fi
            [ -z "${DBMS_VERSION}" ] && DBMS_VERSION="8.0"
            if ! [[ ${DBMS_VERSION} =~ ^(8.0|8.1|8.2|8.3|8.4)$ ]]; then
                echo "Invalid combination -d ${DBMS} -i ${DBMS_VERSION}" >&2
                echo >&2
                echo "Use \"Build/Scripts/runTests.sh -h\" to display help and valid options" >&2
                exit 1
            fi
            ;;
        postgres)
            if [ -n "${DATABASE_DRIVER}" ]; then
                echo "Invalid combination -d ${DBMS} -a ${DATABASE_DRIVER}" >&2
                echo >&2
                echo "Use \"Build/Scripts/runTests.sh -h\" to display help and valid options" >&2
                exit 1
            fi
            [ -z "${DBMS_VERSION}" ] && DBMS_VERSION="10"
            if ! [[ ${DBMS_VERSION} =~ ^(10|11|12|13|14|15|16|17|18)$ ]]; then
                echo "Invalid combination -d ${DBMS} -i ${DBMS_VERSION}" >&2
                echo >&2
                echo "Use \"Build/Scripts/runTests.sh -h\" to display help and valid options" >&2
                exit 1
            fi
            ;;
        sqlite)
            if [ -n "${DATABASE_DRIVER}" ]; then
                echo "Invalid combination -d ${DBMS} -a ${DATABASE_DRIVER}" >&2
                echo >&2
                echo "Use \"Build/Scripts/runTests.sh -h\" to display help and valid options" >&2
                exit 1
            fi
            if [ -n "${DBMS_VERSION}" ]; then
                echo "Invalid combination -d ${DBMS} -i ${DATABASE_DRIVER}" >&2
                echo >&2
                echo "Use \"Build/Scripts/runTests.sh -h\" to display help and valid options" >&2
                exit 1
            fi
            ;;
        *)
            echo "Invalid option -d ${DBMS}" >&2
            echo >&2
            echo "Use \"Build/Scripts/runTests.sh -h\" to display help and valid options" >&2
            exit 1
            ;;
    esac
}

cleanCacheFiles() {
    echo -n "Clean caches ... "
    rm -rf \
        .cache \
        .php-cs-fixer.cache
    echo "done"
}

cleanTestFiles() {
    # test related
    echo -n "Clean test related files ... "
    rm -rf \
        .Build/Web/typo3temp/var/tests/
    echo "done"
}

cleanRenderedDocumentationFiles() {
    echo -n "Clean rendered documentation files ... "
    rm -rf \
        Documentation-GENERATED-temp
    echo "done"
}

loadHelp() {
    # Load help text into $HELP
    read -r -d '' HELP <<EOF
sbuerk/extension-skeleton test runner. Execute unit, functional and other test suites
in a container based test environment. Handles execution of single test files,
sending xdebug information to a local IDE and more.

Usage: $0 [options] [file]

Options:
    -s <...>
        Specifies which test suite to run
            - cgl: test and fix all php files
            - checkBom: check UTF-8 files do not contain BOM
            - checkExceptionCodes: check for duplicate and missing exception codes
            - checkMarkdownTables: check markdown tables are formatted, "-- --fix" to format them
            - checkRepositoryInitialization: check initializeRepository.sh rewrites all identifiers
            - checkTestMethodsPrefix: check test methods do not start with "test"
            - clean: clean up build, cache, rendered documentation and testing related files
            - cleanCache: clean up cache related files and folders
            - cleanRenderedDocumentation: clean up rendered documentation (Documentation-GENERATED-temp)
            - cleanTests: clean up test related files and folders
            - composer: "composer" with all remaining arguments dispatched
            - composerInstall: "composer install"
            - composerUpdate: "composer update", handy if host has no PHP
            - composerValidate: "composer validate --strict" of the root composer.json
            - functional: PHP functional tests
            - lintPhp: PHP linting
            - phpstan: phpstan analyze
            - phpstanGenerateBaseline: regenerate phpstan baseline, handy after phpstan updates
            - renderDocumentation: render the extension documentation into Documentation-GENERATED-temp
            - setVersion: apply a version across the repository, "-- <version> <type>"
            - unit (default): PHP unit tests
            - unitRandom: PHP unit tests in random order, "-o <number>" to use a specific seed
            - watchDocumentation: render the documentation and re-render it on every change,
              served on port 1337, a different port as first argument

    -b <docker|podman>
        Container environment:
            - docker
            - podman

        If not specified, podman will be used if available. Otherwise, docker is used.

    -a <mysqli|pdo_mysql>
        Only with -s functional
        Specifies to use another driver, following combinations are available:
            - mysql
                - mysqli (default)
                - pdo_mysql
            - mariadb
                - mysqli (default)
                - pdo_mysql

    -d <sqlite|mariadb|mysql|postgres>
        Only with -s functional
        Specifies on which DBMS tests are performed
            - sqlite: (default): use sqlite
            - mariadb: use mariadb
            - mysql: use MySQL
            - postgres: use postgres

    -i version
        Specify a specific database version
        With "-d mariadb":
            - 10.4   short-term, maintained until 2024-06-18 (default)
            - 10.5   short-term, maintained until 2025-06-24
            - 10.6   long-term, maintained until 2026-06
            - 10.7   short-term, no longer maintained
            - 10.8   short-term, maintained until 2023-05
            - 10.9   short-term, maintained until 2023-08
            - 10.10  short-term, maintained until 2023-11
            - 10.11  long-term, maintained until 2028-02
            - 11.0   development series
            - 11.1   short-term development series
            - 11.2   short-term development series, maintained until 2024-11
            - 11.3   short-term development series, rolling release
            - 11.4   long-term, maintained until 2029-05
            - 11.5   short-term development series, maintained until 2024-11
            - 11.6   short-term development series, maintained until 2025-02
            - 11.7   short-term development series, maintained until 2025-05
            - 11.8   long-term, maintained until 2030-06
        With "-d mysql":
            - 8.0   maintained until 2026-04 (default) LTS
            - 8.1   unmaintained since 2023-10
            - 8.2   unmaintained since 2024-01
            - 8.3   maintained until 2024-04
            - 8.4   maintained until 2032-04 LTS
        With "-d postgres":
            - 10    unmaintained since 2022-11-10 (default)
            - 11    maintained until 2023-11-09
            - 12    maintained until 2024-11-14
            - 13    maintained until 2025-11-13
            - 14    maintained until 2026-11-12
            - 15    maintained until 2027-11-11
            - 16    maintained until 2028-11-09
            - 17    maintained until 2029-11-08
            - 18    maintained until 2030-11-14

    -t <13|14>
        Specifies the TYPO3 CORE Version to be used
            - 13: (default) use TYPO3 v13
            - 14: use TYPO3 v14
        Note that the dependencies must be installed for the selected core
        version first, which is done by the composerUpdate suite:
            ./Build/Scripts/runTests.sh -t 13 -s composerUpdate
        Gates executed with a different core version installed than selected
        report false positives.

    -p <8.2|8.3|8.4|8.5>
        Specifies the PHP minor version to be used
            - 8.2: use PHP 8.2 (default)
            - 8.3: use PHP 8.3
            - 8.4: use PHP 8.4
            - 8.5: use PHP 8.5

    -x
        Only with -s functional|unit|unitRandom
        Send information to host instance for test or system under test break points. This is especially
        useful if a local PhpStorm instance is listening on default xdebug port 9003. A different port
        can be selected with -y

    -y <port>
        Send xdebug information to a different port than default 9003 if an IDE like PhpStorm
        is not listening on default port.

    -o <number>
        Only with -s unitRandom
        Set specific random seed to replay a random run in this order again. The phpunit randomizer
        outputs the used seed at the end. Use that number to replay the unit tests in that order.

    -n
        Only with -s cgl
        Activate dry-run in CGL check that does not actively change files and only prints broken ones.

    -u
        Update existing typo3/core-testing-*:latest container images and remove dangling local volumes.
        New images are published once in a while and only the latest ones are supported by core testing.
        Use this if weird test errors occur. Also removes obsolete image versions of typo3/core-testing-*.

    -h
        Show this help.

Examples:
    # Install dependencies for TYPO3 v13 on PHP 8.2 (default matrix)
    ./Build/Scripts/runTests.sh -t 13 -p 8.2 -s composerUpdate

    # Run all unit tests using PHP 8.2
    ./Build/Scripts/runTests.sh -s unit
    ./Build/Scripts/runTests.sh -s unit -p 8.2

    # Run all unit tests and enable xdebug (have a PhpStorm listening on port 9003!)
    ./Build/Scripts/runTests.sh -s unit -x

    # Run a single functional test class on sqlite, phpunit arguments after "--"
    ./Build/Scripts/runTests.sh -s functional -d sqlite -- --filter DummyTest

    # Run functional tests on postgres 10
    ./Build/Scripts/runTests.sh -s functional -d postgres -i 10

    # Check the coding guidelines without changing files, as CI does
    ./Build/Scripts/runTests.sh -s cgl -n

    # Write documentation with a browser preview reloading on every save
    ./Build/Scripts/runTests.sh -s watchDocumentation
    ./Build/Scripts/runTests.sh -s watchDocumentation 4711

    # Apply a version across the repository, without needing PHP on the host
    ./Build/Scripts/runTests.sh -s setVersion -- 1.2.0 release --dry-run
EOF
}

# Test if docker exists, else exit out with error
if ! type "docker" >/dev/null 2>&1 && ! type "podman" >/dev/null 2>&1; then
    echo "This script relies on docker or podman. Please install" >&2
    exit 1
fi

# Option defaults
TEST_SUITE="help"
CORE_VERSION="13"
DBMS="sqlite"
PHP_VERSION="8.2"
PHP_XDEBUG_ON=0
PHP_XDEBUG_PORT=9003
PHPUNIT_RANDOM=""
CGLCHECK_DRY_RUN=0
DATABASE_DRIVER=""
DBMS_VERSION=""
CONTAINER_BIN=""
CONTAINER_HOST="host.docker.internal"
DOCUMENTATION_PORT="1337"

# Option parsing updates above default vars
# Reset in case getopts has been used previously in the shell
OPTIND=1
# Array for invalid options
INVALID_OPTIONS=()
# Simple option parsing based on getopts (! not getopt)
while getopts "a:b:s:d:i:p:t:xy:o:nhu" OPT; do
    case ${OPT} in
        s)
            TEST_SUITE=${OPTARG}
            ;;
        b)
            if ! [[ ${OPTARG} =~ ^(docker|podman)$ ]]; then
                INVALID_OPTIONS+=("${OPTARG}")
            fi
            CONTAINER_BIN=${OPTARG}
            ;;
        a)
            DATABASE_DRIVER=${OPTARG}
            ;;
        d)
            DBMS=${OPTARG}
            ;;
        i)
            DBMS_VERSION=${OPTARG}
            ;;
        p)
            PHP_VERSION=${OPTARG}
            if ! [[ ${PHP_VERSION} =~ ^(8.2|8.3|8.4|8.5)$ ]]; then
                INVALID_OPTIONS+=("p ${OPTARG}")
            fi
            ;;
        t)
            CORE_VERSION=${OPTARG}
            if ! [[ ${CORE_VERSION} =~ ^(13|14)$ ]]; then
                INVALID_OPTIONS+=("t ${OPTARG}")
            fi
            ;;
        x)
            PHP_XDEBUG_ON=1
            ;;
        y)
            PHP_XDEBUG_PORT=${OPTARG}
            ;;
        o)
            PHPUNIT_RANDOM="--random-order-seed=${OPTARG}"
            ;;
        n)
            CGLCHECK_DRY_RUN=1
            ;;
        h)
            loadHelp
            echo "${HELP}"
            exit 0
            ;;
        u)
            TEST_SUITE=update
            ;;
        \?)
            INVALID_OPTIONS+=("${OPTARG}")
            ;;
        :)
            INVALID_OPTIONS+=("${OPTARG}")
            ;;
    esac
done

# Exit on invalid options
if [ ${#INVALID_OPTIONS[@]} -ne 0 ]; then
    echo "Invalid option(s):" >&2
    for I in "${INVALID_OPTIONS[@]}"; do
        echo "-"${I} >&2
    done
    echo >&2
    echo "call \"Build/Scripts/runTests.sh -h\" to display help and valid options"
    exit 1
fi

handleDbmsOptions

COMPOSER_ROOT_VERSION="1.0.0-dev"
CONTAINER_INTERACTIVE="-it --init"
HOST_UID=$(id -u)
HOST_GID=$(id -g)
# Additional container arguments a caller may inject, for instance a CI runner that has to pass
# "--userns" or a network mode. Declared so the expansions below are defined without a caller.
CI_PARAMS="${CI_PARAMS:-}"
USERSET=""
if [ $(uname) != "Darwin" ]; then
    USERSET="--user $HOST_UID"
fi

# Go to the directory this script is located, so everything else is relative
# to this dir, no matter from where this script is called, then go up two dirs.
THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
cd "$THIS_SCRIPT_DIR" || exit 1
cd ../../ || exit 1
ROOT_DIR="${PWD}"

# Create .cache dir: composer need this.
mkdir -p .cache/composer
mkdir -p .Build/Web/typo3temp/var/tests

IS_CORE_CI=0
if [ "${CI}" == "true" ]; then
    # ENV var "CI" is set by the pipeline. We use it here to distinct 'local' and 'CI' environment.
    IS_CORE_CI=1
    CONTAINER_INTERACTIVE=""
elif [ ! -t 0 ] || [ ! -t 1 ]; then
    # If stdin or stdout is not a TTY (a wrapper script, a pipe, an IDE run configuration or any
    # other non-interactive shell), drop the interactive "-it" flags to avoid the podman warning
    # "The input device is not a TTY.", the corresponding docker failure, and TTY control
    # characters in redirected output. "--init" is kept so the PID 1 init process still forwards
    # signals such as ctrl-c to the test process.
    CONTAINER_INTERACTIVE="--init"
fi

# determine default container binary to use: 1. podman 2. docker
if [[ -z "${CONTAINER_BIN}" ]]; then
    if type "podman" >/dev/null 2>&1; then
        CONTAINER_BIN="podman"
    elif type "docker" >/dev/null 2>&1; then
        CONTAINER_BIN="docker"
    fi
fi

IMAGE_PHP="ghcr.io/typo3/core-testing-$(echo "php${PHP_VERSION}" | sed -e 's/\.//'):latest"
IMAGE_DOCS="ghcr.io/typo3-documentation/render-guides:latest"
IMAGE_MARIADB="docker.io/mariadb:${DBMS_VERSION}"
IMAGE_MYSQL="docker.io/mysql:${DBMS_VERSION}"
IMAGE_POSTGRES="docker.io/postgres:${DBMS_VERSION}-alpine"
# PostgreSQL 18 moved "PGDATA" from "/var/lib/postgresql/data" to
# "/var/lib/postgresql/<major>/docker" and refuses to start when a mount point sits at the old
# location. Mounting one level above at "/var/lib/postgresql" is the documented recommendation
# for that case, while earlier versions expect the mount at the data directory itself.
POSTGRES_TMPFS_MOUNT="/var/lib/postgresql/data"
if [ "${DBMS}" = "postgres" ] && [ "${DBMS_VERSION}" -ge 18 ]; then
    POSTGRES_TMPFS_MOUNT="/var/lib/postgresql"
fi

# Set $1 to first mass argument, this is the optional test file or test directory to execute
shift $((OPTIND - 1))

SUFFIX=$(echo $RANDOM)
NETWORK="extension-skeleton-${SUFFIX}"
${CONTAINER_BIN} network create ${NETWORK} >/dev/null

if [ "${CONTAINER_BIN}" == "docker" ]; then
    # docker needs the add-host for xdebug remote debugging. podman has host.container.internal built in
    CONTAINER_COMMON_PARAMS="${CONTAINER_INTERACTIVE} --rm --network ${NETWORK} --add-host ${CONTAINER_HOST}:host-gateway ${USERSET} -v ${ROOT_DIR}:${ROOT_DIR} -w ${ROOT_DIR}"
    CONTAINER_SIMPLE_PARAMS="${CONTAINER_INTERACTIVE} --rm --network ${NETWORK} --add-host ${CONTAINER_HOST}:host-gateway ${USERSET} -v ${ROOT_DIR}:${ROOT_DIR} -w ${ROOT_DIR}"
    DOCUMENTATION_COMMON_PARAMS="${CONTAINER_INTERACTIVE} --rm ${USERSET} -v ${ROOT_DIR}:/project"
    # docker creates the tmpfs owned by root, which the container user - "--user" above - may not
    # be able to write to, and SQLite then fails with "unable to open database file". podman maps
    # the container user to the host user and needs no ownership here.
    #
    # Ownership and mode are both set, because they fail in different environments. A probe inside
    # a container on a GitHub hosted runner showed the mount as "root:root" mode 0755 with the
    # container user at "uid=1001 gid=0" - the group is 0 because "--user" above passes no group -
    # so neither the owner nor the group bits applied. Locally the same mount comes up 0775, which
    # is why setting the owner alone was enough there and not on the runner.
    TMPFS_MOUNT_OPTIONS="rw,noexec,nosuid,uid=${HOST_UID},gid=${HOST_GID},mode=1777"
else
    # podman
    CONTAINER_HOST="host.containers.internal"
    TMPFS_MOUNT_OPTIONS="rw,noexec,nosuid"
    if [ $( uname ) = "Linux" ]; then
        CONTAINER_COMMON_PARAMS="${CONTAINER_INTERACTIVE} ${CI_PARAMS} --rm --network ${NETWORK} -v ${ROOT_DIR}:${ROOT_DIR}:Z -w ${ROOT_DIR}"
        CONTAINER_SIMPLE_PARAMS="${CONTAINER_INTERACTIVE} ${CI_PARAMS} --rm -v ${ROOT_DIR}:${ROOT_DIR}:Z -w ${ROOT_DIR}"
        DOCUMENTATION_COMMON_PARAMS="${CONTAINER_INTERACTIVE} ${CI_PARAMS} --rm -v ${ROOT_DIR}:${ROOT_DIR}:Z -v ${ROOT_DIR}:/project"
    else
        CONTAINER_COMMON_PARAMS="${CONTAINER_INTERACTIVE} ${CI_PARAMS} --rm --network ${NETWORK} -v ${ROOT_DIR}:${ROOT_DIR} -w ${ROOT_DIR}"
        CONTAINER_SIMPLE_PARAMS="${CONTAINER_INTERACTIVE} ${CI_PARAMS} --rm -v ${ROOT_DIR}:${ROOT_DIR} -w ${ROOT_DIR}"
        DOCUMENTATION_COMMON_PARAMS="${CONTAINER_INTERACTIVE} ${CI_PARAMS} --rm -v ${ROOT_DIR}:${ROOT_DIR} -v ${ROOT_DIR}:/project"
    fi
fi

if [ ${PHP_XDEBUG_ON} -eq 0 ]; then
    XDEBUG_MODE="-e XDEBUG_MODE=off"
    XDEBUG_CONFIG=" "
else
    XDEBUG_MODE="-e XDEBUG_MODE=debug -e XDEBUG_TRIGGER=foo"
    XDEBUG_CONFIG="client_port=${PHP_XDEBUG_PORT} client_host=${CONTAINER_HOST}"
fi

# Suite execution
case ${TEST_SUITE} in
    cgl)
        # Active dry-run for cgl needs not "-n" but specific options
        CSFIXER_DRYRUN=""
        if [ "${CGLCHECK_DRY_RUN}" -eq 1 ]; then
            CSFIXER_DRYRUN="--dry-run --diff"
        fi
        COMMAND="php -dxdebug.mode=off .Build/bin/php-cs-fixer fix -v ${CSFIXER_DRYRUN} --config=Build/php-cs-fixer/config.php"
        ${CONTAINER_BIN} run ${CONTAINER_COMMON_PARAMS} --name cgl-${SUFFIX} ${IMAGE_PHP} ${COMMAND}
        SUITE_EXIT_CODE=$?
        ;;
    checkBom)
        COMMAND="Build/Scripts/checkUtf8Bom.sh"
        ${CONTAINER_BIN} run ${CONTAINER_COMMON_PARAMS} --name check-bom-${SUFFIX} ${IMAGE_PHP} /bin/sh -c "${COMMAND}"
        SUITE_EXIT_CODE=$?
        ;;
    checkExceptionCodes)
        COMMAND="Build/Scripts/duplicateExceptionCodeCheck.sh"
        ${CONTAINER_BIN} run ${CONTAINER_COMMON_PARAMS} --name check-exception-codes-${SUFFIX} ${IMAGE_PHP} /bin/bash -c "${COMMAND}"
        SUITE_EXIT_CODE=$?
        ;;
    checkMarkdownTables)
        COMMAND="php -dxdebug.mode=off Build/Scripts/checkMarkdownTables.php $@"
        ${CONTAINER_BIN} run ${CONTAINER_COMMON_PARAMS} --name check-markdown-tables-${SUFFIX} ${IMAGE_PHP} /bin/sh -c "${COMMAND}"
        SUITE_EXIT_CODE=$?
        ;;
    checkRepositoryInitialization)
        COMMAND="php -dxdebug.mode=off Build/Scripts/checkRepositoryInitialization.php"
        ${CONTAINER_BIN} run ${CONTAINER_COMMON_PARAMS} --name check-repository-initialization-${SUFFIX} ${IMAGE_PHP} /bin/bash -c "${COMMAND}"
        SUITE_EXIT_CODE=$?
        ;;
    checkTestMethodsPrefix)
        COMMAND="php -dxdebug.mode=off Build/Scripts/testMethodPrefixChecker.php"
        ${CONTAINER_BIN} run ${CONTAINER_COMMON_PARAMS} --name check-test-methods-prefix-${SUFFIX} ${IMAGE_PHP} /bin/sh -c "${COMMAND}"
        SUITE_EXIT_CODE=$?
        ;;
    clean)
        cleanCacheFiles
        cleanRenderedDocumentationFiles
        cleanTestFiles
        SUITE_EXIT_CODE=$?
        ;;
    cleanCache)
        cleanCacheFiles
        SUITE_EXIT_CODE=$?
        ;;
    cleanRenderedDocumentation)
        cleanRenderedDocumentationFiles
        SUITE_EXIT_CODE=$?
        ;;
    cleanTests)
        cleanTestFiles
        SUITE_EXIT_CODE=$?
        ;;
    composer)
        COMMAND=(composer "$@")
        ${CONTAINER_BIN} run ${CONTAINER_SIMPLE_PARAMS} --name composer-command-${SUFFIX} -e COMPOSER_CACHE_DIR=.cache/composer -e COMPOSER_ROOT_VERSION=${COMPOSER_ROOT_VERSION} ${IMAGE_PHP} "${COMMAND[@]}"
        SUITE_EXIT_CODE=$?
        ;;
    composerInstall)
        ${CONTAINER_BIN} run ${CONTAINER_SIMPLE_PARAMS} --name composer-install-${SUFFIX} -e COMPOSER_CACHE_DIR=.cache/composer -e COMPOSER_ROOT_VERSION=${COMPOSER_ROOT_VERSION} ${IMAGE_PHP} composer install
        SUITE_EXIT_CODE=$?
        ;;
    composerValidate)
        ${CONTAINER_BIN} run ${CONTAINER_SIMPLE_PARAMS} --name composer-validate-${SUFFIX} -e COMPOSER_CACHE_DIR=.cache/composer -e COMPOSER_ROOT_VERSION=${COMPOSER_ROOT_VERSION} ${IMAGE_PHP} composer validate --strict --no-check-lock
        SUITE_EXIT_CODE=$?
        ;;
    composerUpdate)
        rm -rf .Build composer.lock composer.json.orig
        if [[ ${IS_CORE_CI} -eq 0 ]]; then
            # Locally the cache is dropped along with the dependency set, as it was while it still
            # lived below ".Build/". This is a precaution, not a fix for a reproduced defect:
            # switching between the core versions also switches the major version of
            # "typo3/class-alias-loader", a working copy accumulates months of such switches, and
            # an install resolving against a cache from the other major is a class of failure that
            # is tedious to recognize. One download of a dependency set that was about to be
            # replaced anyway is the cheaper side of that trade.
            #
            # In CI the trade goes the other way: every job starts from an empty checkout, installs
            # once and ends, so there is no earlier state to collide with, and the cache is restored
            # on purpose to avoid downloading the dependency set in every job.
            rm -rf .cache
            mkdir -p .cache/composer
        fi
        \cp -f composer.json composer.json.orig
        ${CONTAINER_BIN} run ${CONTAINER_SIMPLE_PARAMS} --name composer-require-${SUFFIX} -e COMPOSER_CACHE_DIR=.cache/composer -e COMPOSER_ROOT_VERSION=${COMPOSER_ROOT_VERSION} ${IMAGE_PHP} composer require --dev --no-update "typo3/minimal":"^${CORE_VERSION}"
        SUITE_EXIT_CODE=$?
        if [[ "${SUITE_EXIT_CODE}" -eq 0 ]]; then
          ${CONTAINER_BIN} run ${CONTAINER_SIMPLE_PARAMS} --name composer-update-${SUFFIX} -e COMPOSER_CACHE_DIR=.cache/composer -e COMPOSER_ROOT_VERSION=${COMPOSER_ROOT_VERSION} ${IMAGE_PHP} composer install
          SUITE_EXIT_CODE=$?
        fi
        [[ -f composer.json.orig ]] && \cp -f composer.json.orig composer.json
        ;;
    functional)
        PHPUNIT_CONFIG_FILE="Build/phpunit/FunctionalTests.xml"
        COMMAND=(.Build/bin/phpunit -c ${PHPUNIT_CONFIG_FILE} --exclude-group not-${DBMS} --exclude-group not-core-${CORE_VERSION} "$@")
        case ${DBMS} in
            mariadb)
                echo "Using driver: ${DATABASE_DRIVER}"
                ${CONTAINER_BIN} run --rm ${CI_PARAMS} --name mariadb-func-${SUFFIX} --network ${NETWORK} -d -e MYSQL_ROOT_PASSWORD=funcp --tmpfs /var/lib/mysql/:rw,noexec,nosuid ${IMAGE_MARIADB} >/dev/null
                SUITE_EXIT_CODE=$? && [[ "${SUITE_EXIT_CODE}" -ne 0 ]] && printSummary
                waitFor mariadb-func-${SUFFIX} 3306
                CONTAINERPARAMS="-e typo3DatabaseDriver=${DATABASE_DRIVER} -e typo3DatabaseName=func_test -e typo3DatabaseUsername=root -e typo3DatabaseHost=mariadb-func-${SUFFIX} -e typo3DatabasePassword=funcp"
                ${CONTAINER_BIN} run ${CONTAINER_COMMON_PARAMS} --name functional-${SUFFIX} ${XDEBUG_MODE} -e XDEBUG_CONFIG="${XDEBUG_CONFIG}" ${CONTAINERPARAMS} ${IMAGE_PHP} "${COMMAND[@]}"
                SUITE_EXIT_CODE=$?
                ;;
            mysql)
                echo "Using driver: ${DATABASE_DRIVER}"
                ${CONTAINER_BIN} run --rm ${CI_PARAMS} --name mysql-func-${SUFFIX} --network ${NETWORK} -d -e MYSQL_ROOT_PASSWORD=funcp --tmpfs /var/lib/mysql/:rw,noexec,nosuid ${IMAGE_MYSQL} >/dev/null
                SUITE_EXIT_CODE=$? && [[ "${SUITE_EXIT_CODE}" -ne 0 ]] && printSummary
                waitFor mysql-func-${SUFFIX} 3306
                CONTAINERPARAMS="-e typo3DatabaseDriver=${DATABASE_DRIVER} -e typo3DatabaseName=func_test -e typo3DatabaseUsername=root -e typo3DatabaseHost=mysql-func-${SUFFIX} -e typo3DatabasePassword=funcp"
                ${CONTAINER_BIN} run ${CONTAINER_COMMON_PARAMS} --name functional-${SUFFIX} ${XDEBUG_MODE} -e XDEBUG_CONFIG="${XDEBUG_CONFIG}" ${CONTAINERPARAMS} ${IMAGE_PHP} "${COMMAND[@]}"
                SUITE_EXIT_CODE=$?
                ;;
            postgres)
                ${CONTAINER_BIN} run --rm ${CI_PARAMS} --name postgres-func-${SUFFIX} --network ${NETWORK} -d -e POSTGRES_PASSWORD=funcp -e POSTGRES_USER=funcu --tmpfs ${POSTGRES_TMPFS_MOUNT}:rw,noexec,nosuid ${IMAGE_POSTGRES} >/dev/null
                SUITE_EXIT_CODE=$? && [[ "${SUITE_EXIT_CODE}" -ne 0 ]] && printSummary
                waitFor postgres-func-${SUFFIX} 5432
                CONTAINERPARAMS="-e typo3DatabaseDriver=pdo_pgsql -e typo3DatabaseName=bamboo -e typo3DatabaseUsername=funcu -e typo3DatabaseHost=postgres-func-${SUFFIX} -e typo3DatabasePassword=funcp"
                ${CONTAINER_BIN} run ${CONTAINER_COMMON_PARAMS} --name functional-${SUFFIX} ${XDEBUG_MODE} -e XDEBUG_CONFIG="${XDEBUG_CONFIG}" ${CONTAINERPARAMS} ${IMAGE_PHP} "${COMMAND[@]}"
                SUITE_EXIT_CODE=$?
                ;;
            sqlite)
                # create sqlite tmpfs mount typo3temp/var/tests/functional-sqlite-dbs/ to avoid permission issues
                rm -rf "${ROOT_DIR}/.Build/Web/typo3temp/var/tests/functional-sqlite-dbs/"
                SUITE_EXIT_CODE=$? && [[ "${SUITE_EXIT_CODE}" -ne 0 ]] && printSummary
                mkdir -p "${ROOT_DIR}/.Build/Web/typo3temp/var/tests/functional-sqlite-dbs/"
                SUITE_EXIT_CODE=$? && [[ "${SUITE_EXIT_CODE}" -ne 0 ]] && printSummary
                CONTAINERPARAMS="-e typo3DatabaseDriver=pdo_sqlite --tmpfs ${ROOT_DIR}/.Build/Web/typo3temp/var/tests/functional-sqlite-dbs/:${TMPFS_MOUNT_OPTIONS}"
                ${CONTAINER_BIN} run ${CONTAINER_COMMON_PARAMS} --name functional-${SUFFIX} ${XDEBUG_MODE} -e XDEBUG_CONFIG="${XDEBUG_CONFIG}" ${CONTAINERPARAMS} ${IMAGE_PHP} "${COMMAND[@]}"
                SUITE_EXIT_CODE=$?
                ;;
        esac
        ;;
    lintPhp)
        COMMAND="find . -name \\*.php ! -path "./.Build/\\*" -print0 | xargs -0 -n1 -P4 php -dxdebug.mode=off -l >/dev/null"
        ${CONTAINER_BIN} run ${CONTAINER_COMMON_PARAMS} --name lint-php-${SUFFIX} ${IMAGE_PHP} /bin/sh -c "${COMMAND}"
        SUITE_EXIT_CODE=$?
        ;;
    phpstan)
        PHPSTAN_CONFIG_FILE="Build/phpstan/Core${CORE_VERSION}/phpstan.neon"
        COMMAND=(php -dxdebug.mode=off .Build/bin/phpstan analyse -c ${PHPSTAN_CONFIG_FILE} --no-interaction --memory-limit 4G "$@")
        ${CONTAINER_BIN} run ${CONTAINER_COMMON_PARAMS} --name phpstan-${SUFFIX} ${IMAGE_PHP} "${COMMAND[@]}"
        SUITE_EXIT_CODE=$?
        ;;
    phpstanGenerateBaseline)
        PHPSTAN_CONFIG_FILE="Build/phpstan/Core${CORE_VERSION}/phpstan.neon"
        COMMAND=(php -dxdebug.mode=off .Build/bin/phpstan analyse -c ${PHPSTAN_CONFIG_FILE} --no-interaction --memory-limit 4G --allow-empty-baseline --generate-baseline=Build/phpstan/Core${CORE_VERSION}/phpstan-baseline.neon "$@")
        ${CONTAINER_BIN} run ${CONTAINER_COMMON_PARAMS} --name phpstan-baseline-${SUFFIX} ${IMAGE_PHP} "${COMMAND[@]}"
        SUITE_EXIT_CODE=$?
        ;;
    renderDocumentation)
        cleanRenderedDocumentationFiles
        ${CONTAINER_BIN} run ${DOCUMENTATION_COMMON_PARAMS} --name render-documentation-${SUFFIX} ${IMAGE_DOCS} --no-progress --fail-on-error --config=Documentation Documentation
        SUITE_EXIT_CODE=$?
        ;;
    setVersion)
        # Arguments are the ones of the script itself, for instance:
        #   ./Build/Scripts/runTests.sh -s setVersion -- 1.2.0 release
        COMMAND=(Build/Scripts/setVersion.sh "$@")
        ${CONTAINER_BIN} run ${CONTAINER_COMMON_PARAMS} --name set-version-${SUFFIX} ${IMAGE_PHP} "${COMMAND[@]}"
        SUITE_EXIT_CODE=$?
        ;;
    unit)
        PHPUNIT_CONFIG_FILE="Build/phpunit/UnitTests.xml"
        COMMAND=(.Build/bin/phpunit -c ${PHPUNIT_CONFIG_FILE} --exclude-group not-core-${CORE_VERSION} "$@")
        ${CONTAINER_BIN} run ${CONTAINER_COMMON_PARAMS} --name unit-${SUFFIX} ${XDEBUG_MODE} -e XDEBUG_CONFIG="${XDEBUG_CONFIG}" ${IMAGE_PHP} "${COMMAND[@]}"
        SUITE_EXIT_CODE=$?
        ;;
    unitRandom)
        PHPUNIT_CONFIG_FILE="Build/phpunit/UnitTests.xml"
        COMMAND=(.Build/bin/phpunit -c ${PHPUNIT_CONFIG_FILE} --exclude-group not-core-${CORE_VERSION} --order-by=random ${PHPUNIT_RANDOM} "$@")
        ${CONTAINER_BIN} run ${CONTAINER_COMMON_PARAMS} --name unit-random-${SUFFIX} ${XDEBUG_MODE} -e XDEBUG_CONFIG="${XDEBUG_CONFIG}" ${IMAGE_PHP} "${COMMAND[@]}"
        SUITE_EXIT_CODE=$?
        ;;
    watchDocumentation)
        # An optional first mass argument overrides the port, for a second instance or a taken one.
        DOCUMENTATION_PORT="${1:-${DOCUMENTATION_PORT}}"
        if ! [[ ${DOCUMENTATION_PORT} =~ ^[0-9]+$ ]]; then
            echo "Invalid port \"${DOCUMENTATION_PORT}\", expected a number." >&2
            SUITE_EXIT_CODE=1
        else
            cleanRenderedDocumentationFiles
            echo "Rendering Documentation/ and watching it for changes."
            echo "Open http://localhost:${DOCUMENTATION_PORT}/Index.html once the first render is done."
            echo "Press ctrl-c to stop."
            echo ""
            # Attached to the network so an interrupted run is caught by cleanUp(). Files added
            # while the server runs are not picked up; restart the suite for those.
            ${CONTAINER_BIN} run ${DOCUMENTATION_COMMON_PARAMS} --network ${NETWORK} --name watch-documentation-${SUFFIX} -p ${DOCUMENTATION_PORT}:${DOCUMENTATION_PORT} ${IMAGE_DOCS} --port ${DOCUMENTATION_PORT} --watch --config=Documentation Documentation
            SUITE_EXIT_CODE=$?
        fi
        ;;
    update)
        # pull typo3/core-testing-* versions of those ones that exist locally
        echo "> pull ghcr.io/typo3/core-testing-* versions of those ones that exist locally"
        ${CONTAINER_BIN} images "ghcr.io/typo3/core-testing-*" --format "{{.Repository}}:{{.Tag}}" | xargs -I {} ${CONTAINER_BIN} pull {}
        echo ""
        # remove "dangling" typo3/core-testing-* images (those tagged as <none>)
        echo "> remove \"dangling\" ghcr.io/typo3/core-testing-* images (those tagged as <none>)"
        ${CONTAINER_BIN} images --filter "reference=ghcr.io/typo3/core-testing-*" --filter "dangling=true" --format "{{.ID}}" | xargs -I {} ${CONTAINER_BIN} rmi -f {}
        echo ""
        SUITE_EXIT_CODE=0
        ;;
    help)
        loadHelp
        echo "${HELP}" >&2
        cleanUp
        exit 0
        ;;
    *)
        loadHelp
        echo "Invalid -s option argument ${TEST_SUITE}" >&2
        echo >&2
        echo "${HELP}" >&2
        cleanUp
        exit 1
        ;;
esac

# Cleanup, print summary && exit with exitcode
printSummary
