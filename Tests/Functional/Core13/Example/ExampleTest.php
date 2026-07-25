<?php

declare(strict_types=1);

namespace SBUERK\ExtensionSkeleton\Tests\Functional\Core13\Example;

use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\Attributes\Test;
use SBUERK\ExtensionSkeleton\Core13\Example\Example;
use SBUERK\ExtensionSkeleton\Example\ExampleInterface;
use SBUERK\ExtensionSkeleton\Tests\Functional\AbstractFunctionalTestCase;

/**
 * Verifies the core version aware dependency injection wiring on TYPO3 v13.
 *
 * Core version aware tests live below `Tests/Functional/Core13/` and are put
 * into the `not-core-14` group, so they are skipped when the test suite runs
 * against another core version — `Build/Scripts/runTests.sh` passes
 * `--exclude-group not-core-<version>` for the selected core version.
 */
#[Group('not-core-14')]
final class ExampleTest extends AbstractFunctionalTestCase
{
    #[Test]
    public function interfaceIsAliasedToCoreVersionAwareImplementation(): void
    {
        $this->assertInstanceOf(Example::class, $this->get(ExampleInterface::class));
    }

    #[Test]
    public function implementationOfTheOtherCoreVersionIsNotRegistered(): void
    {
        $otherImplementation = 'SBUERK\\ExtensionSkeleton\\Core14\\Example\\Example';

        $this->assertFalse(
            $this->getContainer()->has($otherImplementation),
            sprintf('"%s" is not registered in the dependency injection container.', $otherImplementation),
        );
    }

    #[Test]
    public function exampleReturnsCoreVersionAwareValue(): void
    {
        $this->assertSame(
            'Example implementation for TYPO3 v13',
            $this->get(ExampleInterface::class)->example(),
        );
    }
}
