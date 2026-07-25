# TYPO3 extension `extension_skeleton`

TYPO3 CMS extension skeleton supporting TYPO3 v13 and v14 within one code base,
including core version aware class loading, the container based test and
quality gate harness, the GitHub Actions workflows and the release tooling.

- **Package name**: `sbuerk/extension-skeleton`
- **Extension key**: `extension_skeleton`
- **Repository**: https://github.com/sbuerk/extension-skeleton
- **License**: GPL-2.0-or-later

## Creating a repository from this template

This repository is a GitHub **template repository**. A new extension starts by
creating a repository from it, either on the command line or in the web
interface — the result is the same.

Unlike a fork, a repository created from a template starts with a **single
commit** and carries none of the history of this repository.

### With the GitHub CLI

```bash
gh repo create <owner>/<repository> \
  --template sbuerk/extension-skeleton \
  --public \
  --description "<description>" \
  --clone
```

| Placeholder     | Is                                                                                   |
|-----------------|--------------------------------------------------------------------------------------|
| `<owner>`       | The user or organization the repository belongs to. Omitted, the authenticated user. |
| `<repository>`  | The repository name, which every identifier of the extension is derived from.        |
| `<description>` | The repository description, shown on GitHub and written into `composer.json`.        |

`--public` can be `--private` instead, or `--internal` for an organization on
GitHub Enterprise. `--clone` clones the new repository into the current
directory; leave it out to only create it.

Explicitly in a user namespace:

```bash
gh repo create sbuerk/my-new-typo3-extension \
  --template sbuerk/extension-skeleton \
  --public \
  --description "My super cool new extension"
```

In an organization — the organization has to allow repository creation for the
authenticated user, and `--team` may be added to grant a team access right away:

```bash
gh repo create my-organization/my-new-typo3-extension \
  --template sbuerk/extension-skeleton \
  --public \
  --description "My super cool new extension"
```

Omitting the owner is the short form, and creates the repository in the
namespace of the authenticated user:

```bash
gh repo create my-new-typo3-extension \
  --template sbuerk/extension-skeleton \
  --public \
  --description "My super cool new extension"
```

→ [`gh repo create`](https://cli.github.com/manual/gh_repo_create) for the full
list of options.

### In the web interface

1. Open <https://github.com/sbuerk/extension-skeleton>.
2. Click **Use this template** above the file list, and choose
   **Create a new repository**.
3. Pick the **Owner** — a user or an organization.
4. Enter the **Repository name**, and optionally a description.
5. Choose the visibility: **Public**, **Private** or **Internal**.
6. Click **Create repository from template**.

**Include all branches** is not needed: everything lives on the default branch.

→ [Creating a repository from a template](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-repository-from-a-template)

### What happens next

Creating the repository starts the [`initialize`](.github/workflows/initialize.yml)
workflow, which rewrites every identifier inherited from the template to the one
derived from the new repository name, and pushes the result. See the next
section.

> [!NOTE]
> This section and the next one describe **this template**, not the extension
> built from it. Once your repository is initialized, both can be deleted from
> its `README.md`.

## Repository initialization

A repository created from this template still carries the identifiers of the
template — composer package name, TYPO3 extension key, PHP namespaces and the
extension title — and has to be initialized once with the identifiers of the new
repository.

Creating a repository from this template starts the
[`initialize`](.github/workflows/initialize.yml) workflow, which does exactly
that and pushes the result as a single `[TASK] Adjust repository` commit.
**Normally nothing else has to be done** — just pull that commit.

To do it by hand in a clone instead:

```bash
# See what would be changed ...
Build/Scripts/initializeRepository.sh vendor/some-repository-name --dry-run

# ... and apply it, including the coding guidelines on the result.
Build/Scripts/initializeRepository.sh vendor/some-repository-name
```

For `vendor/some-repository-name` this yields the composer package name
`vendor/some-repository-name`, the extension key `some_repository_name` and the
PHP root namespace `VENDOR\SomeRepositoryName\`.

→ [Repository initialization](docs/workflow/repository-initialization.md) for
the full list of derived identifiers, the workflow and the two constraints to
know about.

## Compatibility

| Branch | Extension | TYPO3     | PHP       |
|--------|-----------|-----------|-----------|
| main   | 1.x       | v13 / v14 | 8.2 - 8.5 |

## Installation

```bash
composer require sbuerk/extension-skeleton
```

As long as no stable version has been released, require the development version
of the main branch explicitly:

```bash
composer require sbuerk/extension-skeleton:^1.0@dev
```

This additionally requires `minimum-stability: "dev"` together with
`prefer-stable: true` in the root `composer.json` file.

## Documentation

| For                        | Where                                                         |
|----------------------------|---------------------------------------------------------------|
| Users and integrators      | [`Documentation/`](Documentation), rendered to docs.typo3.org |
| Developers and maintainers | [`docs/`](docs/Index.md)                                      |
| Contributors, entry point  | [`CONTRIBUTING.md`](CONTRIBUTING.md)                          |
| AI coding agents           | [`AGENTS.md`](AGENTS.md)                                      |

```bash
# Render once, as CI does. Must pass without errors.
Build/Scripts/runTests.sh -s renderDocumentation

# Serve it while writing, re-rendering on every save, on port 1337.
Build/Scripts/runTests.sh -s watchDocumentation
```

The rendered output is written to the git-ignored `Documentation-GENERATED-temp/`
directory.

## Development

All tests and quality tools run in containers through the
[`Build/Scripts/runTests.sh`](Build/Scripts/runTests.sh) wrapper. The only
requirement on the host is a container runtime — **podman** (preferred) or
**docker**.

```bash
# Install dependencies for TYPO3 v13 on PHP 8.2 (default matrix).
Build/Scripts/runTests.sh -t 13 -p 8.2 -s composerUpdate

# Quality gates.
Build/Scripts/runTests.sh -s cgl -n
Build/Scripts/runTests.sh -s phpstan
Build/Scripts/runTests.sh -s lintPhp

# Tests.
Build/Scripts/runTests.sh -s unit
Build/Scripts/runTests.sh -s functional -d sqlite

# All available options.
Build/Scripts/runTests.sh -h
```

Everything has to pass for **both** TYPO3 v13 and v14, each after the matching
`composerUpdate` — see
[Dual core setup](docs/development/dual-core-setup.md).

→ [`CONTRIBUTING.md`](CONTRIBUTING.md) for the contribution workflow ·
[`docs/`](docs/Index.md) for the full developer documentation

## License

This extension is published under the [GPL-2.0-or-later](LICENSE) license.
