# Environment state

Some behaviour depends on the *environment* a request runs in — the application
type (frontend or backend), the site, the language aspect, the workspace. Extbase
repositories are the obvious example: the same query returns different records
depending on the language context in effect.

Inside a frontend request that environment exists. In a command, a scheduler
task, a backend module or a functional test it does not, and a query then
returns either nothing or silently the default language — a defect that only
shows up in production.

[`fgtclb/environment-state-manager`](https://github.com/fgtclb/environment-state-manager)
builds such an environment, applies it, and restores the previous state
afterwards. In this repository it is a **development dependency** used by
functional tests; in a real extension it is just as useful in production code.

The worked example is
[`Tests/Functional/Domain/Repository/GreetingRepositoryTest.php`](../../Tests/Functional/Domain/Repository/GreetingRepositoryTest.php).

## The three types you deal with

| Type                                 | Role                                                                                                          |
|--------------------------------------|---------------------------------------------------------------------------------------------------------------|
| `StateBuildContext`                  | A DTO describing *what* to build: application type, page, language, and for the backend a user and workspace. |
| `EnvironmentBuilderFactoryInterface` | Returns the environment builder matching the running TYPO3 version.                                           |
| `StateManagerInterface`              | Builds, applies, backs up, restores and resets the environment.                                               |

All three are published as public services, so a test fetches them with
`$this->get()`. The package resolves the version specific implementation exactly
the way this repository does it — a shared interface, one implementation per core
version in a `Core13/` and a `Core14/` directory, and only the matching one
registered in the container. See
[Core version aware code](../architecture/core-version-aware-code.md); the
package is a second, independent example of the same pattern.

## Use `execute()`

```php
$this->get(StateManagerInterface::class)->execute(
    new StateBuildContext(
        applicationType: ApplicationType::FRONTEND,
        pageId: 1,
        languageId: 1,
    ),
    $work,
);
```

`execute()` backs the current environment up, applies the built one, runs the
closure and restores the backup **in every case**, including when the closure
throws. That is the whole reason to prefer it over the lower level calls.

It returns `void`, so a result is captured by reference:

```php
$messages = [];
$this->executeInLanguageContext(1, function () use (&$messages): void {
    foreach ($this->get(GreetingRepository::class)->findAllInLanguageContext() as $greeting) {
        $messages[] = $greeting->getMessage();
    }
});
```

`bootstrap()`, `apply()`, `backup()` and `restore()` are available for cases
`execute()` does not cover — building a state once and applying it repeatedly,
for instance. They change the environment **without** taking a backup, so
pairing them correctly is then your job.

## Reset in `tearDown()`

```php
protected function tearDown(): void
{
    $this->get(StateManagerInterface::class)->reset();

    parent::tearDown();
}
```

`execute()` restores the environment already. The reset is the guard for the
other case: a test that fails or throws *before* reaching `execute()`, or one
using `apply()` directly, otherwise leaves a populated environment behind. The
next test then starts in a state nobody configured, which produces failures that
move when tests are reordered — the kind `unitRandom` exists to expose.

## What the fixture asserts

The [fixture extension](fixture-extensions.md) carries a table, an Extbase model
and a repository for exactly this purpose. The data set is deliberately
asymmetric:

| Record | Language                 | Message       |
|--------|--------------------------|---------------|
| 1      | EN (0)                   | `Hello`       |
| 2      | EN (0)                   | `Hello again` |
| 3      | DE (1), translation of 1 | `Hallo`       |
| 4      | FR (2), translation of 1 | `Bonjour`     |

The second greeting has no translation, and the site languages use
`fallbackType: 'strict'`. So the expected result differs per language:

| Language context | `findAllInLanguageContext()` |
|------------------|------------------------------|
| EN (0)           | `Hello`, `Hello again`       |
| DE (1)           | `Hallo`                      |
| FR (2)           | `Bonjour`                    |

An asymmetric data set matters: had every record been translated, a test that
never applied a language context at all would still have produced a plausible
looking result.

The second repository method is the counterpart — it pins the language aspect
and is therefore *not* affected by the environment:

```php
$query->getQuerySettings()->setLanguageAspect(
    new LanguageAspect(0, 0, LanguageAspect::OVERLAYS_OFF),
);
```

`OVERLAYS_OFF` is the part worth remembering. Restricting the *selection* to a
language is not enough — without it the selected rows are still overlaid with
the translation of the current language, and the query stays language dependent
after all. The same is true of `setRespectSysLanguage(false)`, which switches
off the language *filter* but not the overlay.

## Verifying the context is really applied

A test asserting language behaviour can pass for the wrong reason. The cheapest
proof is to remove the environment and see the right things break — replacing
`execute()` with a plain call of the closure makes the DE and FR cases fail,
while EN keeps passing because it *is* the default language. Whenever such a
test is written, run that probe once.

## See also

- [Functional tests](functional-tests.md)
- [Site based tests](site-based-tests.md)
- [Fixture extensions](fixture-extensions.md)
- [Core version aware code](../architecture/core-version-aware-code.md)
