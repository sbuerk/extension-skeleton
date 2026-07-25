# Repository initialization

This repository is a GitHub **template repository**. A repository created from
it still carries the identifiers of the template — composer package name, TYPO3
extension key, PHP namespaces and the extension title — and has to be
initialized once with the identifiers of the new repository.

## Derived identifiers

All of them are derived from the `<owner>/<repository>` reference of the new
repository. For `vendor/some-repository-name` the result is:

| Identifier                    | Value                                                             |
|-------------------------------|-------------------------------------------------------------------|
| Composer package name         | `vendor/some-repository-name`                                     |
| TYPO3 extension key           | `some_repository_name`                                            |
| PHP root namespace            | `VENDOR\SomeRepositoryName\`                                      |
| Core version aware namespaces | `VENDOR\SomeRepositoryName\Core13\`, `…\Core14\`                  |
| Test namespace                | `VENDOR\SomeRepositoryName\Tests\`                                |
| Extension title               | `Some Repository Name`                                            |
| Repository URLs               | `homepage`, `support.issues`, `support.source` in `composer.json` |

The extension key is normalized to lowercase, with `-`, `.` and spaces turned
into `_`.

## Automatically, when creating the repository from the template

Creating a repository from this template starts the
[`initialize`](../../.github/workflows/initialize.yml) workflow. It runs the
initialization script with the `<owner>/<repository>` reference of the new
repository and pushes the result as a single `[TASK] Adjust repository` commit.

Nothing else has to be done — just pull that commit into an already existing
local clone. Should the workflow not have been started, it can be started
manually from the **Actions** tab of the new repository, or the clone can be
initialized as described below.

## Manually, in a clone of the repository

```bash
git clone git@github.com:vendor/some-repository-name.git
cd some-repository-name

# See what would be changed ...
Build/Scripts/initializeRepository.sh vendor/some-repository-name --dry-run

# ... and apply it, including the coding guidelines on the result.
Build/Scripts/initializeRepository.sh vendor/some-repository-name

