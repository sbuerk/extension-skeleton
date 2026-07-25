..  include:: /Includes.rst.txt

..  _introduction:

============
Introduction
============

What does it do?
================

The :guilabel:`Extension Skeleton` extension supports TYPO3 v13 and v14
within one code base. Core version specific implementations are provided
through :ref:`core version aware <introduction-core-version-aware>` classes
and are wired by the dependency injection container of the running TYPO3
version.

..  note::

    The extension is currently being built up. This chapter is extended along
    with the implemented features.

..  _introduction-core-version-aware:

Core version aware implementations
==================================

Code that has to differ between the supported TYPO3 versions lives below
:file:`Core13/` and :file:`Core14/` in the repository root. Shared code —
interfaces, abstract base classes and everything working on both core
versions — lives in :file:`Classes/`.

Only the directory matching the running TYPO3 version is registered in the
dependency injection container, so a service asking for an interface always
receives the implementation matching the current core version.

Compatibility
=============

..  list-table::
    :header-rows: 1

    *   -   Branch
        -   Extension
        -   TYPO3
        -   PHP
    *   -   main
        -   1.x
        -   v13 / v14
        -   8.2 - 8.5

Contributing
============

Contributions are welcome. The development setup, the quality gates and the
commit message rules are described in the :file:`CONTRIBUTING.md` file of the
`source repository <https://github.com/sbuerk/extension-skeleton>`__.
