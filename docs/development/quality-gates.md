# Quality gates

The same gates run locally and in the GitHub Actions workflows for TYPO3 v13
and v14. Every one of them must pass for both core versions, each after the
matching `composerUpdate` — see [Dual core setup](dual-core-setup.md).

## The gates

```bash
# Coding guidelines: fix in place ...
Build/Scripts/runTests.sh -s cgl

# ... or check only, without changing files, as CI does.
Build/Scripts/runTests.sh -s cgl -n

# Static analysis (PHPStan, level 8).
Build/Scripts/runTests.sh -s phpstan

# PHP linting.
Build/Scripts/runTests.sh -s lintPhp

# Validate the root composer.json.
Build/Scripts/runTests.sh -s composerValidate

# Ensure UTF-8 files do not contain a BOM.
Build/Scripts/runTests.sh -s checkBom

# Find duplicate or missing exception codes.
Build/Scripts/runTests.sh -s checkExceptionCodes

# Ensure markdown tables are formatted ("-- --fix" formats them).
Build/Scripts/runTests.sh -s checkMarkdownTables

# Ensure the repository initialization rewrites every identifier.
Build/Scripts/runTests.sh -s checkRepositoryInitialization

# Ensure test methods do not start with "test".
Build/Scripts/runTests.sh -s checkTestMethodsPrefix
```

| Gate                            | Configuration                                                                                              | Core version dependent |
|---------------------------------|------------------------------------------------------------------------------------------------------------|------------------------|
| `cgl`                           | [`Build/php-cs-fixer/config.php`](../../Build/php-cs-fixer/config.php)                                     | no                     |
| `phpstan`                       | `Build/phpstan/Core13/`, `Build/phpstan/Core14/`                                                           | **yes**                |
| `lintPhp`                       | —                                                                                                          | no                     |
| `composerValidate`              | `composer.json`                                                                                            | no                     |
| `checkBom`                      | [`Build/Scripts/checkUtf8Bom.sh`](../../Build/Scripts/checkUtf8Bom.sh)                                     | no                     |
| `checkExceptionCodes`           | [`Build/Scripts/duplicateExceptionCodeCheck.sh`](../../Build/Scripts/duplicateExceptionCodeCheck.sh)       | no                     |
| `checkMarkdownTables`           | [`Build/Scripts/checkMarkdownTables.php`](../../Build/Scripts/checkMarkdownTables.php)                     | no                     |
| `checkRepositoryInitialization` | [`Build/Scripts/checkRepositoryInitialization.php`](../../Build/Scripts/checkRepositoryInitialization.php) | no                     |
| `checkTestMethodsPrefix`        | [`Build/Scripts/testMethodPrefixChecker.php`](../../Build/Scripts/testMethodPrefixChecker.php)             | no                     |

## PHPStan

PHPStan runs at **level 8** and is configured **per core version**. Each
configuration analyses only its own core version aware sources —
`Build/phpstan/Core13/phpstan.neon` lists `Classes`, `Configuration`, `Core13`
and `Tests`, and excludes `Tests/*/Core14/*`. Analysing the sources of the other
core version would report false positives about API that does not exist there.

Both PHPStan suites pass arguments after `--` through to the tool and do not
force an output format, so `-- --error-format=json` or `-- --no-progress` is the
caller's choice.

When PHPStan reports pre-existing findings that cannot be fixed right away, the
baseline can be regenerated per core version — but **prefer fixing the finding**:

```bash
Build/Scripts/runTests.sh -t 13 -s phpstanGenerateBaseline
Build/Scripts/runTests.sh -t 14 -s phpstanGenerateBaseline
```

