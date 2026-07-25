# Site based tests

Site based tests set up a real site configuration with several languages and
issue frontend sub-requests against it, so rendering, routing and language
resolution can be asserted end to end.

[`Tests/Functional/SiteBasedRenderingTest.php`](../../Tests/Functional/SiteBasedRenderingTest.php)
is the worked example: one page tree, three languages, three requests.

## Why a package instead of the core trait

TYPO3 ships `SiteBasedTestTrait` inside the core mono-repository only. It lives
in a test namespace which is stripped from the distributed system extension
packages, so an extension cannot use it without installing `typo3/cms-core`
from source *and* registering that namespace in its own `composer.json` — easy
to get wrong, and it breaks whenever the core moves the file.

[`sbuerk/typo3-site-based-test-trait`](https://github.com/sbuerk/typo3-site-based-test-trait)
provides an equivalent trait as a normal package, and hides the differences the
core version introduced over time behind one API.

Its majors are pinned to a core version, so the constraint names both:

```json
"sbuerk/typo3-site-based-test-trait": "^2.0.1 || ^3.0.0"
```

| Package major | TYPO3 |
|---------------|-------|
| `2.x`         | v13   |
| `3.x`         | v14   |

`composerUpdate` resolves the major matching the `-t` core version, which is one
more reason why the installed dependency set must match the version a suite is
run for — see [Dual core setup](../development/dual-core-setup.md).

Beyond availability, the package differs from the core trait in ways that matter
for a test suite: a language that cannot be resolved **fails** the test instead
of silently marking it skipped, the annotations survive PHPStan level 8 without
a baseline entry, and `writeSiteConfiguration()` and `buildSiteConfiguration()`
take an additional array argument for site configuration keys the core trait has
no parameter for.

## No test extends the framework test case directly

[`AbstractFunctionalTestCase`](../../Tests/Functional/AbstractFunctionalTestCase.php)
extends the `FunctionalTestCase` of that package rather than the one of
`typo3/testing-framework`:

```php
use SBUERK\TYPO3\Testing\TestCase\FunctionalTestCase;

abstract class AbstractFunctionalTestCase extends FunctionalTestCase
```

The package class extends the framework class, so nothing is lost, and every
functional test gains its additions — most notably a `setUpFrontendRootPage()`
whose fourth argument can set up a root page *without* creating a
`sys_template` record, which is what site set based TypoScript needs.

Since every functional test already extends `AbstractFunctionalTestCase`, the
whole chain roots in the package class through that one edit. When adding an
intermediate abstract test case, keep it — just make sure the chain ends there
and not at the framework class.

## The three parts of a site based test

### 1. The language presets

`LANGUAGE_PRESETS` is what the identifiers passed to the build methods resolve
against:

```php
protected const LANGUAGE_PRESETS = [
    'EN' => ['id' => 0, 'title' => 'English', 'locale' => 'en_US.UTF8'],
    'DE' => ['id' => 1, 'title' => 'German', 'locale' => 'de_DE.UTF8'],
    'FR' => ['id' => 2, 'title' => 'French', 'locale' => 'fr_FR.UTF8'],
];
```

A preset may carry a `custom` key, whose content is merged into the language
block of the written site configuration. That is how an extension adding its own
fields to a site language tests them.

### 2. The site configuration

```php
$this->writeSiteConfiguration(
    'acme',
    $this->buildSiteConfiguration(
        rootPageId: 1,
        base: 'https://acme.com/',
        websiteTitle: 'ACME',
    ),
    [
        $this->buildDefaultLanguageConfiguration(
            identifier: 'EN',
            base: 'https://acme.com/',
        ),
        $this->buildLanguageConfiguration(
            identifier: 'DE',
            base: 'https://acme.com/de/',
            fallbackIdentifiers: ['EN'],
            fallbackType: 'strict',
        ),
    ],
);
```

`fallbackType: 'strict'` is the interesting choice for a translation test: a
content element without a translation is **not** rendered from the default
language, so a test asserting translated output cannot pass by accident.

Site sets and other root level configuration go into the `additional` argument
rather than into a `dependencies` argument, which keeps the call identical
across package majors:

```php
$this->writeSiteConfiguration(
    identifier: 'acme',
    site: [],
    languages: [],
    errorHandling: [],
    additional: [
        'dependencies' => ['my-vendor/site-set-identifier'],
    ],
);
```

### 3. The page tree

The tree is imported from a CSV data set,
[`Tests/Functional/Fixtures/Database/SiteWithThreeLanguages.csv`](../../Tests/Functional/Fixtures/Database/SiteWithThreeLanguages.csv):

| uid | pid | language | `l10n_parent` | slug       |
|-----|-----|----------|---------------|------------|
| 1   | 0   | EN (0)   | –             | `/`        |
| 2   | 0   | DE (1)   | 1             | `/`        |
| 3   | 0   | FR (2)   | 1             | `/`        |
| 10  | 1   | EN (0)   | –             | `/hello`   |
| 11  | 1   | DE (1)   | 10            | `/hallo`   |
| 12  | 1   | FR (2)   | 10            | `/bonjour` |

Two things are worth copying from it:

- **Translations of a page keep the `pid` of the original**, they are not
  children of it. The relation is `l10n_parent` plus `sys_language_uid`.
- **Slugs are translated.** The language base is prepended by the router, so
  page 11 is reachable as `https://acme.com/de/hallo`. A fixture reusing the
  default language slug in every language would never notice a routing bug.

The content elements are in the same file, one per language, with `l18n_parent`
pointing at the default language record — note the `l18n` spelling, `tt_content`
differs from `pages` here.

Finally the root page needs TypoScript, which is where the base test case comes
in:

```php
$this->setUpFrontendRootPage(
    1,
    ['setup' => ['EXT:tests_example_fixture/Configuration/TypoScript/setup.typoscript']],
);
```

## The request

```php
$response = $this->executeFrontendSubRequest(new InternalRequest('https://acme.com/de/hallo'));

$this->assertSame(200, $response->getStatusCode());
$this->assertStringContainsString('[DE] Hello SiteBasedTestTrait', (string)$response->getBody());
```

The sub-request runs the real frontend in the same process — routing, TypoScript,
Extbase and Fluid included. Asserting the status code alone proves little; assert
on rendered content.

The example uses a data provider with one case per language, keyed so a failure
names the language:

```php
yield '1 DE -> [DE] Hello SiteBasedTestTrait' => [
    'url' => 'https://acme.com/de/hallo',
    'expectedContent' => '[DE] Hello SiteBasedTestTrait',
];
```

## What renders the marker

The [fixture extension](fixture-extensions.md) contains a small Extbase plugin
whose only job is to make the resolved language visible in the response body.
Its controller reads the site language from the request attribute:

```php
$language = $this->request->getAttribute('language');

$this->view->assign(
    'languageKey',
    $language instanceof SiteLanguage
        ? strtoupper($language->getLocale()->getLanguageCode())
        : 'UNRESOLVED',
);
```

The request attribute is used rather than the language aspect because it behaves
identically in TYPO3 v13 and v14 — a fixture extension should not need
[core version aware code](../architecture/core-version-aware-code.md).

Two details of the plugin registration are worth knowing, both of them the
reason it works on both core versions unchanged:

- `ExtensionUtility::configurePlugin()` is called with
  `PLUGIN_TYPE_CONTENT_ELEMENT` explicitly, and it has to be. TYPO3 v13 still
  defaults to `list_type` and **triggers a deprecation** for it; v14 removed
  that plugin content element and throws an `\InvalidArgumentException` for
  anything but `CType`. Naming `CType` is the one call correct on both. Omitting
  it would not fail silently either: the deprecation turns the v13 run red,
  because [the suites fail on deprecations](phpunit-configuration.md#strictness-policy).
  See the changelog entry `Important-105538-ListTypeAndSubTypes.rst` shipped
  with `typo3/cms-core`.
- `Configuration/TCA/Overrides/tt_content.php` passes **no** plugin type:
  `ExtensionUtility::registerPlugin()` reads it back from what `configurePlugin()`
  registered, and `ext_localconf.php` is loaded before the TCA overrides.
- The generated rendering definition is `=< lib.contentElement`, which comes from
  EXT:fluid_styled_content. That extension is not a dependency here, so the
  fixture TypoScript overrides `tt_content.testsexamplefixture_hello` with a
  plain `EXTBASEPLUGIN` content object instead of pulling one in.

## See also

- [Functional tests](functional-tests.md)
- [Fixture extensions](fixture-extensions.md)
- [Environment state](environment-state.md)
- [Dual core setup](../development/dual-core-setup.md)
