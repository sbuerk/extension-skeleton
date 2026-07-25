# Development environment

All tests and quality tools run in containers through the
[`Build/Scripts/runTests.sh`](../../Build/Scripts/runTests.sh) wrapper. The only
requirement on the host is a container runtime — **podman** (preferred) or
**docker**. The wrapper pulls the required TYPO3 testing images on first use;
neither PHP nor Composer needs to be installed on the host.

Dependencies are installed into the git-ignored `.Build/` directory. The
wrapper installs them for a specific TYPO3 core and PHP version:

```bash
# Install dependencies for TYPO3 v13 on PHP 8.2 (default matrix).
Build/Scripts/runTests.sh -t 13 -p 8.2 -s composerUpdate

# Switch the working copy to the TYPO3 v14 dependency set.
Build/Scripts/runTests.sh -t 14 -p 8.2 -s composerUpdate
```

> [!IMPORTANT]
> The installed dependency set must match the core version a gate is run for.
> See [Dual core setup](dual-core-setup.md) — this is the single most common
> source of false positives in this repository.

Run `Build/Scripts/runTests.sh -h` to see all suites and options.

The wrapper detects whether it is attached to a terminal. Interactively it runs
the containers with `-it`; from a pipe, a wrapper script, an IDE run
configuration or a git hook it drops those flags — podman would only warn, but
docker fails outright, and redirected output would carry TTY control characters.
`--init` is kept either way, so ctrl-c still reaches the process in the
container.

It picks **podman** whenever it is installed and falls back to docker; `-b`
overrides that. There is no reason to pass it locally — the workflows do, and
[why they do](quality-gates.md#why-ci-passes--b-docker) is a property of GitHub
hosted runners, not of this repository.

## Frequently used options

| Option         | Meaning                                                                   |
|----------------|---------------------------------------------------------------------------|
| `-s <suite>`   | Suite to run (`unit`, `functional`, `cgl`, `phpstan`, …).                 |
| `-t <13\|14>`  | TYPO3 core major version to run against. Default `13`.                    |
| `-p <version>` | PHP version (`8.2` … `8.5`). Default `8.2`.                               |
| `-d <dbms>`    | Database for functional tests (`sqlite`, `mariadb`, `mysql`, `postgres`). |
| `-i <version>` | Database image version, together with `-d`. `-h` lists the accepted ones. |
| `-b <bin>`     | Container binary, `podman` or `docker`. Auto-detected, podman preferred.  |
| `-n`           | Check only, do not modify files (used by `cgl` in CI).                    |
| `-o <seed>`    | Replay a specific random order seed with `unitRandom`.                    |
| `-h`           | Full help with every suite and option.                                    |

## Suites

| Suite                           | Purpose                                                       |
|---------------------------------|---------------------------------------------------------------|
| `unit`                          | PHP unit tests (default suite).                               |
| `unitRandom`                    | Unit tests in random order.                                   |
| `functional`                    | PHP functional tests.                                         |
| `cgl`                           | Coding guidelines, fix in place or check with `-n`.           |
| `phpstan`                       | Static analysis.                                              |
| `phpstanGenerateBaseline`       | Regenerate the PHPStan baseline of the selected core version. |
| `lintPhp`                       | PHP linting.                                                  |
| `checkBom`                      | UTF-8 files must not contain a BOM.                           |
| `checkExceptionCodes`           | Duplicate or missing exception codes.                         |
| `checkMarkdownTables`           | Markdown tables must be formatted, `-- --fix` formats them.   |
| `checkRepositoryInitialization` | `initializeRepository.sh` rewrites every identifier.          |
| `checkTestMethodsPrefix`        | Test methods must not start with `test`.                      |
| `composer`                      | `composer` with all remaining arguments dispatched.           |
| `composerInstall`               | `composer install`.                                           |
| `composerUpdate`                | `composer update` for the core version given with `-t`.       |
| `composerValidate`              | `composer validate --strict` of the root `composer.json`.     |
| `renderDocumentation`           | Render `Documentation/` into `Documentation-GENERATED-temp/`. |
| `setVersion`                    | Apply a version, `-- <version> <type>`.                       |
| `watchDocumentation`            | Serve `Documentation/`, re-rendering on every change.         |
| `clean`                         | Remove build, cache, rendered documentation and test files.   |
| `cleanCache`                    | Cache files and folders only.                                 |
| `cleanRenderedDocumentation`    | `Documentation-GENERATED-temp/` only.                         |
| `cleanTests`                    | Test related files and folders only.                          |

## Passing arguments to the underlying tool

The wrapper parses its own options with `getopts`, so arguments meant for
PHPUnit (or any other dispatched tool) must follow a `--` separator:

```bash
Build/Scripts/runTests.sh -s functional -d sqlite -- --filter DummyTest
```

## See also

- [Dual core setup](dual-core-setup.md)
- [Quality gates](quality-gates.md)
- [Testing](../testing/Index.md)
