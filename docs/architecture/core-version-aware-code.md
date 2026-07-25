# Core version aware code

The extension supports more than one TYPO3 major version from a single code
base. Code that cannot be written for all of them at once is **core version
aware**: it exists once per supported core version, and only the variant
matching the running TYPO3 version is used.

## Where the code lives

| Directory  | Contains                                                                                                                |
|------------|-------------------------------------------------------------------------------------------------------------------------|
| `Classes/` | Everything working on **all** supported core versions: interfaces, abstract base classes, version independent services. |
| `Core13/`  | Implementations for TYPO3 v13 only.                                                                                     |
| `Core14/`  | Implementations for TYPO3 v14 only.                                                                                     |

`Core13/` and `Core14/` are separate PSR-4 roots in the repository root, not
subdirectories of `Classes/`, and are registered in `composer.json` with the
core version as the third namespace part:

```json
"autoload": {
    "psr-4": {
        "SBUERK\\ExtensionSkeleton\\": "Classes/",
        "SBUERK\\ExtensionSkeleton\\Core13\\": "Core13/",
        "SBUERK\\ExtensionSkeleton\\Core14\\": "Core14/"
    }
}
```

## How the right variant is selected

Composer autoloads **all** of those directories — that is unavoidable and
harmless, as long as a class is never *instantiated* on the wrong core version.
The selection therefore happens in the dependency injection container:
[`Configuration/Services.php`](../../Configuration/Services.php) loads
`Classes/` unconditionally and, on top of it, only the `Core<major>/` directory
matching the running TYPO3 version:

```php
$coreMajorVersion = (new Typo3Version())->getMajorVersion();
$coreAwareDirectory = sprintf('%s/../Core%d', __DIR__, $coreMajorVersion);
if (is_dir($coreAwareDirectory)) {
    $services->load(
        sprintf('SBUERK\\ExtensionSkeleton\\Core%d\\', $coreMajorVersion),
        $coreAwareDirectory . '/*',
    );
}
```

Because of that, a class below `Core13/` may freely use API that only exists in
TYPO3 v13 — it is never instantiated when running on v14.

This is deliberately the *only* mechanism used for version differences. Do not
write conditional code (`if ($coreMajorVersion === 13) { … }`) in shared classes
below `Classes/`; split the class instead. Shared code stays readable, and each
version aware implementation can be deleted as a whole once its core version is
dropped.

## The pattern to follow

1. Declare an **interface** in `Classes/` — consumers only ever type hint this.
2. Put shared behaviour into an **abstract base class** in `Classes/`. Abstract
   classes use method injection, see
   [Class design](class-design.md#abstract-classes-must-not-use-constructor-injection).
3. Implement it once per core version in `Core13/` and `Core14/`, each
   registering itself as the default implementation of the interface with
   `#[AsAlias]`:

   ```php
   #[AsAlias(id: ExampleInterface::class, public: true)]
   final readonly class Example extends AbstractExample
   {
   }
   ```

See [`Classes/Example/`](../../Classes/Example),
[`Core13/Example/`](../../Core13/Example) and
[`Core14/Example/`](../../Core14/Example) for the complete example shipped with
the skeleton.

## Configuration is the exception

The `Core13/` and `Core14/` split works for classes, because the container picks
one of them. Configuration files — TCA, TypoScript, `ext_localconf.php` — are
loaded by TYPO3 from a fixed path and cannot be split that way. A version
difference there is resolved **in the file**, by building the array and adjusting
it before returning:

```php
$tcaConfiguration = [
    'ctrl' => [ /* … */ ],
    'columns' => [ /* … */ ],
];

// The 'searchFields' ctrl option was removed in TYPO3 v14 (Breaking #106972).
// @todo Remove once TYPO3 v13 support is dropped.
if ((new Typo3Version())->getMajorVersion() < 14) {
    $tcaConfiguration['ctrl']['searchFields'] = 'title,message';
}

return $tcaConfiguration;
```

Three things make this acceptable where a conditional in a class would not be:

- The difference is **at the end of the file**, applied to the finished array,
  not scattered through it. The configuration stays readable as one thing.
- It carries a `@todo` naming the condition under which it goes away. A version
  switch without an exit condition becomes permanent.
- It names the **changelog issue**, so the reason can be looked up. The
  changelogs ship with `typo3/cms-core` in `Documentation/Changelog/` — verify
  against them rather than from memory.

Dropping the option instead of guarding it is not the same thing: v14 removed it
and warns when it is present, but v13 still evaluates it and searches *nothing*
without it. Removing it silently changes behaviour on v13.

The complete example is
[`Configuration/TCA/tx_examplefixture_domain_model_greeting.php`](../../Tests/Functional/Fixtures/Extensions/example-fixture/Configuration/TCA/tx_examplefixture_domain_model_greeting.php)
of the [fixture extension](../testing/fixture-extensions.md), and
[`ext_localconf.php`](../../Tests/Functional/Fixtures/Extensions/example-fixture/ext_localconf.php)
next to it shows the better outcome where one exists: passing
`PLUGIN_TYPE_CONTENT_ELEMENT` explicitly is valid on both versions, so no switch
is needed at all. Look for that first.

## Tooling and tests

- **PHPStan** is configured per core version. Each configuration analyses only
  its own core version aware sources — `Build/phpstan/Core13/phpstan.neon` lists
  `Classes`, `Configuration`, `Core13` and `Tests`, and excludes
  `Tests/*/Core14/*`. Analysing the sources of the other core version would
  report false positives about API that does not exist there. See
  [Quality gates](../development/quality-gates.md).
- **Tests** mirror the same layout: `Tests/Unit/Core13/`, `Tests/Unit/Core14/`,
  `Tests/Functional/Core13/` and `Tests/Functional/Core14/`. Every core version
  aware test class carries the PHPUnit group of the core versions it must
  **not** run on:

  ```php
  #[Group('not-core-14')]
  final class ExampleTest extends UnitTestCase
  {
  }
  ```

  `Build/Scripts/runTests.sh` passes `--exclude-group not-core-<version>` for
  the selected core version, so those tests are skipped automatically on the
  other one.
- Both core versions must be verified before opening a pull request, each after
  the matching `composerUpdate` — see
  [Dual core setup](../development/dual-core-setup.md) and
  [Pull requests](../workflow/pull-requests.md).

## See also

- [Dependency injection](dependency-injection.md)
- [Class design](class-design.md)
- [Dual core setup](../development/dual-core-setup.md)
- [Functional tests](../testing/functional-tests.md)
