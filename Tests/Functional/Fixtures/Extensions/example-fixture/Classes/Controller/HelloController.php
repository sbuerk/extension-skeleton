<?php

declare(strict_types=1);

namespace TESTS\ExampleFixture\Controller;

use Psr\Http\Message\ResponseInterface;
use TYPO3\CMS\Core\Site\Entity\SiteLanguage;
use TYPO3\CMS\Extbase\Mvc\Controller\ActionController;

/**
 * Controller of the "Hello" plugin of the fixture extension.
 *
 * It renders a static greeting prefixed with the language code of the site
 * language the request was resolved to, which is all a site based test needs to
 * tell the languages of a frontend response apart — see the "Site based tests"
 * page of the developer documentation in "docs/testing/".
 *
 * The site language is read from the request attribute rather than from the
 * language aspect, because that is the same in TYPO3 v13 and v14 and needs no
 * core version aware code in a fixture extension.
 */
final class HelloController extends ActionController
{
    public function indexAction(): ResponseInterface
    {
        $language = $this->request->getAttribute('language');

        $this->view->assign(
            'languageKey',
            $language instanceof SiteLanguage
                ? strtoupper($language->getLocale()->getLanguageCode())
                : 'UNRESOLVED',
        );

        return $this->htmlResponse();
    }
}
