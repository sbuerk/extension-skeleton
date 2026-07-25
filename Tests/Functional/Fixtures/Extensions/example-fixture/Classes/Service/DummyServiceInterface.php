<?php

declare(strict_types=1);

namespace TESTS\ExampleFixture\Service;

/**
 * Contract of the dummy service of the fixture extension.
 *
 * The fixture extension exists to prove that a fixture extension can be loaded
 * by its composer package name, so this contract carries no behaviour worth
 * testing on its own — a single method with a static result is enough to show
 * that the class was autoloaded and that the dependency injection wiring of the
 * fixture extension was processed.
 */
interface DummyServiceInterface
{
    public function getExtensionKey(): string;
}
