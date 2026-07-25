<?php

declare(strict_types=1);

namespace SBUERK\ExtensionSkeleton\Tests;

use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\Attributes\Test;
use TYPO3\CMS\Core\Information\Typo3Version;

/**
 * Asserts that a test run happens against a TYPO3 version this extension
 * supports, and that both supported versions are actually exercised.
 *
 * **Never drop the tests using this trait.** They are the cheapest guard this
 * repository has against a whole class of silent failure: a gate that runs, is
 * green, and proves nothing because it ran against the wrong core version. The
 * dependency set is installed separately from the version a suite is run for —
 * `-t 13` selects a version but installs nothing — so a stale `.Build/`, a
 * misconfigured CI matrix entry or a `composerUpdate` that was skipped all
 * produce a run that looks exactly like a real one.
 *
 * The three assertions cover that from both sides:
 *
 * - The running major version is one of the supported ones at all.
 * - Running with `-t 13` really is TYPO3 v13, and `-t 14` really is v14. This
 *   works through the group exclusion `Build/Scripts/runTests.sh` passes:
 *   `--exclude-group not-core-<version>` removes the assertion for the version
 *   that is *not* selected, so exactly one of the two remains — and it fails
 *   when what is installed disagrees with what was asked for.
 *
 * The group names are written out rather than composed from the constants
 * below, because an attribute argument has to be a constant expression and the
 * rest of this repository spells them out as well.
 *
 * @see \SBUERK\ExtensionSkeleton\Tests\Unit\VersionCompatTest
 * @see \SBUERK\ExtensionSkeleton\Tests\Functional\ExtensionLoadedTest
 */
trait ExtensionCoreVersionCompatTestsTrait
{
    private const LOWEST_SUPPORTED_MAJOR_VERSION = 13;
    private const HIGHEST_SUPPORTED_MAJOR_VERSION = 14;

    #[Test]
    public function runsAgainstASupportedMajorVersion(): void
    {
        $this->assertContains(
            (new Typo3Version())->getMajorVersion(),
            [self::LOWEST_SUPPORTED_MAJOR_VERSION, self::HIGHEST_SUPPORTED_MAJOR_VERSION],
        );
    }

    #[Group('not-core-14')]
    #[Test]
    public function runsAgainstTheLowestSupportedMajorVersion(): void
    {
        $this->assertSame(self::LOWEST_SUPPORTED_MAJOR_VERSION, (new Typo3Version())->getMajorVersion());
    }

    #[Group('not-core-13')]
    #[Test]
    public function runsAgainstTheHighestSupportedMajorVersion(): void
    {
        $this->assertSame(self::HIGHEST_SUPPORTED_MAJOR_VERSION, (new Typo3Version())->getMajorVersion());
    }
}
