<?php

declare(strict_types=1);

/**
 * Formats Markdown tables: every cell padded so the pipes line up, and the
 * separator row as wide as the widest cell of its column. An unformatted table
 * renders identically, which is why it goes unnoticed until an edit reflows the
 * whole table and buries the actual change in the diff.
 *
 * Alignment markers (":---", "---:", ":---:") are preserved. Tables inside
 * fenced code blocks are left alone, so a page may show an unformatted table as
 * an example.
 *
 * This file carries the algorithm alone and **requires nothing**, neither the
 * composer autoloader nor an installed dependency set. Two callers rely on
 * that:
 *
 *   - "checkMarkdownTables.php", the quality gate, which adds the file
 *     traversal and the reporting on top of it.
 *   - "initializeRepository.sh", which reformats the tables it just widened by
 *     rewriting the template identifiers — in a fresh repository, where nothing
 *     is installed yet.
 *
 * Keep it dependency free.
 *
 * See the documentation conventions in "docs/Index.md".
 */
final class MarkdownTableFormatter
{
    private const SEPARATOR = '/^\|?(\s*:?-+:?\s*\|)*\s*:?-+:?\s*\|?$/';
    private const FENCE = '/^\s*(```|~~~)/';

    /**
     * @return array{0: string, 1: bool} formatted content and whether it differs
     */
    public function format(string $content): array
    {
        $lines = explode("\n", $content);
        $result = [];
        $fenced = false;
        $changed = false;
        $index = 0;
        $count = count($lines);

        while ($index < $count) {
            $line = $lines[$index];
            if (preg_match(self::FENCE, $line) === 1) {
                $fenced = !$fenced;
                $result[] = $line;
                $index++;
                continue;
            }
            if (!$fenced
                && str_starts_with(ltrim($line), '|')
                && isset($lines[$index + 1])
                && preg_match(self::SEPARATOR, trim($lines[$index + 1])) === 1
            ) {
                $block = [];
                while ($index < $count && str_starts_with(ltrim($lines[$index]), '|')) {
                    $block[] = $lines[$index];
                    $index++;
                }
                $formatted = $this->formatBlock($block);
                if ($formatted !== $block) {
                    $changed = true;
                }
                array_push($result, ...$formatted);
                continue;
            }
            $result[] = $line;
            $index++;
        }

        return [implode("\n", $result), $changed];
    }

    /**
     * @param array<int, string> $block
     * @return array<int, string>
     */
    private function formatBlock(array $block): array
    {
        $rows = array_map($this->splitCells(...), $block);
        $columns = max(array_map('count', $rows));
        foreach ($rows as $rowIndex => $row) {
            $rows[$rowIndex] = array_pad($row, $columns, '');
        }

        $widths = [];
        for ($column = 0; $column < $columns; $column++) {
            $width = 0;
            foreach ($rows as $rowIndex => $row) {
                if ($rowIndex === 1) {
                    continue;
                }
                $width = max($width, mb_strlen($row[$column]));
            }
            $widths[$column] = $width;
        }

        $formatted = [];
        foreach ($rows as $rowIndex => $row) {
            if ($rowIndex === 1) {
                $cells = [];
                for ($column = 0; $column < $columns; $column++) {
                    $cells[] = $this->separator($widths[$column], $rows[1][$column]);
                }
                $formatted[] = '|' . implode('|', $cells) . '|';
                continue;
            }
            $cells = [];
            for ($column = 0; $column < $columns; $column++) {
                $cells[] = $this->pad($row[$column], $widths[$column]);
            }
            $formatted[] = '| ' . implode(' | ', $cells) . ' |';
        }

        return $formatted;
    }

    /**
     * @return array<int, string>
     */
    private function splitCells(string $line): array
    {
        $cells = preg_split('/(?<!\\\\)\|/', trim($line)) ?: [];
        if ($cells !== [] && trim($cells[0]) === '') {
            array_shift($cells);
        }
        if ($cells !== [] && trim($cells[count($cells) - 1]) === '') {
            array_pop($cells);
        }

        return array_map('trim', $cells);
    }

    private function separator(int $width, string $marker): string
    {
        $left = str_starts_with($marker, ':');
        $right = str_ends_with($marker, ':');
        if ($left && $right) {
            return ':' . str_repeat('-', $width) . ':';
        }
        if ($left) {
            return ':' . str_repeat('-', $width + 1);
        }
        if ($right) {
            return str_repeat('-', $width + 1) . ':';
        }

        return str_repeat('-', $width + 2);
    }

    private function pad(string $cell, int $width): string
    {
        return $cell . str_repeat(' ', max(0, $width - mb_strlen($cell)));
    }
}
