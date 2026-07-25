<?php

declare(strict_types=1);

namespace SBUERK\ExtensionSkeleton\Example;

use Symfony\Contracts\Service\Attribute\Required;
use TYPO3\CMS\Core\Information\Typo3Version;

/**
 * Shared implementation of all core version aware {@see ExampleInterface}
 * implementations.
 *
 * Abstract classes must not use constructor injection: the constructor belongs
 * to the extending classes. Dependencies are injected with `inject*()` methods
 * carrying the `#[Required]` attribute instead, so adding a dependency here
 * never changes the constructor signature of the extending classes and never
 * breaks their API.
 *
 * The class is `readonly` so extending classes can be `final readonly` as well —
 * PHP requires the whole hierarchy to agree on it. PHP allows a readonly
 * property to be initialized by any method of its declaring class, which is
 * exactly what the injection method below does; only PHPStan insists on the
 * constructor, which is why the two findings are ignored by their identifier.
 * That combination is the documented way of writing an injected abstract base
 * class here — see the "Class design" section of CONTRIBUTING.md.
 */
abstract readonly class AbstractExample implements ExampleInterface
{
    /** @phpstan-ignore property.uninitializedReadonly */
    protected Typo3Version $typo3Version;

    #[Required]
    public function injectTypo3Version(Typo3Version $typo3Version): void
    {
        /** @phpstan-ignore property.readOnlyAssignNotInConstructor */
        $this->typo3Version = $typo3Version;
    }

    protected function coreMajorVersion(): int
    {
        return $this->typo3Version->getMajorVersion();
    }
}
