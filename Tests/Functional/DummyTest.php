<?php

declare(strict_types=1);

namespace SBUERK\ExtensionSkeleton\Tests\Functional;

use PHPUnit\Framework\Attributes\Test;
use SBUERK\ExtensionSkeleton\Dummy;

final class DummyTest extends AbstractFunctionalTestCase
{
    #[Test]
    public function dummyIsRetrievableFromDependencyInjectionContainer(): void
    {
        $this->assertInstanceOf(Dummy::class, $this->get(Dummy::class));
    }
}