git add -A
git commit -m '[TASK] Adjust repository'
git push
```

The script always operates on the repository root, no matter from where it is
called, and reads the values to replace from `composer.json`. It is therefore
idempotent and can be run again later to rename an already initialized
repository. `Build/Scripts/initializeRepository.sh --help` shows all options.

## Two constraints worth knowing

**GitHub Actions workflow files must not contain the extension identifiers.**
The `GITHUB_TOKEN` of an Actions run may not update files below
`.github/workflows/`, so `Build/Scripts/initializeRepository.sh` skips them and
warns when one still carries an identifier. Derive such values at runtime
instead, as [`publish.yml`](../../.github/workflows/publish.yml) does when it
reads the extension key from `composer.json`.

**The initialization applies the coding guidelines itself.** Renaming the PHP
namespace changes the alphabetical order of the `use` statements, so the result
would otherwise fail the `cgl` gate. The script installs the dependencies when
they are missing and runs `Build/Scripts/runTests.sh -s cgl` at the end, which
needs a container runtime. Without one it skips the step with a hint;
`--skip-cgl` skips it deliberately. In both cases run
`Build/Scripts/runTests.sh -s cgl` before committing.

`--container-bin=docker|podman` picks the runtime for that step and is passed
on as `-b`; without it the test runner keeps its own preference, which is
podman when it is installed. The
[initialize workflow](../../.github/workflows/initialize.yml) passes `docker`,
because the podman of GitHub hosted runners aborts container starts
intermittently and this job gets exactly one attempt per repository — see
[why CI passes `-b docker`](../development/quality-gates.md#why-ci-passes--b-docker).

**It reformats the markdown tables for the same reason.** A table cell holding
an identifier changes width when that identifier is renamed, and a longer
repository name is enough to break the alignment the `checkMarkdownTables` gate
requires — the first pull request in the new repository then fails on a file
nobody touched. The script therefore reformats every markdown file it rewrote,
using [`Build/Scripts/MarkdownTableFormatter.php`](../../Build/Scripts/MarkdownTableFormatter.php),
the algorithm of that gate.

Unlike `cgl` this step does **not** go through `runTests.sh`. It runs in a fresh
repository where no dependency set is installed and there may be no container
runtime at all, which is why the formatter is a file of its own and requires
nothing — neither the composer autoloader nor an installed dependency. Keep it
that way; the gate script adds the traversal and the reporting on top of it.

## Identifiers that must survive initialization

Not every occurrence of a template identifier may be rewritten. The bare owner
(`sbuerk`) and the bare vendor namespace (`SBUERK`) are replaced too, so the
template author does not stay behind in prose, author fields and namespaces.
That replacement is literal, and it would otherwise also hit things which are
not identifiers of this repository at all:

| Token                                | Where it appears                                                                                                                                  |
|--------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------|
| `sbuerk/fixture-packages`            | `require-dev`, `allow-plugins` and `extra` in `composer.json`                                                                                     |
| `sbuerk/typo3-site-based-test-trait` | `require-dev` in `composer.json`                                                                                                                  |
| `SBUERK\TYPO3\Testing\…`             | The base test case and every site based test                                                                                                      |
| `SBUERK\AvailableFixturePackages`    | [`Build/phpunit/FunctionalTestsBootstrap.php`](../../Build/phpunit/FunctionalTestsBootstrap.php) — the class the fixture package plugin generates |

Renaming any of them produces a repository that no longer resolves its own
dependencies. `Build/Scripts/initializeRepository.sh` therefore masks them with
a placeholder before applying the replacements and restores them afterwards.

Both sources are **derived, not hardcoded**, so a dependency added later is
covered without editing the script:

1. Every dependency package name in `composer.json` — a dependency name is never
   an identifier of this repository.
2. Every `<VendorNamespace>\<Segment>` occurring in the working tree whose
   segment is not this repository's own package namespace. That is what protects
   the PHP namespaces of dependencies published under the same vendor.

The masking happens on a copy, which is why `--dry-run` reports exactly what a
real run would change.

> [!TIP]
> `checkRepositoryInitialization` asserts that the identifiers come out right,
> but it does not install anything. The deeper test is to run the initialization
> into a throwaway clone and let the whole gate matrix judge the result —
> `composerUpdate`, `cgl`, `phpstan`, `unit`, `functional`. A missed token shows
> up there as a fatal error, not as a subtle diff. Note that `cgl -n` fails on
> the raw result by design: renaming the namespace reorders the `use` statements,
> which is why the script runs the fixer at the end unless `--skip-cgl` is given.

The same applies in the other direction to
[fixture extensions](../testing/fixture-extensions.md): `tests/example-fixture`,
`tests_example_fixture` and `TESTS\ExampleFixture\` are deliberately chosen so
they share no token with the template identifiers, which keeps them untouched by
design. Keep new fixtures free of them too.

## The replacements are one pass, not a sequence

The replacement list is ordered from the most specific pattern to the least, so
that a short pattern cannot consume part of a longer one — the full package name
`sbuerk/extension-skeleton` is handled before the bare repository name
`extension-skeleton`. Ordering alone is not enough, because a *new* identifier
may contain the *old* one whenever the new repository name does:

| Repository reference                  | Contains the template name | Rewritten correctly |
|---------------------------------------|----------------------------|---------------------|
| `vendor/some-repository-name`         | no                         | yes                 |
| `sbuerk/my-extension-skeleton`        | yes, as a suffix           | yes                 |
| `sbuerk/extension-skeleton-foo`       | yes, as a prefix           | yes                 |
| `sbuerk/test-extension-skeleton-demo` | yes, in the middle         | yes                 |

Applied one after the other into the same buffer, the bare repository name would
find `extension-skeleton` inside the `sbuerk/my-extension-skeleton` that the
previous replacement had just written, and expand it a second time to
`sbuerk/my-my-extension-skeleton`.

Every search is therefore replaced by a **placeholder**, and the placeholders are
resolved to their final values only once the whole list has been processed — the
same round trip the protected tokens use, in the other direction. A placeholder
contains no identifier, so nothing written during a pass can be rewritten again.

Any new replacement added to the list has to keep that property. Writing a final
value directly makes it visible to every search that follows.

The `checkRepositoryInitialization` gate holds it to that: it initializes a
throwaway copy of the working tree under each of the references in the table
above and asserts the result, so a replacement added later cannot quietly
reintroduce the double rewrite.
→ [Repository initialization gate](../development/quality-gates.md#repository-initialization)

## See also

- [Releasing](releasing.md)
- [Development environment](../development/environment.md)
