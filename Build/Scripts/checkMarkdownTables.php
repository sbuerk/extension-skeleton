<?php

declare(strict_types=1);

use Symfony\Component\Console\Output\ConsoleOutput;
use Symfony\Component\Finder\Finder;

require_once __DIR__ . '/../../.Build/vendor/autoload.php';
require_once __DIR__ . '/MarkdownTableFormatter.php';

/**
 * Quality gate over the Markdown tables of "./*.md" and "docs/". The algorithm
 * lives in "MarkdownTableFormatter.php", which is dependency free so that
 * "initializeRepository.sh" can use it in a repository where nothing is
 * installed yet; this file adds the file traversal and the reporting.
 *
 * Run "--fix" to rewrite the files instead of only reporting them:
 *
 *   Build/Scripts/runTests.sh -s checkMarkdownTables
 *   Build/Scripts/runTests.sh -s checkMarkdownTables -- --fix
 *
 * See the documentation conventions in "docs/Index.md".
 */
$fix = in_array('--fix', array_slice($argv, 1), true);
$output = new ConsoleOutput();
$root = dirname(__DIR__, 2);

$finder = new Finder();
$finder->files()
    ->ignoreVCSIgnored(true)
    ->name('*.md')
    ->in($root)
    ->depth(0);

$documentation = new Finder();
$documentation->files()
    ->ignoreVCSIgnored(true)
    ->name('*.md')
    ->in($root . '/docs');

$formatter = new MarkdownTableFormatter();
$offenders = [];
$checked = 0;

foreach ([$finder, $documentation] as $set) {
    foreach ($set as $file) {
        // Symlinked files are duplicates of their target, which is checked itself.
        if ($file->isLink()) {
            continue;
        }
        $checked++;
        $content = (string)file_get_contents($file->getPathname());
        [$formatted, $changed] = $formatter->format($content);
        if (!$changed) {
            continue;
        }
        $offenders[] = substr($file->getPathname(), strlen($root) + 1);
        if ($fix) {
            file_put_contents($file->getPathname(), $formatted);
        }
    }
}

if ($offenders === []) {
    $output->writeln(sprintf('<info>Checked %d markdown files, all tables are formatted.</info>', $checked));
    exit(0);
}

if ($fix) {
    $output->writeln(sprintf('<info>Formatted tables in %d of %d markdown files:</info>', count($offenders), $checked));
    $output->writeln(array_map(static fn(string $file): string => '  ' . $file, $offenders));
    exit(0);
}

$output->writeln(sprintf('<error>Found unformatted tables in %d of %d markdown files:</error>', count($offenders), $checked));
$output->writeln(array_map(static fn(string $file): string => '  ' . $file, $offenders));
$output->writeln('');
$output->writeln('Pad every cell so the pipes line up, or run:');
$output->writeln('  Build/Scripts/runTests.sh -s checkMarkdownTables -- --fix');
exit(1);
