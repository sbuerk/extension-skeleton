<?php

declare(strict_types=1);

use Symfony\Component\Console\Output\ConsoleOutput;

require_once __DIR__ . '/../../.Build/vendor/autoload.php';
require_once __DIR__ . '/MarkdownTableFormatter.php';

/**
 * Regression test for "Build/Scripts/initializeRepository.sh".
 *
 * That script runs exactly once per repository created from this template, in a
 * GitHub Actions job nobody is watching. When it produces a wrong identifier the
 * result is a repository that does not resolve its own dependencies — so it is
 * worth proving rather than assuming.
 *
 * The check initializes a throwaway copy of the working tree under several
 * repository references and asserts the outcome. The references are derived from
 * the current package name, not hardcoded, so this keeps testing the right thing
 * in a repository created from this template.
 *
 * The interesting cases are the ones where the new repository name contains the
 * current one — as a prefix, a suffix or in the middle. Replacements applied one
 * after the other into the same buffer expand such a name twice, which is what
 * turned "sbuerk/test-extension-skeleton-demo" into
 * "sbuerk/test-test-extension-skeleton-demo-demo".
 *
 *   Build/Scripts/runTests.sh -s checkRepositoryInitialization
 *
 * What this does not cover: the bare owner. It is rewritten too, but it also
 * legitimately survives inside dependency package names, so "is it gone" is not
 * a property that can be asserted. The protected token assertion covers the part
 * that actually breaks a repository.
 *
 * See "docs/workflow/repository-initialization.md".
 */
final class RepositoryInitializationCheck
{
    /**
     * Directories the working tree copy never contains. Everything else is taken
     * from "git ls-files", which is the same file list the script itself uses.
     */
    private const WORKSPACE = '.Build/repository-initialization';

    private string $currentPackage;
    private string $currentOwner;
    private string $currentRepository;
    private string $currentExtensionKey;
    private string $currentNamespace;
    private string $currentTitle;

    /** @var array<int, string> */
    private array $failures = [];

    public function __construct(
        private readonly string $root,
        private readonly ConsoleOutput $output,
    ) {}

    public function run(): int
    {
        $composerJson = $this->readComposerJson($this->root . '/composer.json');
        $this->currentPackage = (string)($composerJson['name'] ?? '');
        $this->currentExtensionKey = (string)($composerJson['extra']['typo3/cms']['extension-key'] ?? '');
        if ($this->currentPackage === '' || !str_contains($this->currentPackage, '/')) {
            $this->output->writeln('<error>composer.json has no usable "name".</error>');

            return 1;
        }
        [$this->currentOwner, $this->currentRepository] = explode('/', $this->currentPackage, 2);
        $this->currentNamespace = $this->camelCase($this->currentRepository);
        $this->currentTitle = $this->title($this->currentRepository);

        $sourceFiles = $this->trackedFiles();
        if ($sourceFiles === []) {
            $this->output->writeln('<error>Could not list the tracked files — is "git" available?</error>');

            return 1;
        }

        $this->output->writeln(sprintf(
            'Checking "Build/Scripts/initializeRepository.sh" against %s, %d files.',
            $this->currentPackage,
            count($sourceFiles),
        ));

        foreach ($this->cases() as $label => $reference) {
            $this->checkReference($label, $reference, $sourceFiles);
        }
        $this->checkDryRunChangesNothing($sourceFiles);
        $this->checkSecondRunIsANoOp($sourceFiles);

        $this->removeDirectory($this->root . '/' . self::WORKSPACE);

        if ($this->failures !== []) {
            $this->output->writeln('');
            $this->output->writeln(sprintf('<error>%d assertion(s) failed:</error>', count($this->failures)));
            foreach ($this->failures as $failure) {
                $this->output->writeln('  ' . $failure);
            }

            return 1;
        }

        $this->output->writeln('<info>Repository initialization is correct for every checked reference.</info>');

        return 0;
    }

    /**
     * The references to initialize to. Three of them contain the current
     * repository name, which is the case that regressed.
     *
     * @return array<string, string>
     */
    private function cases(): array
    {
        $owner = $this->currentOwner;
        $repository = $this->currentRepository;
        $otherOwner = $owner === 'example-vendor' ? 'other-vendor' : 'example-vendor';

        return [
            'name contains the current one in the middle' => sprintf('%s/test-%s-demo', $owner, $repository),
            'name starts with something new' => sprintf('%s/my-%s', $owner, $repository),
            'name ends with something new' => sprintf('%s/%s-extra', $owner, $repository),
            'unrelated name, same owner' => sprintf('%s/renamed-extension', $owner),
            'unrelated name, different owner' => sprintf('%s/renamed-extension', $otherOwner),
            'mixed case and separators' => sprintf('%s/Some.Fancy_Thing', ucfirst($otherOwner)),
        ];
    }

