<?php

declare(strict_types=1);

use TYPO3\CMS\Extbase\Utility\ExtensionUtility;

defined('TYPO3') or die();

// Adds the plugin to the content element type selection, which is what makes
// "testsexamplefixture_hello" a valid CType of a tt_content record.
ExtensionUtility::registerPlugin(
    'TestsExampleFixture',
    'Hello',
    'Example fixture: Hello',
);