A growing baseline is a defect, not a configuration. Regenerating it to make a
new finding disappear hides the very problem the gate exists for. The two
`@phpstan-ignore` annotations this repository does accept are documented, scoped
and justified in
[Class design](../architecture/class-design.md#the-two-phpstan-ignores-on-injected-readonly-properties);
nothing else may be silenced.

## Exception codes

TYPO3 exception codes are unix timestamps taken at the moment the exception is
written, and must be unique across the code base. `checkExceptionCodes` finds
both duplicates and exceptions thrown without a code.

## Test method naming

Test methods must **not** be prefixed with `test`; use the PHPUnit `#[Test]`
attribute and a descriptive method name instead. `checkTestMethodsPrefix`
enforces this:

```php
#[Test]
public function getExtensionKeyReturnsExtensionKey(): void
{
    // ...
}
```

## Markdown table formatting

`checkMarkdownTables` verifies that every table in `./*.md` and `docs/` is
formatted — cells padded so the pipes line up, separator row as wide as its
column.

It is the second gate that can fix what it finds, and the two are inverted
towards each other: `cgl` **fixes** by default and only checks with `-n`, while
`checkMarkdownTables` **checks** by default and only fixes when asked:

```bash
Build/Scripts/runTests.sh -s checkMarkdownTables
Build/Scripts/runTests.sh -s checkMarkdownTables -- --fix
```

The gate exists because the defect is invisible: an unformatted table renders
exactly like a formatted one, so it survives review and only shows up as noise
in the diff of the *next* change to that table. Alignment markers (`:---`,
`---:`, `:---:`) are preserved, and tables inside fenced code blocks are left
alone so a page can show an unformatted one as an example.

Git-ignored files are skipped, and so are the symlinked agent instruction files,
which are checked through their target.
→ [Documentation conventions](../Index.md#conventions-of-this-documentation)

## Repository initialization

`checkRepositoryInitialization` runs
[`Build/Scripts/initializeRepository.sh`](../../Build/Scripts/initializeRepository.sh)
against a throwaway copy of the working tree, once per repository reference, and
asserts the outcome: the composer package name, the extension key, the PSR-4
prefixes, the namespaces declared in the PHP files, that no dependency package
name was rewritten, that no masking placeholder survived, that no template
identifier is left anywhere, and that the markdown tables are still formatted.

That last one is not cosmetic. A cell holding an identifier changes width when
the identifier is renamed, so a longer repository name leaves the tables
unaligned and `checkMarkdownTables` fails in the first pull request of the new
repository, on a file nobody touched. The script reformats them, and this
asserts it — the assertion goes red on all six references when the step is
removed.

It also asserts that `--dry-run` changes nothing, and that initializing a second
time to the same reference is recognized and does nothing — the
[initialize workflow](../../.github/workflows/initialize.yml) triggers on more
than one event.

The references are **derived from the current package name**, not hardcoded, so
the gate keeps testing the right thing in a repository created from this
template. Three of them deliberately contain the current repository name, as a
prefix, a suffix and in the middle: that is the case which regressed, and the
reason the replacements are
[one pass rather than a sequence](../workflow/repository-initialization.md#the-replacements-are-one-pass-not-a-sequence).

The gate takes about half a minute, which is why it is worth knowing what it is
buying: the script runs exactly once per repository created from this template,
in a job nobody watches, and a wrong identifier produces a repository that
cannot resolve its own dependencies.

> [!NOTE]
> This is why `initializeRepository.sh` reads `composer.json` with `php` and not
> with `jq` — the container images have no `jq`, and a gate that cannot run the
> script it verifies is worth nothing. `setVersion.sh` follows it, which is what
> lets `-s setVersion` run a release step in a container as well.

What it does not cover: the bare owner. That is rewritten too, but it also
legitimately survives inside dependency package names, so "is it gone" is not a
property that can be asserted. The dependency assertion covers the part that
actually breaks a repository.

## Continuous integration

[`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) runs everything for
a pull request, with the core version as a **matrix dimension** rather than one
workflow per core version. Every step calls `Build/Scripts/runTests.sh`, so a
gate behaves identically in CI and on a developer machine.

The jobs are staged, cheapest and most likely to fail first:

```
quality ─┐
phpstan ─┤
lint    ─┼─> unit ─> functional (SQLite) ─> functional (MySQL, MariaDB, Postgres)
         │
docs ────┘
```

| Job                 | Matrix                                   | Runs                                        |
|---------------------|------------------------------------------|---------------------------------------------|
| `quality`           | lowest PHP, one core version             | The gates that inspect source files         |
| `phpstan`           | lowest PHP × both core versions          | The one gate configured per core version    |
| `lint`              | all PHP versions × both core versions    | `lintPhp`                                   |
| `unit`              | edge PHP versions × both core versions   | `unit`, `unitRandom`                        |
| `functional-sqlite` | edge PHP versions × both core versions   | `functional -d sqlite`                      |
| `functional-dbms`   | edge PHP × both cores × 4 DBMS — 16 jobs | `functional` against each database          |
| `documentation`     | —                                        | `renderDocumentation`, uploads the artifact |

Two decisions are worth knowing:

- **The DBMS matrix is gated on SQLite.** It is the expensive part, sixteen jobs
  each starting a database container. Running it only after the same tests pass
  on SQLite for both core versions means a defect that is not DBMS specific is
  reported by four jobs instead of twenty.
- **The version independent gates run once, not per core version and PHP
  version.** They inspect source files rather than the installed core, so
  repeating them tests the same files again. Only `phpstan` is genuinely per
  core version.

### Why CI passes `-b docker`

Every `runTests.sh` invocation in the workflows passes `-b docker`, and
[`initialize.yml`](../../.github/workflows/initialize.yml) hands
`--container-bin=docker` to the initialization script for the same reason.

The script itself prefers **podman** and only falls back to docker. That default
is right and stays: podman-only machines are exactly what it is built for.
GitHub hosted runners happen to ship both, and that is the single place this
repository meets a broken combination — their podman/crun pairing has been
observed to abort the *first* container start of a job with

```
Error: OCI runtime error: crun: unknown version specified
```

and exit code 126. It is intermittent, hits any job, and is caused by neither
the runner image nor the testing image changing; a rerun onto another host
clears it. Selecting docker in the workflow avoids crun entirely and leaves the
script default and every local run untouched. **Drop the flag once GitHub stops
producing the mismatch** — it is a workaround for their fleet, not a property of
this repository.

Picking docker there has a consequence worth knowing, and it is why the SQLite
functional mount carries `mode=1777` in addition to `uid`/`gid`: docker runs the
container as `--user $(id -u)` with group 0, and on a runner the tmpfs comes up
`root:root` mode `0755`, so neither the owner nor the group bits apply and every
test fails with `unable to open database file`. Rootless podman is root inside
its user namespace and never saw it.

### The composer cache

The composer **download cache** is shared per PHP and core version, so the
repeated `composerUpdate` resolves against a warm cache instead of downloading
the dependency set again in every job.

It lives in `.cache/` at the repository root, and that location is load-bearing:
`runTests.sh -s composerUpdate` starts with `rm -rf .Build`, so a cache kept
under `.Build/` would be deleted before composer ever reads it. The job would
still save it on the way out, so the cache step looks healthy in the run log
while never once being used — locally the same applies, and every dependency
install re-downloads the whole set. The phpstan result cache sits next to it for
the same reason. **Do not move either back under `.Build/`.**

What is deliberately *not* symmetric is who keeps it: `composerUpdate` deletes
`.cache/` **locally** and keeps it in CI, guarded by the same `IS_CORE_CI` the
rest of the script uses. The two contexts differ in what the cache can collide
with. A CI job starts from an empty checkout, installs once and ends; a working
copy switches between the core versions for months, and that switch changes the
major version of `typo3/class-alias-loader` — v13 resolves `^1.2`, v14 resolves
`^2.0.1`.

The local clear is a **precaution rather than a fix for a reproduced defect**.
Switching back and forth four times does not fail today; what it buys is that an
install never resolves against a cache belonging to the other major, which is a
class of failure that costs far more to recognize than the one download it
costs to avoid — of a dependency set that was going to be replaced anyway.

CI is the safety net, not the first run — the gates are cheap enough to run
locally before pushing.

### Commenting on a pull request from a fork

[`.github/workflows/pr-comment.yml`](../../.github/workflows/pr-comment.yml)
posts the link to the rendered documentation as a single comment, updated in
place on every push.

It is a **separate workflow on the `workflow_run` event**, and it has to be. A
pull request from a fork gets a read-only `GITHUB_TOKEN` and no secrets, so a
comment step inside `ci.yml` would work for branches in this repository and
silently fail for exactly the external contributors it is meant to serve.
`workflow_run` fires when `ci.yml` finishes, runs in the context of the default
branch of this repository rather than the fork, and its token may write even
though the token of the run that triggered it could not. No pull request code is
checked out or executed there, which is what makes the write permission safe —
and it is why `pull_request_target` is *not* used.

Two consequences:

1. The file only takes effect once it is **on the default branch**. Changing it
   in a pull request does not change the behaviour of that pull request.
2. `github.event.workflow_run.pull_requests` is empty for a fork, so the pull
   request number travels in the `pull-request-context` artifact written by
   `ci.yml`.

## See also

- [Development environment](environment.md)
- [Dual core setup](dual-core-setup.md)
- [Testing](../testing/Index.md)
- [Pull requests](../workflow/pull-requests.md)
