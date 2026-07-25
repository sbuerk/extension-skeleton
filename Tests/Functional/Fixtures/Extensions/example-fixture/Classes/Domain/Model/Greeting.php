<?php

declare(strict_types=1);

namespace TESTS\ExampleFixture\Domain\Model;

use Symfony\Component\DependencyInjection\Attribute\Exclude;
use TYPO3\CMS\Extbase\DomainObject\AbstractEntity;

/**
 * Extbase model of the greeting table of the fixture extension.
 *
 * A model is data, not a service: `#[Exclude]` keeps it out of the dependency
 * injection container, which would otherwise pick it up through the resource
 * loading in `Configuration/Services.php`. It carries no dependencies and is
 * instantiated by the Extbase data mapper. `AbstractEntity` brings the
 * language and version awareness of the record along — `_languageUid`,
 * `_localizedUid` and `_versionedUid` are filled by the data mapper from the
 * overlaid row, which is what a test asserting language behaviour looks at.
 *
 * The properties are not `readonly`: the data mapper assigns them by reflection
 * on an instance created without calling the constructor, which a readonly
 * property does not allow.
 */
#[Exclude]
final class Greeting extends AbstractEntity
{
    protected string $title = '';

    protected string $message = '';

    public function getTitle(): string
    {
        return $this->title;
    }

    public function getMessage(): string
    {
        return $this->message;
    }
}
