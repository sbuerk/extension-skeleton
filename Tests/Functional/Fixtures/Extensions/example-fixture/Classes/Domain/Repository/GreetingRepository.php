<?php

declare(strict_types=1);

namespace TESTS\ExampleFixture\Domain\Repository;

use Symfony\Component\DependencyInjection\Attribute\Autoconfigure;
use TESTS\ExampleFixture\Domain\Model\Greeting;
use TYPO3\CMS\Core\Context\LanguageAspect;
use TYPO3\CMS\Extbase\Persistence\QueryInterface;
use TYPO3\CMS\Extbase\Persistence\QueryResultInterface;
use TYPO3\CMS\Extbase\Persistence\Repository;

/**
 * Repository of {@see Greeting}.
 *
 * The two methods differ in exactly one query setting, which is the point of
 * the fixture: the first one answers differently depending on the language
 * context the environment was built with, the second one does not. A test can
 * therefore prove that a language context was applied at all, rather than
 * assuming it.
 *
 * `#[Autoconfigure(public: true)]` is required, not decoration: a repository is
 * fetched from the container by consumers — and by the functional test — while
 * the dependency injection defaults of the extension keep services private.
 *
 * @extends Repository<Greeting>
 */
#[Autoconfigure(public: true)]
final class GreetingRepository extends Repository
{
    /**
     * Records of the language the environment was built for, with the default
     * language records overlaid according to the fallback configuration of the
     * site language.
     *
     * @return QueryResultInterface<int, Greeting>
     */
    public function findAllInLanguageContext(): QueryResultInterface
    {
        $query = $this->createQuery();
        // A functional test has no TypoScript "persistence.storagePid", so
        // without this the query would look for records on page 0 only.
        $query->getQuerySettings()->setRespectStoragePage(false);
        $query->setOrderings(['uid' => QueryInterface::ORDER_ASCENDING]);

        return $query->execute();
    }

    /**
     * The default language records, whatever the language context is.
     *
     * Pinning the language aspect is what a command or a scheduler task does
     * when it must always read the same rows — for example to write a report or
     * to feed an import. `OVERLAYS_OFF` is the important part: without it the
     * rows would still be overlaid with the translation of the current
     * language, and only the *selection* would be pinned.
     *
     * @return QueryResultInterface<int, Greeting>
     */
    public function findAllInDefaultLanguage(): QueryResultInterface
    {
        $query = $this->createQuery();
        $query->getQuerySettings()->setRespectStoragePage(false);
        $query->getQuerySettings()->setLanguageAspect(
            new LanguageAspect(0, 0, LanguageAspect::OVERLAYS_OFF),
        );
        $query->setOrderings(['uid' => QueryInterface::ORDER_ASCENDING]);

        return $query->execute();
    }
}