    /**
     * @param array<int, string> $sourceFiles
     */
    private function checkReference(string $label, string $reference, array $sourceFiles): void
    {
        [$owner, $repository] = explode('/', $reference, 2);
        $expectedPackage = strtolower($owner) . '/' . strtolower($repository);
        $expectedKey = $this->extensionKey($repository);
        $expectedNamespace = $this->vendorNamespace($owner) . '\\' . $this->camelCase($repository);

        $workspace = $this->prepare($sourceFiles, $this->slug($reference));
        [$exitCode, $log] = $this->initialize($workspace, [$reference, '--skip-cgl']);

        if ($exitCode !== 0) {
            $this->fail($label, sprintf('the script exited with %d: %s', $exitCode, $this->lastLine($log)));

            return;
        }

        $composerJson = $this->readComposerJson($workspace . '/composer.json');
        $this->assertSame($label, 'composer.json name', $expectedPackage, (string)($composerJson['name'] ?? ''));
        $this->assertSame(
            $label,
            'extension key',
            $expectedKey,
            (string)($composerJson['extra']['typo3/cms']['extension-key'] ?? ''),
        );

        $this->assertNamespaces($label, $composerJson, $expectedNamespace);
        $this->assertDeclaredNamespaces($label, $workspace, $expectedNamespace);
        $this->assertNoPlaceholders($label, $workspace);
        $this->assertDependenciesSurvived($label, $workspace);
        $this->assertNoStaleIdentifiers($label, $workspace, $expectedPackage, $expectedKey, $expectedNamespace);
        $this->assertMarkdownTablesFormatted($label, $workspace);

        $this->removeDirectory($workspace);
    }

    /**
     * Every PSR-4 prefix has to sit below the new root namespace, and the
     * shortest one has to be that root itself. Asserted this way rather than
     * against a fixed list, so restructuring "Classes/" downstream does not turn
     * into a failure here.
     *
     * @param array<string, mixed> $composerJson
     */
    private function assertNamespaces(string $label, array $composerJson, string $expectedNamespace): void
    {
        foreach (['autoload' => '', 'autoload-dev' => 'Tests\\'] as $section => $suffix) {
            /** @var array<string, string> $map */
            $map = $composerJson[$section]['psr-4'] ?? [];
            if ($map === []) {
                continue;
            }
            $prefixes = array_keys($map);
            usort($prefixes, static fn(string $a, string $b): int => strlen($a) <=> strlen($b));
            $this->assertSame(
                $label,
                sprintf('%s root namespace', $section),
                $expectedNamespace . '\\' . $suffix,
                $prefixes[0],
            );
            foreach ($prefixes as $prefix) {
                if (!str_starts_with($prefix, $expectedNamespace . '\\')) {
                    $this->fail($label, sprintf('PSR-4 prefix "%s" is not below "%s\\"', $prefix, $expectedNamespace));
                }
            }
        }
    }

    /**
     * composer.json may claim the right namespace while the PHP files still
     * declare the old one — that is exactly what a half applied rewrite looks
     * like, so the files are checked separately.
     *
     * Checked by namespace rather than by directory: "autoload-dev" maps
     * "Tests/", which also holds the fixture extensions, and those carry an
     * unrelated namespace on purpose.
     */
    private function assertDeclaredNamespaces(string $label, string $workspace, string $expectedNamespace): void
    {
        $old = $this->vendorNamespace($this->currentOwner) . '\\' . $this->currentNamespace;
        $renamed = 0;
        foreach ($this->phpFilesIn($workspace) as $file) {
            if (preg_match('/^namespace\s+([^;]+);/m', (string)file_get_contents($file), $matches) !== 1) {
                continue;
            }
            $declared = trim($matches[1]);
            if ($declared === $old || str_starts_with($declared, $old . '\\')) {
                $this->fail($label, sprintf(
                    '%s still declares "%s"',
                    substr($file, strlen($workspace) + 1),
                    $declared,
                ));

                return;
            }
            if ($declared === $expectedNamespace || str_starts_with($declared, $expectedNamespace . '\\')) {
                $renamed++;
            }
        }
        if ($renamed === 0) {
            $this->fail($label, sprintf('no PHP file declares a namespace below "%s"', $expectedNamespace));
        }
    }

