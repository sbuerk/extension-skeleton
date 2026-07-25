# Releasing

Two scripts in [`Build/Scripts/`](../../Build/Scripts) drive the release. Both
always operate on the repository root, no matter from where they are called, and
both show all options with `--help`.

## `setVersion.sh` — apply a version

Applies a version and its derived variants to every file carrying one: the
`COMPOSER_ROOT_VERSION` in `Build/Scripts/runTests.sh`, `extra.typo3/cms.version`
and `extra.branch-alias` in `composer.json`, the `version` in `ext_emconf.php`,
the `VERSION` file and — discovered dynamically, none has to exist — the
functional test [fixture extensions](../testing/fixture-extensions.md) below
`Tests/Functional/Fixtures/Extensions/`.

```bash
# Release version 1.2.0 (X.Y.Z, no branch-alias update).
Build/Scripts/setVersion.sh 1.2.0 release

# Next development version after it (X.Y.W-dev, branch-alias X.Y.x-dev).
Build/Scripts/setVersion.sh 1.2.1 post-release

# Force a plain development version, for example when branching.
Build/Scripts/setVersion.sh 1.3.0 dev

# Show every change without touching a file.
Build/Scripts/setVersion.sh 1.2.0 release --dry-run
```

The script only edits working-tree files; it performs no git or network
operations.

It reads and writes `composer.json` with **php**, not with `jq`, so it can also
be run through the container wrapper on a host that has neither:

```bash
Build/Scripts/runTests.sh -s setVersion -- 1.2.0 release
```

Everything after `--` is passed to the script unchanged, `--dry-run` included.
Both ways produce the same result — the wrapper only adds the container. The
same reasoning applies to
[repository initialization](repository-initialization.md), which a quality gate
runs inside a container where `jq` does not exist.

## `release.sh` — orchestrate the release

Drives the full two-phase workflow for one release version: branch, apply the
release version, commit `[RELEASE] X.Y.Z`, push, open a pull request, wait for
the checks, merge, tag and push the tag — and afterwards the same for the next
development version with `[TASK] Set version X.Y.W`.

It has two independent safety gates:

```bash
# Print the whole plan, change nothing at all.
Build/Scripts/release.sh 1.2.0 --dry-run

# Run the local steps for real, but only PRINT every remote operation.
Build/Scripts/release.sh 1.2.0

# Actually publish: push, pull request, merge, tag.
Build/Scripts/release.sh 1.2.0 --execute
```

Without `--execute` no push, no pull request, no merge and no tag ever happens,
so a release can safely be rehearsed. `git` and the GitHub CLI (`gh`) have to be
available and authenticated for `--execute`.

Pushing the tag triggers the [`publish`](../../.github/workflows/publish.yml)
workflow, which builds the TER artifact and creates the GitHub release.

## Before releasing

- Both core versions green across the full [gate matrix](../development/quality-gates.md).
- Changelog entries for the version in place, see
  [Changelog and documentation](changelog-and-documentation.md).
- `Build/Scripts/runTests.sh -s renderDocumentation` passing.

## See also

- [Pull requests](pull-requests.md)
- [Commit messages](commit-messages.md)
- [Repository initialization](repository-initialization.md)
