<?php

declare(strict_types=1);

namespace TESTS\ExampleFixture\Service;

use Symfony\Component\DependencyInjection\Attribute\AsAlias;

/**
 * Default implementation of {@see DummyServiceInterface}.
 *
 * Wired with a Symfony dependency injection attribute, following the same
 * interface plus default implementation pattern the extension itself uses. It
 * is deliberately *not* core version aware: a fixture extension has no reason
 * to carry a `Core13/` and `Core14/` split.
 *
 * It is published with `public: true` so a functional test can fetch it from
 * the container with `$this->get()`.
 */
#[AsAlias(id: DummyServiceInterface::class, public: true)]
final readonly class DummyService implements DummyServiceInterface
{
    public function getExtensionKey(): string
    {
        return 'tests_example_fixture';
    }
}