    /**
     * The script masks identifiers with placeholders while it works. One left
     * behind means a mask was never restored.
     */
    private function assertNoPlaceholders(string $label, string $workspace): void
    {
        foreach ($this->contentLines($workspace) as [$file, $number, $line]) {
            if (preg_match('/@@(REPLACEMENT|PROTECTED)-\d+@@/', $line) === 1) {
                $this->fail($label, sprintf('leftover placeholder in %s:%d', $file, $number));

                return;
            }
        }
    }

    /**
     * An identifier inside a table cell changes the width of its column when it
     * is renamed, and a longer repository name is enough. Without the
     * reformatting step the "checkMarkdownTables" gate then fails in the very
     * first pipeline run of the new repository, on a file nobody touched — which
     * is exactly how this was reported.
     */
    private function assertMarkdownTablesFormatted(string $label, string $workspace): void
    {
        $formatter = new MarkdownTableFormatter();
        foreach ($this->filesIn($workspace) as $file) {
            if (!str_ends_with($file, '.md')) {
                continue;
            }
            [, $changed] = $formatter->format((string)file_get_contents($file));
            if ($changed) {
                $this->fail($label, sprintf(
                    'unformatted markdown table in %s',
                    substr($file, strlen($workspace) + 1),
                ));

                return;
            }
        }
    }

    /**
     * A dependency package name is never an identifier of this repository, and
     * rewriting one produces a repository that cannot install itself.
     */
    private function assertDependenciesSurvived(string $label, string $workspace): void
    {
        $source = $this->readComposerJson($this->root . '/composer.json');
        /** @var array<string, string> $require */
        $require = array_merge($source['require'] ?? [], $source['require-dev'] ?? []);
        $initialized = (string)file_get_contents($workspace . '/composer.json');
        foreach (array_keys($require) as $package) {
            if (!str_contains($package, '/')) {
                continue;
            }
            if (!str_contains($initialized, '"' . $package . '"')) {
                $this->fail($label, sprintf('dependency "%s" no longer appears in composer.json', $package));
            }
        }
    }

    /**
     * No template identifier may survive. The new identifiers are removed from
     * the line first: a new name may legitimately contain the old one, which is
     * the whole point of these cases.
     */
    private function assertNoStaleIdentifiers(
        string $label,
        string $workspace,
        string $expectedPackage,
        string $expectedKey,
        string $expectedNamespace,
    ): void {
        $newTokens = [
            substr($expectedNamespace, strpos($expectedNamespace, '\\') + 1),
            substr($expectedPackage, strpos($expectedPackage, '/') + 1),
            $expectedKey,
            $this->title(substr($expectedPackage, strpos($expectedPackage, '/') + 1)),
        ];
        $staleTokens = array_filter([
            $this->currentPackage,
            $this->currentRepository,
            $this->currentExtensionKey,
            $this->currentNamespace,
            $this->currentTitle,
        ]);

        foreach ($this->contentLines($workspace) as [$file, $number, $line]) {
            // The script never rewrites itself, so its generic examples stay.
            if ($file === 'Build/Scripts/initializeRepository.sh') {
                continue;
            }
            $stripped = str_replace($newTokens, '', $line);
            foreach ($staleTokens as $token) {
                if (str_contains($stripped, $token)) {
                    $this->fail($label, sprintf(
                        'template identifier "%s" survived in %s:%d%s',
                        $token,
                        $file,
                        $number,
                        str_starts_with($file, '.github/workflows/')
                            ? ' (workflow files are never rewritten — derive the value at runtime)'
                            : '',
                    ));

                    return;
                }
            }
        }
    }

    /**
     * @param array<int, string> $sourceFiles
     */
    private function checkDryRunChangesNothing(array $sourceFiles): void
    {
        $label = '--dry-run';
        $workspace = $this->prepare($sourceFiles, 'dry-run');
        $before = $this->fingerprint($workspace);
        [$exitCode, $log] = $this->initialize($workspace, [
            sprintf('%s/dry-run-target', $this->currentOwner),
            '--dry-run',
            '--skip-cgl',
        ]);

        if ($exitCode !== 0) {
            $this->fail($label, sprintf('the script exited with %d: %s', $exitCode, $this->lastLine($log)));
        } elseif ($this->fingerprint($workspace) !== $before) {
            $this->fail($label, 'the working tree was modified');
        }

        $this->removeDirectory($workspace);
    }

