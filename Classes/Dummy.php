<?php

declare(strict_types=1);

namespace SBUERK\ExtensionSkeleton;

use Symfony\Component\DependencyInjection\Attribute\Autoconfigure;

/**
 * Placeholder class of the initial extension skeleton.
 *
 * It exists so the quality gates, the dependency injection wiring and both
 * test suites have something to verify while the actual implementation is
 * being built.
 *
 * Services are wired through Symfony dependency injection attributes on the
 * class itself, not through `Configuration/Services.php`. Services are private
 * by default; classes belonging to the public API are published explicitly with
 * `#[Autoconfigure(public: true)]`, as done here.
 *
 * @todo Remove along with its tests as soon as the first real implementation
 *       is added.
 */
#[Autoconfigure(public: true)]
final readonly class Dummy
{
    public function getExtensionKey(): string
    {
        return 'extension_skeleton';
    }
}
