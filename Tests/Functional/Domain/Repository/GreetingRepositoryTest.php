<?php

declare(strict_types=1);

namespace SBUERK\ExtensionSkeleton\Tests\Functional\Domain\Repository;

use FGTCLB\EnvironmentStateManager\StateBuildContext;
use FGTCLB\EnvironmentStateManager\StateManagerInterface;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\Test;
use SBUERK\ExtensionSkeleton\Tests\Functional\AbstractFunctionalTestCase;
use SBUERK\TYPO3\Testing\SiteHandling\SiteBasedTestTrait;
use TESTS\ExampleFixture\Domain\Model\Greeting;
use TESTS\ExampleFixture\Domain\Repository\GreetingRepository;
use TYPO3\CMS\Core\Http\ApplicationType;

/**
 * Retrieval of records through an Extbase repository in several language
 * contexts.
 *
 * A repository query outside of a request — in a command, a scheduler task or,
 * as here, a test — has no language context unless one is built. Without it the
 * result is either empty or silently the default language, which is the kind of
 * defect that only shows up in production. `fgtclb/environment-state-manager`
 * builds that context and, just as importantly, restores the previous one
 * afterwards.
 *
 * The data set is asymmetric on purpose: the second greeting is not translated,
 * so a language context that is *not* applied cannot produce the expected
 * result by accident.
 */
final class GreetingRepositoryTest extends AbstractFunctionalTestCase
{
    use SiteBasedTestTrait;

    protected const LANGUAGE_PRESETS = [
        'EN' => ['id' => 0, 'title' => 'English', 'locale' => 'en_US.UTF8'],
        'DE' => ['id' => 1, 'title' => 'German', 'locale' => 'de_DE.UTF8'],
        'FR' => ['id' => 2, 'title' => 'French', 'locale' => 'fr_FR.UTF8'],
    ];

    protected array $testExtensionsToLoad = [
        'sbuerk/extension-skeleton',
        'fgtclb/environment-state-manager',
        'tests/example-fixture',
    ];

    protected function setUp(): void
    {
        parent::setUp();

        $this->importCSVDataSet(__DIR__ . '/../../Fixtures/Database/SiteWithThreeLanguages.csv');
        $this->importCSVDataSet(__DIR__ . '/../../Fixtures/Database/Greetings.csv');
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

    protected function tearDown(): void
    {
        // The environment is restored by execute() already; this guards against
        // a leftover state when a test fails before or outside of it.
        $this->get(StateManagerInterface::class)->reset();

        parent::tearDown();
    }

    /**
     * @return \Generator<string, array{languageId: int, expectedMessages: string[]}>
     */
    public static function siteLanguages(): \Generator
    {
        yield '0 EN -> both untranslated records' => [
            'languageId' => 0,
            'expectedMessages' => ['Hello', 'Hello again'],
        ];
        yield '1 DE -> the translated record only' => [
            'languageId' => 1,
            'expectedMessages' => ['Hallo'],
        ];
        yield '2 FR -> the translated record only' => [
            'languageId' => 2,
            'expectedMessages' => ['Bonjour'],
        ];
    }

    /**
     * @param string[] $expectedMessages
     */
    #[DataProvider('siteLanguages')]
    #[Test]
    public function repositoryReturnsRecordsOfTheLanguageTheEnvironmentWasBuiltFor(
        int $languageId,
        array $expectedMessages,
    ): void {
        $this->assertSame($expectedMessages, $this->messagesInLanguageContext($languageId));
    }

    #[Test]
    public function queryWithAPinnedLanguageAspectIsUnaffectedByTheEnvironment(): void
    {
        $messages = [];
        $this->executeInLanguageContext(1, function () use (&$messages): void {
            foreach ($this->get(GreetingRepository::class)->findAllInDefaultLanguage() as $greeting) {
                $this->assertInstanceOf(Greeting::class, $greeting);
                $messages[] = $greeting->getMessage();
            }
        });

        $this->assertSame(['Hello', 'Hello again'], $messages);
    }

    #[Test]
    public function environmentIsRestoredAfterExecute(): void
    {
        $before = $GLOBALS['TYPO3_REQUEST'] ?? null;

        $this->executeInLanguageContext(1, function (): void {
            $this->assertNotNull($GLOBALS['TYPO3_REQUEST'] ?? null);
        });

        $this->assertSame($before, $GLOBALS['TYPO3_REQUEST'] ?? null);
    }

    /**
     * @return string[]
     */
    private function messagesInLanguageContext(int $languageId): array
    {
        $messages = [];
        $this->executeInLanguageContext($languageId, function () use (&$messages): void {
            foreach ($this->get(GreetingRepository::class)->findAllInLanguageContext() as $greeting) {
                $this->assertInstanceOf(Greeting::class, $greeting);
                $messages[] = $greeting->getMessage();
            }
        });

        return $messages;
    }

    /**
     * Runs the closure in a frontend environment built for the given site
     * language. `execute()` backs the current environment up, applies the built
     * one, runs the closure and restores the backup in every case — including
     * when the closure throws.
     */
    private function executeInLanguageContext(int $languageId, \Closure $work): void
    {
        $this->get(StateManagerInterface::class)->execute(
            new StateBuildContext(
                applicationType: ApplicationType::FRONTEND,
                pageId: 1,
                languageId: $languageId,
            ),
            $work,
        );
    }
}
