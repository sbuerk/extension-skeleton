# Workflow

From a change in the working copy to a published release.

| Page                                                          | Contents                                                                                                          |
|---------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------|
| [Commit messages](commit-messages.md)                         | TYPO3 core commit message conventions: tags, subject length, body wrapping, footers, referencing core changelogs. |
| [Pull requests](pull-requests.md)                             | Branching, the local pre-flight checklist, review and history hygiene.                                            |
| [Changelog and documentation](changelog-and-documentation.md) | `Documentation/` vs `docs/`, reST changelog entries, rendering, the changelogs shipped with `typo3/cms-core`.     |
| [Releasing](releasing.md)                                     | `setVersion.sh` and `release.sh`, their safety gates, the publish workflow.                                       |
| [Repository initialization](repository-initialization.md)     | Turning a repository created from this template into a concrete extension.                                        |

## The short version

- Commit subjects are `[TAG] Imperative summary`, ~52 characters, body wrapped at
  ~72. A model is never credited as an author; substantial AI involvement is
  disclosed with an `AI-assisted:` trailer instead.
- A change is not done until the gates pass for **both** core versions and the
  documentation is updated in the same commit.
- User facing changes need a changelog entry below `Documentation/Changelog/`.
- Releases are rehearsed: `release.sh` changes nothing remote without
  `--execute`.

## See also

- [Documentation index](../Index.md)
- [Quality gates](../development/quality-gates.md)
- [Development](../development/Index.md)
