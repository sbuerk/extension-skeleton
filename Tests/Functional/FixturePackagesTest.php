<?php

declare(strict_types=1);

namespace SBUERK\ExtensionSkeleton\Tests\Functional;

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\Test;
use TESTS\ExampleFixture\Service\DummyService;
use TESTS\ExampleFixture\Service\DummyServiceInterface;
use TYPO3\CMS\Core\Utility\ExtensionManagementUtility;

/**
 * Verifies the "sbuerk/fixture-packages" integration.
 *
 * The subject of these tests is the wiring, not the fixture extension: that a
 * fixture extension below "Tests/Functional/Fixtures/Extensions/" can be named
 * in $testExtensionsToLoad by its composer package name, that its classes are
 * autoloaded and that its "Configuration/Services.php" is processed. The dummy
 * service is only the visible end of that chain, which is why asserting its
 * static result is enough.
 */
final class FixturePackagesTest extends AbstractFunctionalTestCase
{
    /**
     * The fixture extension is loaded by its composer package name, which is
     * exactly what is under test here. The extension itself is repeated from
     * the parent class, because redeclaring the property replaces it.
     */
    protected array $testExtensionsToLoad = [
        'sbuerk/extension-skeleton',
        'tests/example-fixture',
    ];

    public static function fixtureExtensionIdentifiers(): \Generator
    {
        yield 'composer package name: tests/example-fixture' => ['identifier' => 'tests/example-fixture'];
        yield 'extension key: tests_example_fixture' => ['identifier' => 'tests_example_fixture'];
    }

    #[DataProvider('fixtureExtensionIdentifiers')]
    #[Test]
    public function fixtureExtensionIsLoadedInTestInstance(string $identifier): void
    {
        $this->assertTrue(ExtensionManagementUtility::isLoaded($identifier), sprintf(
            '"%s" returns true using identifier "%s".',
            sprintf('%s::%s()', ExtensionManagementUtility::class, 'isLoaded'),
            $identifier,
        ));
    }

    #[Test]
    public function serviceConfigurationOfFixtureExtensionIsProcessed(): void
    {
        $this->assertInstanceOf(DummyService::class, $this->get(DummyServiceInterface::class));
    }

    #[Test]
    public function dummyServiceOfFixtureExtensionIsAutoloaded(): void
    {
        $subject = $this->get(DummyServiceInterface::class);
        $this->assertInstanceOf(DummyServiceInterface::class, $subject);

        $this->assertSame('tests_example_fixture', $subject->getExtensionKey());
    }
}
