..  include:: /Includes.rst.txt

..  _installation:

============
Installation
============

The extension has to be installed like any other TYPO3 CMS extension.

Composer mode
=============

..  code-block:: bash

    composer require sbuerk/extension-skeleton

..  note::

    As long as no stable version has been released, the development version of
    the main branch has to be required explicitly:

    ..  code-block:: bash

        composer require sbuerk/extension-skeleton:^1.0@dev

    This additionally requires ``minimum-stability`` to be set to ``dev``
    together with ``prefer-stable`` set to ``true`` in the root
    :file:`composer.json` file.

Classic mode
============

#.  **Get it from the Extension Manager**:
    Switch to the module :guilabel:`Admin Tools > Extensions`, switch to
    :guilabel:`Get Extensions` and search for the extension key
    *extension_skeleton*, then import the extension from the repository.

#.  **Get it from typo3.org**:
    You can always get the current version from `TER`_ by downloading the zip
    version. Upload the file afterwards in the Extension Manager.

..  _TER: https://extensions.typo3.org/extension/extension_skeleton

The extension does not require any further configuration yet.
