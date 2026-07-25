<?php

declare(strict_types=1);

namespace SBUERK\ExtensionSkeleton\Tests\Unit;

use SBUERK\ExtensionSkeleton\Tests\ExtensionCoreVersionCompatTestsTrait;
use TYPO3\TestingFramework\Core\Unit\UnitTestCase;

/**
 * **Never drop this test.** It is the unit side of the version guard described
 * on {@see ExtensionCoreVersionCompatTestsTrait}: it proves that the unit suite
 * ran against the core version it was asked to run against, rather than against
 * whatever happened to be installed in `.Build/`.
 *
 * It carries no assertions of its own on purpose. Everything is in the trait,
 * so the unit and the functional side cannot drift apart.
 */
final class VersionCompatTest extends UnitTestCase
{
    use ExtensionCoreVersionCompatTestsTrait;
}
