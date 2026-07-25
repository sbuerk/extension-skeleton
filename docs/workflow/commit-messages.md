# Commit messages

This repository follows the **TYPO3 core commit message conventions**.

## Format

```
[TAG] Short imperative summary

A wrapped body (around 72 characters per line) that explains what the
change does and, more importantly, why it is needed. Describe the
behaviour change and the motivation, not the line-by-line diff.
```

Rules:

- The subject line starts with a **tag** in square brackets, followed by a
  short summary in **imperative mood** ("Add", "Fix", "Rename"), capitalized
  and **without** a trailing period.
- Keep the subject concise — aim for **~52 characters**, ~72 at most.
- Separate subject and body with a single blank line.
- Wrap the body at around **72 characters** and explain the *what* and *why*.
- An issue reference is **not required**. Everything that may appear below the
  body is listed under [Footer trailers](#footer-trailers).
- References are **verified, not assumed** — check the issue exists and is the
  right one before writing it into the message.

## Tags

| Tag         | Use for                                                                    |
|-------------|----------------------------------------------------------------------------|
| `[FEATURE]` | A new feature or capability.                                               |
| `[TASK]`    | Maintenance, refactoring, tooling, tests and other non-functional changes. |
| `[BUGFIX]`  | A bug fix.                                                                 |
| `[DOCS]`    | Documentation-only changes.                                                |
| `[RELEASE]` | Release commits, created by [`release.sh`](releasing.md).                  |

Breaking changes are additionally prefixed with `[!!!]` in front of the tag, so
reviewers and users spot them immediately:

```
[!!!][TASK] Remove deprecated example accessor

Explain what breaks and how to migrate.
```

## Examples

```
[FEATURE] Add core version aware example service

[TASK] Raise minimum TYPO3 version to v13.4

[BUGFIX] Handle empty response payloads

[DOCS] Document the installation for classic mode
```

## Footer trailers

Trailers go at the very end of the message, after a blank line, one per line:

```
[FEATURE] Add core version aware example service

Explain what the change does and why it is needed.

Resolves: #123
AI-assisted: <tool name>
Signed-off-by: Firstname Lastname <mail@example.com>
```

| Trailer               | Use for                                                             | Status                                                                                                  |
|-----------------------|---------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------|
| `Resolves: #123`      | The GitHub issue the change closes.                                 | Optional, and **verified** when used.                                                                   |
| `AI-assisted: <tool>` | Naming the AI tool when it produced structural parts of the change. | **Expected** in the cases listed under [Attribution and AI disclosure](#attribution-and-ai-disclosure). |
| `Signed-off-by: …`    | Certifying the Developer Certificate of Origin.                     | Optional here, see [Sign-off is optional here](#sign-off-is-optional-here).                             |

The `[RELEASE]` and post-release `[TASK]` commits that
[`release.sh`](releasing.md) creates are subject-only and carry no trailers.

## Referencing TYPO3 behaviour changes

When a change reacts to something the TYPO3 core changed — a new API, a
deprecation, a breaking change — name it in the body and cite the changelog
entry. The changelogs ship with the installed core and are the authoritative
source:

```
.Build/vendor/typo3/cms-core/Documentation/Changelog/
```

Read the actual entry rather than relying on memory, and read it in full — a
"Breaking" entry usually documents the replacement API in the same file, and
often states that the removed option is still required on the older version.

> [!IMPORTANT]
> The changelogs reach only as far as the **installed** core version: with
> TYPO3 v13 installed the newest directory is `13.4.x` and there is no `14.0/`
> to read. A package does ship the changelogs of all earlier versions, so
> installing the highest supported version — v14 — puts both v13 and v14
> changelogs on disk at once.
>
> Looking something up is not running a gate. Read with v14 installed, then
> `composerUpdate` back to the version you are working on before running
> anything — see [Dual core setup](../development/dual-core-setup.md).

The rendered version is at
<https://docs.typo3.org/c/typo3/cms-core/main/en-us/Index.html>. See
[Changelog and documentation](changelog-and-documentation.md).

## Attribution and AI disclosure

> [!NOTE]
> This section summarizes the TYPO3 Association policy on AI-assisted code,
> which is a **draft under community review** at
> <https://github.com/TYPO3-Documentation/Policy/pull/47> (draft of 20 July
> 2026). Re-check the whole section against the final document once it is
> merged.

Commits are authored in a human voice, and **a model is never credited as an
author**: no `Co-authored-by:` trailer for an AI tool or model, and no
"Generated with …" notice.

That is not the same as hiding tool involvement. This repository follows the
TYPO3 Association policy on AI-assisted code, which asks for a **provenance
trailer** when AI produced the structural logic, roughly more than half the
lines of a commit, or structural configuration such as TCA or a database schema:

```
AI-assisted: <tool name>
```

It is **not** expected for incidental use — editor autocompletion, explaining
existing code, formatting, linting fixes, mechanical refactoring, or drafting a
message that was then reviewed and edited.

### Sign-off is optional here

The draft policy also recommends a `Signed-off-by:` trailer certifying the
[Developer Certificate of Origin](https://developercertificate.org/): that you
have the right to submit the contribution under this extension's license. It is
a human act, separate from the disclosure trailer, and applies whether or not a
tool was involved. `git commit -s` adds it.

```
Signed-off-by: Firstname Lastname <mail@example.com>
```

**This repository does not require it**, and TYPO3 Core does not use it either —
Gerrit certifies changes through `Change-Id`. It is documented because the
policy recommends it and because a repository created from this template may
well want it. Add it if you do; its absence is not a review finding.

→ [Agent instructions](../../AGENTS.md#ai-assisted-contributions)

## See also

- [Pull requests](pull-requests.md)
- [Changelog and documentation](changelog-and-documentation.md)
- [Releasing](releasing.md)
