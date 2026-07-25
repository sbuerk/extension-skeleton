<?php

declare(strict_types=1);

namespace SBUERK\ExtensionSkeleton\Tests\Unit\Core13\Example;

use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\Attributes\Test;
use SBUERK\ExtensionSkeleton\Core13\Example\Example;
use TYPO3\CMS\Core\Information\Typo3Version;
use TYPO3\TestingFramework\Core\Unit\UnitTestCase;

/**
 * Tests of the TYPO3 v13 implementation living in `Core13/`.
 *
 * Core version aware tests live below `Tests/Unit/Core13/` and are put into
 * the `not-core-14` group, so they are skipped when the test suite runs
 * against another core version — `Build/Scripts/runTests.sh` passes
 * `--exclude-group not-core-<version>` for the selected core version.
 */
#[Group('not-core-14')]
final class ExampleTest extends UnitTestCase
{
    #[Test]
    public function exampleReturnsCoreVersionAwareValue(): void
    {
        $subject = new Example();
        $subject->injectTypo3Version(new Typo3Version());

        $this->assertSame('Example implementation for TYPO3 v13', $subject->example());
    }
}
