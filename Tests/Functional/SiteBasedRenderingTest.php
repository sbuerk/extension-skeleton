<?php

declare(strict_types=1);

namespace SBUERK\ExtensionSkeleton\Tests\Functional;

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\Test;
use SBUERK\TYPO3\Testing\SiteHandling\SiteBasedTestTrait;
use TYPO3\TestingFramework\Core\Functional\Framework\Frontend\InternalRequest;

/**
 * Renders the plugin of the fixture extension in all three site languages.
 *
 * The subject is the test setup, not the plugin: a site configuration with
 * several languages, a page tree with translated slugs and a frontend
 * sub-request per language. The plugin only makes the resolved language visible
 * in the response body.
 */
final class SiteBasedRenderingTest extends AbstractFunctionalTestCase
{
    use SiteBasedTestTrait;

    /**
     * The languages the site configuration is built from. The identifiers are
     * what `buildDefaultLanguageConfiguration()` and
     * `buildLanguageConfiguration()` resolve against.
     */
    protected const LANGUAGE_PRESETS = [
        'EN' => ['id' => 0, 'title' => 'English', 'locale' => 'en_US.UTF8'],
        'DE' => ['id' => 1, 'title' => 'German', 'locale' => 'de_DE.UTF8'],
        'FR' => ['id' => 2, 'title' => 'French', 'locale' => 'fr_FR.UTF8'],
    ];

    protected array $testExtensionsToLoad = [
        'sbuerk/extension-skeleton',
        'tests/example-fixture',
    ];

    protected function setUp(): void
    {
        parent::setUp();

        $this->importCSVDataSet(__DIR__ . '/Fixtures/Database/SiteWithThreeLanguages.csv');
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
                $this->buildLanguageConfiguration(
                    identifier: 'FR',
                    base: 'https://acme.com/fr/',
                    fallbackIdentifiers: ['EN'],
                    fallbackType: 'strict',
                ),
            ],
        );
        $this->setUpFrontendRootPage(
            1,
            [
                'setup' => [
                    'EXT:tests_example_fixture/Configuration/TypoScript/setup.typoscript',
                ],
            ],
        );
    }

    public static function siteLanguages(): \Generator
    {
        yield '0 EN -> [EN] Hello SiteBasedTestTrait' => [
            'url' => 'https://acme.com/hello',
            'expectedContent' => '[EN] Hello SiteBasedTestTrait',
        ];
        yield '1 DE -> [DE] Hello SiteBasedTestTrait' => [
            'url' => 'https://acme.com/de/hallo',
            'expectedContent' => '[DE] Hello SiteBasedTestTrait',
        ];
        yield '2 FR -> [FR] Hello SiteBasedTestTrait' => [
            'url' => 'https://acme.com/fr/bonjour',
            'expectedContent' => '[FR] Hello SiteBasedTestTrait',
        ];
    }

    #[DataProvider('siteLanguages')]
    #[Test]
    public function pluginIsRenderedInSiteLanguage(string $url, string $expectedContent): void
    {
        $response = $this->executeFrontendSubRequest(new InternalRequest($url));

        $this->assertSame(200, $response->getStatusCode());
        $this->assertStringContainsString($expectedContent, (string)$response->getBody());
    }
}
