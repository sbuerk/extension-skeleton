..  include:: /Includes.rst.txt

..  _feature-initial-extension-skeleton:

===================================
Feature: Initial extension skeleton
===================================

Description
===========

Initial skeleton of the ``sbuerk/extension-skeleton`` extension, providing the
project setup the actual implementation is built on:

*   TYPO3 v13 and v14 support on PHP 8.2 up to 8.5, with core version aware
    implementations below :file:`Core13/` and :file:`Core14/`.
*   Dependency injection wiring through :file:`Configuration/Services.php`,
    with services configured by Symfony dependency injection attributes on the
    classes themselves.
*   Container based tooling through :file:`Build/Scripts/runTests.sh` covering
    linting, coding guidelines, static analysis, unit and functional tests and
    documentation rendering.
*   GitHub Actions workflows running these gates for TYPO3 v13 and v14 on pull
    requests.
*   A functional test setup ready to build on: strict PHPUnit configuration,
    an example fixture extension loaded by its composer package name, site
    based tests issuing frontend sub-requests in several languages, and
    repository tests running in a built frontend environment.
*   Developer documentation below :file:`docs/`, covering the architecture,
    the quality gates, both test suites and the release workflow.

The extension ships a :php:`SBUERK\ExtensionSkeleton\Dummy` placeholder class
and an :php:`SBUERK\ExtensionSkeleton\Example\ExampleInterface` example
service, both meant to be removed once the first real implementation is added.
