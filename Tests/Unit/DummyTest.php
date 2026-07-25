<?php

declare(strict_types=1);

namespace SBUERK\ExtensionSkeleton\Tests\Unit;

use PHPUnit\Framework\Attributes\Test;
use SBUERK\ExtensionSkeleton\Dummy;
use TYPO3\TestingFramework\Core\Unit\UnitTestCase;

final class DummyTest extends UnitTestCase
{
    #[Test]
    public function getExtensionKeyReturnsExtensionKey(): void
    {
        $this->assertSame('extension_skeleton', (new Dummy())->getExtensionKey());
    }
}
