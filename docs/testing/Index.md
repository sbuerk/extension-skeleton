# Testing

Both test suites run through [`Build/Scripts/runTests.sh`](../../Build/Scripts/runTests.sh)
and must pass for **both** supported TYPO3 versions.

| Page                                              | Contents                                                                                                                  |
|---------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------|
| [PHPUnit configuration](phpunit-configuration.md) | Where `Build/phpunit/*` comes from, the deliberate deviations from the testing framework template, the strictness policy. |
| [Unit tests](unit-tests.md)                       | Layout and conventions, data providers, core version aware tests, testing injected classes.                               |
| [Functional tests](functional-tests.md)           | The base test case, databases, container assertions, fixtures.                                                            |
| [Fixture extensions](fixture-extensions.md)       | Test-only extensions below `Tests/Functional/Fixtures/Extensions/`, loaded by composer package name.                      |
| [Site based tests](site-based-tests.md)           | Site configuration with several languages and frontend sub-requests.                                                      |
| [Environment state](environment-state.md)         | Application type and language context for functional tests.                                                               |

## Quick start

```bash
# Unit tests.
Build/Scripts/runTests.sh -s unit

# Unit tests in random order.
Build/Scripts/runTests.sh -s unitRandom

# Functional tests on SQLite (no database container required).
Build/Scripts/runTests.sh -s functional -d sqlite

# A single class or method — note the "--" separator.
Build/Scripts/runTests.sh -s functional -d sqlite -- --filter ExtensionLoadedTest
```

## The two tests that must never be dropped

Two of the tests in this repository are not about a feature, and both carry a
class level docblock saying so.

| Test                                                                                     | Suite      | What it actually proves                                                     |
|------------------------------------------------------------------------------------------|------------|-----------------------------------------------------------------------------|
| [`Tests/Unit/VersionCompatTest`](../../Tests/Unit/VersionCompatTest.php)                 | unit       | The suite ran against the core version it was asked to run against.         |
| [`Tests/Functional/ExtensionLoadedTest`](../../Tests/Functional/ExtensionLoadedTest.php) | functional | The same, plus: a complete TYPO3 instance with this extension boots at all. |

Both use
[`ExtensionCoreVersionCompatTestsTrait`](../../Tests/ExtensionCoreVersionCompatTestsTrait.php),
which asserts that the running major version is supported and — through the
`not-core-13` and `not-core-14` groups — that `-t 13` really is v13 and `-t 14`
really is v14. `-t` selects a core version but installs nothing, so without this
a stale `.Build/` produces a green run that proved nothing. Running a suite with
`-t 14` while the v13 set is installed fails it with
`Failed asserting that 13 is identical to 14`.

The functional one earns its keep before its assertions run: booting the
instance compiles the dependency injection container, executes the extension
bootstrap, loads and **migrates** the TCA — the migration raises
`E_USER_DEPRECATED` for everything it had to change, which this suite converts
into a failure — and derives the database schema. An unresolvable service
argument or a TCA structure the other core version has migrated away is reported
there, not in whichever feature test happens to touch it first.

It does not cover FormEngine rendering. That TCA loads and migrates is not the
same as the backend being able to render a form from it.

## Rules that apply to every test

- Test classes are `final`; test methods carry `#[Test]` and are **not** prefixed
  with `test`. Enforced by the `checkTestMethodsPrefix`
  [gate](../development/quality-gates.md#test-method-naming).
- Notices, warnings and deprecations **fail** the suite. Fix the cause, do not
  silence it — see [strictness policy](phpunit-configuration.md#strictness-policy).
- Functional tests extend `AbstractFunctionalTestCase`, never the testing
  framework `FunctionalTestCase` directly — see
  [Site based tests](site-based-tests.md#no-test-extends-the-framework-test-case-directly).
- Core version aware tests live in a `Core13/` or `Core14/` subdirectory and
  carry `#[Group('not-core-<other version>')]` — see
  [Dual core setup](../development/dual-core-setup.md#test-grouping).
- Data provider keys are named, so a failing case is identifiable from the
  output alone.

## See also

- [Documentation index](../Index.md)
- [Development](../development/Index.md)
- [Architecture](../architecture/Index.md)
