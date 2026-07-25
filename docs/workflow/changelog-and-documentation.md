# Changelog and documentation

This repository carries documentation in two places, with different audiences:

| Location                                | Audience                                     | Format   | Shipped              |
|-----------------------------------------|----------------------------------------------|----------|----------------------|
| [`Documentation/`](../../Documentation) | Users and integrators of the extension       | reST     | yes                  |
| [`docs/`](../Index.md)                  | Developers and maintainers of the repository | Markdown | no (`export-ignore`) |

Both are updated as part of the change that makes them necessary, never
afterwards.

## Rendering the user documentation

The sources in `Documentation/` are rendered with the official TYPO3 rendering
container:

```bash
Build/Scripts/runTests.sh -s renderDocumentation
```

The rendered output is written to the git-ignored `Documentation-GENERATED-temp/`
directory. Rendering must pass without errors; the
`documentation` job of the [CI workflow](../../.github/workflows/ci.yml) runs the
same command on every pull request, uploads the result as an artifact, and
[comments the link](../../.github/workflows/pr-comment.yml) on the pull request.

### While writing

`watchDocumentation` renders once, then serves the result and re-renders on
every save, so the browser shows the page as it will be published instead of
reST that has to be imagined:

```bash
Build/Scripts/runTests.sh -s watchDocumentation
Build/Scripts/runTests.sh -s watchDocumentation 4711
```

It serves on port `1337` unless a different port is given as the first argument,
and it keeps running until ctrl-c. Files **added** while it runs are not picked
up — restart it after creating a changelog entry. It is a writing aid, not a
gate: `renderDocumentation` is what has to pass, because it fails on the first
error rather than serving the page anyway.

## Changelog entries

User facing changes need a changelog entry below
`Documentation/Changelog/<version>/`, named by change type:

| File pattern        | Use for                                                    |
|---------------------|------------------------------------------------------------|
| `Feature-*.rst`     | New functionality.                                         |
| `Breaking-*.rst`    | Changes requiring action from users of the extension.      |
| `Deprecation-*.rst` | Functionality marked for removal, with the migration path. |
| `Important-*.rst`   | Notable changes that are neither of the above.             |

Each version directory has an `Index.rst` listing its entries; add new files
there as well.

## The TYPO3 core changelogs

When working on compatibility — adopting a new API, reacting to a deprecation,
preparing for the next major — the authoritative source is the changelog set
shipped with the installed core:

```
.Build/vendor/typo3/cms-core/Documentation/Changelog/
```

Because it ships with the dependency, what is on disk depends on what is
installed — and it reaches only as far as the installed version. A package does
carry the changelogs of all **earlier** versions, so with TYPO3 v14 installed
both `13.*` and `14.*` are there, while a v13 installation has no `14.0/` at
all.

Installing the **highest** supported version therefore gives the complete set in
one step. Switching is only needed to read changelogs *newer* than the installed
version, never older ones. Reading is not running a gate: `composerUpdate` back
to the version you are working on before running anything — see
[Dual core setup](../development/dual-core-setup.md).

The rendered version is at
<https://docs.typo3.org/c/typo3/cms-core/main/en-us/Index.html>.

Read the actual entry rather than relying on memory, and cite it in the commit
message and in any `@todo` left behind for future version work. See
[Commit messages](commit-messages.md#referencing-typo3-behaviour-changes).

## See also

- [Commit messages](commit-messages.md)
- [Pull requests](pull-requests.md)
- [Releasing](releasing.md)
