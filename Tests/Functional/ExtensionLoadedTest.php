<?php

declare(strict_types=1);

namespace SBUERK\ExtensionSkeleton\Tests\Functional;

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\Test;
use SBUERK\ExtensionSkeleton\Tests\ExtensionCoreVersionCompatTestsTrait;
use TYPO3\CMS\Core\Utility\ExtensionManagementUtility;

/**
 * **Never drop this test.** Its assertions look trivial, and its value is not in
 * them: it is the test that has to boot a complete TYPO3 instance with this
 * extension installed before it can assert anything at all. That boot is the
 * actual subject.
 *
 * What a failing boot reports here, at the cheapest possible place:
 *
 * - **Dependency injection.** The container is compiled from
 *   `Configuration/Services.php` and the Symfony attributes on the classes. An
 *   unresolvable argument, a service typed against a missing interface or an
 *   autowiring ambiguity fails the compilation — with the compiler's message,
 *   rather than much later in whichever feature test first fetches that service.
 * - **The extension bootstrap.** `ext_localconf.php` and `ext_tables.php` are
 *   executed if the extension has them. A fatal, a warning or a deprecation
 *   raised there fails the run, because this suite converts those.
 * - **TCA.** Every `Configuration/TCA/` file is loaded and the result is run
 *   through the core's TCA migration, which raises `E_USER_DEPRECATED` for
 *   everything it had to migrate — and this suite turns that into a failure. A
 *   structure one core version still accepts and the other has migrated away is
 *   the difference a repository supporting two core versions from one code base
 *   runs into first, and it is reported by the version that no longer takes it.
 * - **The schema.** The schema of the test instance is derived from that TCA and
 *   from `ext_tables.sql`, so a definition the DBMS rejects fails before the
 *   first record is written.
 *
 * It also carries the version guard, so a green functional run additionally
 * proves it ran against the core version it was asked for —
 * see {@see ExtensionCoreVersionCompatTestsTrait}.
 *
 * What it deliberately does not cover is FormEngine rendering: that TCA loads
 * and migrates is not the same as the backend being able to render a form from
 * it. That needs a test of its own.
 */
final class ExtensionLoadedTest extends AbstractFunctionalTestCase
{
    use ExtensionCoreVersionCompatTestsTrait;

    /**
     * Both identifiers are asserted, because they are resolved differently:
     * TYPO3 knows the extension by its extension key and composer by its package
     * name, and the repository initialization rewrites both.
     *
     * @return \Generator<string, array{identifier: string}>
     */
    public static function expectedLoadedExtensionIdentifiers(): \Generator
    {
        yield 'composer package name: sbuerk/extension-skeleton' => ['identifier' => 'sbuerk/extension-skeleton'];
        yield 'extension key: extension_skeleton' => ['identifier' => 'extension_skeleton'];
    }

    #[DataProvider('expectedLoadedExtensionIdentifiers')]
    #[Test]
    public function verifyLoadedExtensionByIdentifier(string $identifier): void
    {
        $this->assertTrue(ExtensionManagementUtility::isLoaded($identifier), sprintf(
            '"%s" returns true using identifier "%s".',
            sprintf('%s::%s()', ExtensionManagementUtility::class, 'isLoaded'),
            $identifier,
        ));
    }
}