    /**
     * Initializing twice to the same reference has to be recognized and do
     * nothing — the workflow triggers on more than one event.
     *
     * @param array<int, string> $sourceFiles
     */
    private function checkSecondRunIsANoOp(array $sourceFiles): void
    {
        $label = 'second run';
        $reference = sprintf('%s/rerun-target', $this->currentOwner);
        $workspace = $this->prepare($sourceFiles, 'rerun');

        [$exitCode, $log] = $this->initialize($workspace, [$reference, '--skip-cgl']);
        if ($exitCode !== 0) {
            $this->fail($label, sprintf('the first run exited with %d: %s', $exitCode, $this->lastLine($log)));
            $this->removeDirectory($workspace);

            return;
        }

        $before = $this->fingerprint($workspace);
        [$exitCode, $log] = $this->initialize($workspace, [$reference, '--skip-cgl']);
        if ($exitCode !== 0) {
            $this->fail($label, sprintf('the second run exited with %d: %s', $exitCode, $this->lastLine($log)));
        } elseif ($this->fingerprint($workspace) !== $before) {
            $this->fail($label, 'the second run modified the working tree again');
        }

        $this->removeDirectory($workspace);
    }

    /**
     * Copies the working tree into a throwaway directory and makes it a
     * repository of its own.
     *
     * "git init" is not cosmetic: without it the copy sits inside this
     * repository's working tree, the script finds the outer repository and lists
     * its files instead of the copied ones.
     *
     * @param array<int, string> $files
     */
    private function prepare(array $files, string $name): string
    {
        $workspace = $this->root . '/' . self::WORKSPACE . '/' . $name;
        $this->removeDirectory($workspace);
        if (!mkdir($workspace, 0o777, true) && !is_dir($workspace)) {
            throw new RuntimeException(sprintf('Could not create "%s".', $workspace), 1785010001);
        }

        foreach ($files as $file) {
            $source = $this->root . '/' . $file;
            $target = $workspace . '/' . $file;
            $directory = dirname($target);
            if (!is_dir($directory) && !mkdir($directory, 0o777, true) && !is_dir($directory)) {
                throw new RuntimeException(sprintf('Could not create "%s".', $directory), 1785010002);
            }
            // Symlinks stay symlinks: the script skips them, and copying them as
            // regular files would have it rewrite the same content twice.
            if (is_link($source)) {
                symlink((string)readlink($source), $target);
                continue;
            }
            if (!is_file($source)) {
                continue;
            }
            copy($source, $target);
            chmod($target, (int)(fileperms($source) & 0o777));
        }

        $this->execute($workspace, 'git init -q && git add -A');

        return $workspace;
    }

    /**
     * @param array<int, string> $arguments
     * @return array{0: int, 1: string}
     */
    private function initialize(string $workspace, array $arguments): array
    {
        $command = 'Build/Scripts/initializeRepository.sh ' . implode(
            ' ',
            array_map(static fn(string $argument): string => escapeshellarg($argument), $arguments),
        );

        return $this->execute($workspace, $command);
    }

    /**
     * @return array{0: int, 1: string}
     */
    private function execute(string $workspace, string $command): array
    {
        $descriptors = [1 => ['pipe', 'w'], 2 => ['pipe', 'w']];
        $process = proc_open($command . ' 2>&1', $descriptors, $pipes, $workspace, $this->environment());
        if (!is_resource($process)) {
            return [1, sprintf('could not run "%s"', $command)];
        }
        $log = (string)stream_get_contents($pipes[1]);
        fclose($pipes[1]);
        fclose($pipes[2]);

        return [proc_close($process), $log];
    }

    /**
     * git refuses to operate in a directory owned by a different user. In CI the
     * container runs as root against a checkout owned by the runner user, which
     * is exactly that situation, and it would take down both the file listing
     * below and the "git ls-files" the script itself prefers.
     *
     * Passed as environment rather than written to a git config file, so nothing
     * outside these child processes is affected.
     *
     * @return array<string, string>
     */
    private function environment(): array
    {
        /** @var array<string, string> $environment */
        $environment = getenv();

        return array_merge($environment, [
            'GIT_CONFIG_COUNT' => '1',
            'GIT_CONFIG_KEY_0' => 'safe.directory',
            'GIT_CONFIG_VALUE_0' => '*',
        ]);
    }

    /**
     * @return array<int, string>
     */
    private function trackedFiles(): array
    {
        [$exitCode, $log] = $this->execute($this->root, 'git ls-files');
        if ($exitCode !== 0) {
            return [];
        }

        return array_values(array_filter(array_map('trim', explode("\n", $log))));
    }

