# Functional tests

Functional tests live below [`Tests/Functional/`](../../Tests/Functional). They
boot a real TYPO3 instance with a database, so the dependency injection
container, TCA, the persistence layer and — where needed — frontend rendering
are available.

## Running

```bash
# Functional tests on SQLite (no database container required).
Build/Scripts/runTests.sh -s functional -d sqlite

# Functional tests against other database management systems.
Build/Scripts/runTests.sh -s functional -d mariadb -i 10.6
Build/Scripts/runTests.sh -s functional -d mysql -i 8.0
Build/Scripts/runTests.sh -s functional -d postgres -i 10

# A single class or method.
Build/Scripts/runTests.sh -s functional -d sqlite -- --filter ExtensionLoadedTest
```

SQLite is the fastest option and enough for most work. Run at least one other
DBMS before opening a pull request when the change touches queries, schema or
**TCA** — TYPO3 derives the schema from the TCA, so a TCA change is a schema
change.

### Database versions

`-i` selects the image version, and `runTests.sh -h` lists which ones are
accepted per DBMS: MariaDB `10.4` … `11.8`, MySQL `8.0` … `8.4`, PostgreSQL
`10` … `18`. The default is the oldest still supported version, so a run without
`-i` tests the floor of the version range rather than the comfortable case.

PostgreSQL 18 moved its data directory and refuses to start when a mount sits at
the old location. The wrapper places the mount one level higher for `18` and
above, which is the mount point the image documents for that case — nothing to
configure, but it explains why that one version is special cased.

Remember to run both core versions, each after the matching `composerUpdate` —
see [Dual core setup](../development/dual-core-setup.md).

## The test that proves the instance boots

[`Tests/Functional/ExtensionLoadedTest`](../../Tests/Functional/ExtensionLoadedTest.php)
asserts little and is worth a lot: it cannot reach its assertions without
booting a complete TYPO3 instance with this extension installed, which compiles
the dependency injection container, executes the extension bootstrap, loads and
migrates the TCA and derives the database schema. An unresolvable service
argument or a TCA structure the other core version has migrated away fails
there rather than in whichever feature test touches it first.

It is **never removed** —
see [the two tests that must never be dropped](Index.md#the-two-tests-that-must-never-be-dropped).

## The base test case

Functional tests extend
[`Tests/Functional/AbstractFunctionalTestCase`](../../Tests/Functional/AbstractFunctionalTestCase.php),
never the testing framework class directly. It takes care of loading the
extension itself into the test instance:

```php
use SBUERK\TYPO3\Testing\TestCase\FunctionalTestCase;

abstract class AbstractFunctionalTestCase extends FunctionalTestCase
{
    protected array $testExtensionsToLoad = [
        'sbuerk/extension-skeleton',
    ];
}
```

The `FunctionalTestCase` it extends is the one of
`sbuerk/typo3-site-based-test-trait`, which extends the testing framework class
and adds what a site based test needs. Keeping that at the root of the chain is
a rule, not a detail — see
[Site based tests](site-based-tests.md#no-test-extends-the-framework-test-case-directly).

Its class name intentionally does not contain the extension name, so
[repository initialization](../workflow/repository-initialization.md) never has
to rename it.

A test needing more extensions extends the abstract class and redeclares
`$testExtensionsToLoad`. Redeclaring **replaces** the property, so the extension
itself has to be repeated:

```php
protected array $testExtensionsToLoad = [
    'sbuerk/extension-skeleton',
    'tests/example-fixture',
];
```

Loading an extension by its **composer package name** rather than by a path
works for test-only extensions too — see
[Fixture extensions](fixture-extensions.md).

## Conventions

Same as for [unit tests](unit-tests.md): `final` classes, `#[Test]` attributes,
no `test` prefix, named data provider keys.

Additionally:

- Assert against the container through `$this->get()` when verifying wiring.
  `$this->getContainer()->has()` answers whether a service is registered at all,
  which is what the core version aware tests use to prove the *other* version's
  implementation is absent.
- Import records with `importCSVDataSet()` or a DataHandler scenario rather than
  writing SQL.
- Wrap expensive fixture setup in `withDatabaseSnapshot()` so it is built once
  and restored per test.

## Core version aware functional tests

Mirroring the source layout, they live in `Tests/Functional/Core13/` and
`Tests/Functional/Core14/` and carry the group of the core version they must
**not** run on:

```php
#[Group('not-core-14')]
final class ExampleTest extends AbstractFunctionalTestCase
{
    #[Test]
    public function interfaceIsAliasedToCoreVersionAwareImplementation(): void
    {
        $this->assertInstanceOf(Example::class, $this->get(ExampleInterface::class));
    }
}
```

See [Dual core setup](../development/dual-core-setup.md#test-grouping).

## Strictness

Notices, warnings and deprecations fail the suite, and so do a test without an
assertion, a test writing to the output and an incomplete test. This is
deliberate — see
[PHPUnit configuration](phpunit-configuration.md#strictness-policy). Do not
silence them in the test; fix the code that triggers them.

Debug output is the one to watch for here: a `var_dump()` left in a test or in
the code under test turns a green functional test red.

## Related topics

| Topic                                               | Page                                        |
|-----------------------------------------------------|---------------------------------------------|
| Loading fixture extensions by composer package name | [Fixture extensions](fixture-extensions.md) |
| Site configuration and frontend requests            | [Site based tests](site-based-tests.md)     |
| Language and application context in tests           | [Environment state](environment-state.md)   |

## See also

- [PHPUnit configuration](phpunit-configuration.md)
- [Unit tests](unit-tests.md)
- [Core version aware code](../architecture/core-version-aware-code.md)
