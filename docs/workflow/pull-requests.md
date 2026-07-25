# Pull requests

1. Create a topic branch off `main` — for example `feature/example-service` or
   `bugfix/empty-response`.
2. Keep commits focused; one logical change per commit, following the
   [commit message rules](commit-messages.md).
3. Make sure the quality gates and both test suites pass locally before opening
   the pull request:

   ```bash
   Build/Scripts/runTests.sh -s cgl -n
   Build/Scripts/runTests.sh -s phpstan
   Build/Scripts/runTests.sh -s lintPhp
   Build/Scripts/runTests.sh -s unit
   Build/Scripts/runTests.sh -s unitRandom
   Build/Scripts/runTests.sh -s functional -d sqlite
   Build/Scripts/runTests.sh -s composerValidate
   Build/Scripts/runTests.sh -s checkBom
   Build/Scripts/runTests.sh -s checkExceptionCodes
   Build/Scripts/runTests.sh -s checkMarkdownTables
   Build/Scripts/runTests.sh -s checkRepositoryInitialization
   Build/Scripts/runTests.sh -s checkTestMethodsPrefix
   Build/Scripts/runTests.sh -s renderDocumentation
   ```

   Repeat all of it for **both** supported TYPO3 versions (`-t 13` and `-t 14`,
   each after the matching `composerUpdate`) — see
   [Dual core setup](../development/dual-core-setup.md#verifying-a-change).

   Run the functional suite against at least one other DBMS
   (`-d mariadb -i 10.6`, `mysql`, `postgres`) when the change touches queries,
   schema or TCA.
4. Update the documentation in the same pull request: the
   [`docs/`](../Index.md) page covering what changed, and a changelog entry
   below `Documentation/Changelog/` for user facing changes. See
   [Changelog and documentation](changelog-and-documentation.md).
5. Open the pull request against `main`, describing what changes and why. The
   [CI workflow](../../.github/workflows/ci.yml) runs the full matrix for TYPO3
   v13 and v14, and comments the rendered documentation on the pull request —
   for a fork as well, see
   [continuous integration](../development/quality-gates.md#continuous-integration).
6. Address review feedback by amending or adding commits; keep the history
   readable — squash fixup commits before the pull request is merged.

## See also

- [Commit messages](commit-messages.md)
- [Quality gates](../development/quality-gates.md)
- [Releasing](releasing.md)