    /**
     * Path and content of every file, so a change anywhere shows up.
     */
    private function fingerprint(string $workspace): string
    {
        $entries = [];
        foreach ($this->filesIn($workspace) as $file) {
            $entries[] = substr($file, strlen($workspace) + 1) . ':' . sha1_file($file);
        }
        sort($entries);

        return sha1(implode("\n", $entries));
    }

    /**
     * @return iterable<array{0: string, 1: int, 2: string}> relative path, line number, line
     */
    private function contentLines(string $workspace): iterable
    {
        foreach ($this->filesIn($workspace) as $file) {
            $content = (string)file_get_contents($file);
            // Binary files carry no identifiers and would only produce noise.
            if (str_contains($content, "\0")) {
                continue;
            }
            $relative = substr($file, strlen($workspace) + 1);
            foreach (explode("\n", $content) as $index => $line) {
                yield [$relative, $index + 1, $line];
            }
        }
    }

    /**
     * @return array<int, string>
     */
    private function filesIn(string $directory): array
    {
        $files = [];
        $iterator = new RecursiveIteratorIterator(
            new RecursiveCallbackFilterIterator(
                new RecursiveDirectoryIterator($directory, FilesystemIterator::SKIP_DOTS),
                static fn(SplFileInfo $current): bool => $current->getFilename() !== '.git',
            ),
        );
        foreach ($iterator as $file) {
            if ($file instanceof SplFileInfo && $file->isFile() && !$file->isLink()) {
                $files[] = $file->getPathname();
            }
        }
        sort($files);

        return $files;
    }

    /**
     * @return array<int, string>
     */
    private function phpFilesIn(string $directory): array
    {
        return array_values(array_filter(
            $this->filesIn($directory),
            static fn(string $file): bool => str_ends_with($file, '.php'),
        ));
    }

    /**
     * @return array<string, mixed>
     */
    private function readComposerJson(string $path): array
    {
        $decoded = json_decode((string)file_get_contents($path), true);

        return is_array($decoded) ? $decoded : [];
    }

    // The four derivations below mirror the ones in
    // "Build/Scripts/initializeRepository.sh". They are written out a second
    // time on purpose: a check that reuses the implementation it verifies proves
    // nothing about it.

    private function extensionKey(string $repository): string
    {
        $value = (string)preg_replace('/[^a-z0-9_]/', '', str_replace(['-', '.', ' '], '_', strtolower($repository)));
        while (str_contains($value, '__')) {
            $value = str_replace('__', '_', $value);
        }

        return trim($value, '_');
    }

    private function vendorNamespace(string $owner): string
    {
        return strtoupper((string)preg_replace('/[\s._-]/', '', $owner));
    }

    private function camelCase(string $repository): string
    {
        return implode('', array_map(
            static fn(string $part): string => ucfirst($part),
            $this->parts($repository),
        ));
    }

    private function title(string $repository): string
    {
        return implode(' ', array_map(
            static fn(string $part): string => ucfirst($part),
            $this->parts($repository),
        ));
    }

    /**
     * @return array<int, string>
     */
    private function parts(string $repository): array
    {
        return array_values(array_filter((array)preg_split('/[-._ ]+/', $repository)));
    }

    private function slug(string $reference): string
    {
        return (string)preg_replace('/[^A-Za-z0-9]+/', '-', $reference);
    }

    private function lastLine(string $log): string
    {
        $lines = array_values(array_filter(array_map('trim', explode("\n", $log))));

        return $lines === [] ? '(no output)' : (string)end($lines);
    }

    private function assertSame(string $label, string $what, string $expected, string $actual): void
    {
        if ($expected !== $actual) {
            $this->fail($label, sprintf('%s is "%s", expected "%s"', $what, $actual, $expected));
        }
    }

    private function fail(string $label, string $message): void
    {
        $this->failures[] = sprintf('<error>%s</error> — %s', $label, $message);
    }

    private function removeDirectory(string $directory): void
    {
        if (!is_dir($directory)) {
            return;
        }
        $iterator = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator($directory, FilesystemIterator::SKIP_DOTS),
            RecursiveIteratorIterator::CHILD_FIRST,
        );
        foreach ($iterator as $entry) {
            if ($entry instanceof SplFileInfo && $entry->isDir() && !$entry->isLink()) {
                rmdir($entry->getPathname());
                continue;
            }
            unlink((string)$entry);
        }
        rmdir($directory);
    }
}

exit((new RepositoryInitializationCheck(dirname(__DIR__, 2), new ConsoleOutput()))->run());
