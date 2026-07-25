<?php

declare(strict_types=1);

namespace SBUERK\ExtensionSkeleton\Tests\Unit\Core14\Example;

use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\Attributes\Test;
use SBUERK\ExtensionSkeleton\Core14\Example\Example;
use TYPO3\CMS\Core\Information\Typo3Version;
use TYPO3\TestingFramework\Core\Unit\UnitTestCase;

/**
 * Tests of the TYPO3 v14 implementation living in `Core14/`.
 *
 * Core version aware tests live below `Tests/Unit/Core14/` and are put into
 * the `not-core-13` group, so they are skipped when the test suite runs
 * against another core version — `Build/Scripts/runTests.sh` passes
 * `--exclude-group not-core-<version>` for the selected core version.
 */
#[Group('not-core-13')]
final class ExampleTest extends UnitTestCase
{
    #[Test]
    public function exampleReturnsCoreVersionAwareValue(): void
    {
        $subject = new Example();
        $subject->injectTypo3Version(new Typo3Version());

        $this->assertSame('Example implementation for TYPO3 v14', $subject->example());
    }
}
