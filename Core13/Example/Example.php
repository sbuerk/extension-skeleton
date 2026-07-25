<?php

declare(strict_types=1);

namespace SBUERK\ExtensionSkeleton\Core13\Example;

use SBUERK\ExtensionSkeleton\Example\AbstractExample;
use SBUERK\ExtensionSkeleton\Example\ExampleInterface;
use Symfony\Component\DependencyInjection\Attribute\AsAlias;

/**
 * TYPO3 v13 implementation of {@see ExampleInterface}.
 *
 * Only the `Core13/` directory is registered in the dependency
 * injection container when running on TYPO3 v13, see
 * `Configuration/Services.php`. `#[AsAlias]` makes this class the default
 * implementation of the interface, so consumers type hint the interface and
 * receive the implementation matching the running TYPO3 version.
 *
 * The class is `final readonly`, which requires its abstract base class to be
 * `readonly` too — PHP demands the whole hierarchy to agree on it.
 *
 * @todo Remove along with the interface and its tests as soon as the first real
 *       implementation is added.
 */
#[AsAlias(id: ExampleInterface::class, public: true)]
final readonly class Example extends AbstractExample
{
    public function example(): string
    {
        return sprintf('Example implementation for TYPO3 v%d', $this->coreMajorVersion());
    }
}
