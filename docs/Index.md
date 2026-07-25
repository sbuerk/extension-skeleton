# Developer documentation

Technical documentation for developers working **on** this extension: how the
code base is structured, which rules apply to it, how to run the tooling and how
changes get released.

Documentation for people **using** the extension lives in
[`Documentation/`](../Documentation) and is rendered to docs.typo3.org.
[`README.md`](../README.md) is the short overview,
[`CONTRIBUTING.md`](../CONTRIBUTING.md) the entry point that links here.

## [Development](development/Index.md)

| Page                                                  | Contents                                                                     |
|-------------------------------------------------------|------------------------------------------------------------------------------|
| [Development environment](development/environment.md) | `runTests.sh`, container runtimes, suites and options.                       |
| [Dual core setup](development/dual-core-setup.md)     | Running against TYPO3 v13 and v14, and the rule that avoids false positives. |
| [Quality gates](development/quality-gates.md)         | Every gate and its configuration, PHPStan per core version, CI.              |

## [Architecture](architecture/Index.md)

| Page                                                               | Contents                                                                                            |
|--------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------|
| [Core version aware code](architecture/core-version-aware-code.md) | `Classes/` vs `Core13/` vs `Core14/`, and how the right variant is selected.                        |
| [Dependency injection](architecture/dependency-injection.md)       | Symfony DI attributes, stateless services, the rules that apply.                                    |
| [Class design](architecture/class-design.md)                       | `final readonly`, method injection in abstract classes, data objects, the accepted PHPStan ignores. |

## [Testing](testing/Index.md)

| Page                                                      | Contents                                                               |
|-----------------------------------------------------------|------------------------------------------------------------------------|
| [PHPUnit configuration](testing/phpunit-configuration.md) | Where the config comes from, deliberate deviations, strictness policy. |
| [Unit tests](testing/unit-tests.md)                       | Layout, conventions, core version aware tests.                         |
| [Functional tests](testing/functional-tests.md)           | Base test case, databases, container assertions.                       |
| [Fixture extensions](testing/fixture-extensions.md)       | Test-only extensions loaded by composer package name.                  |
| [Site based tests](testing/site-based-tests.md)           | Site configuration, languages, frontend sub-requests.                  |
| [Environment state](testing/environment-state.md)         | Application type and language context in functional tests.             |

## [Workflow](workflow/Index.md)

| Page                                                                   | Contents                                                |
|------------------------------------------------------------------------|---------------------------------------------------------|
| [Commit messages](workflow/commit-messages.md)                         | TYPO3 core commit message conventions.                  |
| [Pull requests](workflow/pull-requests.md)                             | Branching, the pre-flight checklist, review.            |
| [Changelog and documentation](workflow/changelog-and-documentation.md) | reST changelog entries, rendering, the core changelogs. |
| [Releasing](workflow/releasing.md)                                     | `setVersion.sh` and `release.sh`.                       |
| [Repository initialization](workflow/repository-initialization.md)     | Turning the template into a concrete extension.         |

## Conventions of this documentation

- Every directory has an `Index.md` linking its pages; every page ends with a
  *See also* section.
- Pages document **why**, not just **what** — the reasoning is the part that does
  not survive in code.
- A change updates the page covering it in the same commit.
- **Tables are always formatted.** Every cell is padded so the pipes line up, and
  the separator row is as wide as the widest cell in its column:

  ```markdown
  <!-- no -->
  | Header 1 | Header 2 |
  |----------|----------|
  | Value 1 with long text | Value 2 |

  <!-- yes -->
  | Header 1               | Header 2 |
  |------------------------|----------|
  | Value 1 with long text | Value 2  |
  ```

  Both render identically, which is exactly the problem: an unaligned table is
  invisible until someone edits it, and then the reflow touches every row and
  buries the actual change in the diff. Alignment markers (`:---`, `---:`,
  `:---:`) are kept and padded the same way.
