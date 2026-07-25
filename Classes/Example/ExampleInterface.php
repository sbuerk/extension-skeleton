<?php

declare(strict_types=1);

namespace SBUERK\ExtensionSkeleton\Example;

/**
 * Example of a core version aware service contract.
 *
 * Consumers depend on this interface only. The implementation matching the
 * running TYPO3 version is provided by the core version aware classes below
 * `Core13/` and `Core14/`, which register themselves as the default
 * implementation of this interface with the Symfony dependency injection
 * attribute `#[AsAlias]`.
 *
 * @todo Remove along with its implementations and tests as soon as the first
 *       real implementation is added.
 */
interface ExampleInterface
{
    public function example(): string;
}
