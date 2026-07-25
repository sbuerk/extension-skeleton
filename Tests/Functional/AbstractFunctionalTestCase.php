<?php

declare(strict_types=1);

namespace SBUERK\ExtensionSkeleton\Tests\Functional;

use SBUERK\TYPO3\Testing\TestCase\FunctionalTestCase;

/**
 * Base class of all functional tests, taking care that the extension itself is
 * loaded in the test instance.
 *
 * It extends the `FunctionalTestCase` of `sbuerk/typo3-site-based-test-trait`
 * rather than the one of `typo3/testing-framework` directly. That class extends
 * the framework one and adds what a site based test needs, most notably a
 * `setUpFrontendRootPage()` which can set up a root page without creating a
 * `sys_template` record. Having every functional test go through this class
 * means the whole suite gains that without a second base class — see the
 * "Site based tests" page of the developer documentation in "docs/testing/".
 *
 * The class name intentionally does not contain the extension name, so the
 * repository initialization never has to rename classes.
 */
abstract class AbstractFunctionalTestCase extends FunctionalTestCase
{
    protected array $testExtensionsToLoad = [
        'sbuerk/extension-skeleton',
    ];
}
