# Contributing

Contributions are welcome. This document is the entry point: it covers what you
need to get started and links to the detailed developer documentation in
[`docs/`](docs/Index.md).

Source code and issue tracker are hosted on GitHub:
[sbuerk/extension-skeleton](https://github.com/sbuerk/extension-skeleton).

## Table of contents

- [Getting started](#getting-started)
- [Quality gates](#quality-gates)
- [Running tests](#running-tests)
- [Code rules](#code-rules)
- [Commit messages](#commit-messages)
- [Pull request checklist](#pull-request-checklist)
- [Documentation](#documentation)
- [Releasing](#releasing)
- [AI-assisted contributions](#ai-assisted-contributions)
- [Repository initialization](#repository-initialization)

## Getting started

All tests and quality tools run in containers through the
[`Build/Scripts/runTests.sh`](Build/Scripts/runTests.sh) wrapper. The only
requirement on the host is a container runtime — **podman** (preferred) or
**docker**. Neither PHP nor Composer needs to be installed.

```bash
# Install dependencies for TYPO3 v13 on PHP 8.2 (default matrix).
Build/Scripts/runTests.sh -t 13 -p 8.2 -s composerUpdate

# All available suites and options.
Build/Scripts/runTests.sh -h
```

> [!IMPORTANT]
> The dependency set installed in `.Build/` must match the core version a tool
> is run for. `-t` selects the version but installs nothing — only
> `composerUpdate` does. Running a suite with a different core version installed
> than selected reports false positives.

→ [Development environment](docs/development/environment.md) ·
[Dual core setup](docs/development/dual-core-setup.md)

## Quality gates

The same gates run locally and in the GitHub Actions workflows for TYPO3 v13
and v14:

```bash
Build/Scripts/runTests.sh -s cgl          # coding guidelines, "-n" to check only
Build/Scripts/runTests.sh -s phpstan      # static analysis, level 8
Build/Scripts/runTests.sh -s lintPhp      # PHP linting
Build/Scripts/runTests.sh -s composerValidate
Build/Scripts/runTests.sh -s checkBom
Build/Scripts/runTests.sh -s checkExceptionCodes
Build/Scripts/runTests.sh -s checkMarkdownTables
Build/Scripts/runTests.sh -s checkRepositoryInitialization
Build/Scripts/runTests.sh -s checkTestMethodsPrefix
```

PHPStan is configured per core version and has a baseline per core version. A
growing baseline is a defect — prefer fixing the finding.

→ [Quality gates](docs/development/quality-gates.md)

## Running tests

```bash
Build/Scripts/runTests.sh -s unit
Build/Scripts/runTests.sh -s unitRandom
Build/Scripts/runTests.sh -s functional -d sqlite

# A single class or method — note the "--" separator.
Build/Scripts/runTests.sh -s functional -d sqlite -- --filter DummyTest
```

Test methods must **not** be prefixed with `test`; use the PHPUnit `#[Test]`
attribute and a descriptive method name. The suites are configured to be as hard
breaking as possible: notices, warnings, deprecations, a test without an
assertion and output written during a test all fail the run by design.

Functional tests extend `AbstractFunctionalTestCase`, never the testing framework
`FunctionalTestCase` directly — the chain roots in the test case of
`sbuerk/typo3-site-based-test-trait`, which is what makes site configurations and
frontend sub-requests available everywhere.

→ [PHPUnit configuration](docs/testing/phpunit-configuration.md#strictness-policy)

→ [Testing](docs/testing/Index.md) ·
[Unit tests](docs/testing/unit-tests.md) ·
[Functional tests](docs/testing/functional-tests.md) ·
[Site based tests](docs/testing/site-based-tests.md)

## Code rules

The extension supports TYPO3 v13 and v14 from one code base. The rules that make
that work:

- **Version differences split classes, they do not add conditionals.**
  `Classes/` holds everything working on all supported versions; `Core13/` and
  `Core14/` hold one implementation each, and only the matching directory is
  registered in the dependency injection container.
  → [Core version aware code](docs/architecture/core-version-aware-code.md)
- **Services are stateless and wired with Symfony DI attributes on the class** —
  not with `Services.yaml`, not with service definitions in
  `Configuration/Services.php`. They are private unless something really has to
  fetch them from the container.
  → [Dependency injection](docs/architecture/dependency-injection.md)
- **Classes are `final readonly`** where a framework constraint does not prevent
  it. Abstract classes never use constructor injection — they use `#[Required]`
  `inject*()` methods, so the constructor stays free for extending classes.
  → [Class design](docs/architecture/class-design.md)
- **Models, entities, value objects and DTOs are data, not services** and always
  carry `#[Exclude]`, Extbase models included — directory based service
  registration cannot tell them apart, and the omission stays invisible until
  something type hints the class.
  → [Data objects are not services](docs/architecture/class-design.md#data-objects-are-not-services)

## Commit messages

This repository follows the **TYPO3 core commit message conventions**:

```
[TAG] Short imperative summary

A wrapped body (around 72 characters per line) explaining what the change
does and why it is needed.
```

Tags are `[FEATURE]`, `[TASK]`, `[BUGFIX]`, `[DOCS]` and `[RELEASE]`; breaking
changes are additionally prefixed with `[!!!]`. Aim for a subject of ~52
characters. An issue reference is not required, but must be verified when used.

→ [Commit messages](docs/workflow/commit-messages.md)

## Pull request checklist

Before opening a pull request, run every gate from
[Quality gates](#quality-gates), both test suites, and `renderDocumentation`
when anything below `Documentation/` changed — for **both** core versions
(`-t 13` and `-t 14`, each after the matching `composerUpdate`).

Add another DBMS (`-d mariadb -i 10.6`, `mysql`, `postgres`) when the change
touches queries, schema or TCA.

→ [Pull requests](docs/workflow/pull-requests.md) for the full command list

## Documentation

Two audiences, two places — both updated in the same commit as the change:

| Location                          | Audience                   | Format   |
|-----------------------------------|----------------------------|----------|
| [`Documentation/`](Documentation) | Users and integrators      | reST     |
| [`docs/`](docs/Index.md)          | Developers and maintainers | Markdown |

```bash
# Render once, as CI does. Must pass without errors.
Build/Scripts/runTests.sh -s renderDocumentation

# Serve it while writing, re-rendering on every save, on port 1337.
Build/Scripts/runTests.sh -s watchDocumentation
```

User facing changes need a changelog entry below
`Documentation/Changelog/<version>/` — `Feature-*.rst`, `Breaking-*.rst`,
`Deprecation-*.rst` or `Important-*.rst`.

Markdown tables are always **formatted**: cells padded so the pipes line up. An
unaligned table renders the same but reflows the whole table on the next edit,
burying the real change in the diff.

→ [Changelog and documentation](docs/workflow/changelog-and-documentation.md)

## Releasing

Two scripts drive the release: `Build/Scripts/setVersion.sh` applies a version to
every file carrying one, `Build/Scripts/release.sh` orchestrates branch, commit,
pull request, merge and tag. Nothing remote happens without `--execute`.

→ [Releasing](docs/workflow/releasing.md)

## AI-assisted contributions

Contributions developed with AI coding assistants are welcome. This project
follows the [TYPO3 Association policy on AI-assisted code][ai-policy], which is
currently a **draft under community review**:

- You are fully responsible for every line you submit, however it was produced.
  A model is a tool, not an author, and is never credited as one.
- Tag commits with `AI-assisted: <tool name>` when AI generated the structural
  logic, most of the lines, or structural configuration such as TCA. It is not
  expected for autocompletion, formatting or mechanical refactoring.
- Optionally sign off your commits (`git commit -s`) to certify the
  [Developer Certificate of Origin](https://developercertificate.org/). The
  policy recommends it; **this project does not require it**.
- Verify every TYPO3 API against the version you target — models frequently
  suggest deprecated or non-existent API.
- Review security-relevant code with extra care: generated code can look
  entirely plausible and still be wrong in ways review does not catch.

→ [Commit messages: attribution and AI disclosure](docs/workflow/commit-messages.md#attribution-and-ai-disclosure)

[`AGENTS.md`](AGENTS.md) is the instruction file for AI coding agents, with
`CLAUDE.md`, `GEMINI.md` and `.github/copilot-instructions.md` as symlinks to
it. It links into this document and into [`docs/`](docs/Index.md) rather than
repeating them, and adds what applies to agent work: the above, scratch files
below the git-ignored `.agent/`, and the quality gate matrix including the dual
core rule.

→ [Agent instructions](AGENTS.md)

## Repository initialization

This repository is a GitHub template repository. Turning a repository created
from it into a concrete extension is a single command, and normally happens
automatically through the [`initialize`](.github/workflows/initialize.yml)
workflow:

```bash
Build/Scripts/initializeRepository.sh vendor/some-repository-name --dry-run
Build/Scripts/initializeRepository.sh vendor/some-repository-name
```

→ [Repository initialization](docs/workflow/repository-initialization.md)

[ai-policy]: https://github.com/TYPO3-Documentation/Policy/pull/47
