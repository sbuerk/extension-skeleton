<?php

declare(strict_types=1);

use Symfony\Component\DependencyInjection\Loader\Configurator\ContainerConfigurator;

/**
 * Dependency injection wiring of the fixture extension.
 *
 * Deliberately generic: it does nothing but register the classes of the
 * extension, exactly like the file of a real extension would. Services are
 * published and wired through Symfony dependency injection attributes on the
 * classes themselves, not here.
 *
 * The fixture extension is not core version aware, so — unlike
 * `Configuration/Services.php` of the extension itself — there is no `Core13/`
 * and `Core14/` split to resolve.
 */
return static function (ContainerConfigurator $configurator): void {
    $services = $configurator->services();

    $services->defaults()
        ->autowire()
        ->autoconfigure()
        ->private();

    $services->load(
        'TESTS\\ExampleFixture\\',
        __DIR__ . '/../Classes/*',
    );
};
