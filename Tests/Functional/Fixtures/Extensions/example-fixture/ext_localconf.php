<?php

declare(strict_types=1);

use TESTS\ExampleFixture\Controller\HelloController;
use TYPO3\CMS\Extbase\Utility\ExtensionUtility;

defined('TYPO3') or die();

// Registers the controller actions of the plugin and the TypoScript rendering
// definition of its content element.
//
// The plugin type is passed explicitly, and it has to be: TYPO3 v13 still
// defaults to "list_type" and triggers a deprecation for it, while v14 removed
// that plugin content element and throws for anything but "CType". Naming
// "CType" is the one call that is correct on both, so this file needs no core
// version switch.
//
// "Configuration/TCA/Overrides/tt_content.php" then takes no plugin type at
// all: ExtensionUtility::registerPlugin() reads it back from what this file
// registered, and "ext_localconf.php" is loaded before the TCA overrides.
ExtensionUtility::configurePlugin(
    'TestsExampleFixture',
    'Hello',
    [
        HelloController::class => 'index',
    ],
    [],
    ExtensionUtility::PLUGIN_TYPE_CONTENT_ELEMENT,
);
