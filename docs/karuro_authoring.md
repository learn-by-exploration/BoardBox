# Karuro Puzzle Authoring

Karuro is a hybrid Kakuro/crossword puzzle. Grids mix **number** entries
(Kakuro-style digit sums, 1-9 no repeats) and **word** entries (crossword-style
letter sequences). This file documents the JSON format and the rules enforced
by `KaruroPuzzle._validate()` in `lib/games/karuro/karuro_puzzle.dart`.

## File layout

Puzzles live in `assets/puzzles/karuro/`, one JSON per file, named
`karuro-NNN.json` with `NNN` zero-padded (e.g. `karuro-001.json`). The full
catalogue is enumerated in `assets/puzzles/karuro/index.json` in id order
(never sort alphabetically — `karuro-002.json` must come before
`karuro-010.json`).

A puzzle has:

- `id` — string, matches the file basename.
- `title` — human-friendly, e.g. `"Sunny Start"`.
- `difficulty` — `"easy" | "medium" | "hard"`.
- `grid` — `{ "rows": N, "cols": M }` (typically 5x5, 7x7, or 9x9).
- `cells` — `rows` × `cols` of `"#"` (block) or `" "` (entry).
- `entries` — list of runs (see below).
- `solution` — map of `"row,col"` (zero-based) to single-char value.
- `metrics` — see the *Metrics* section.

## Entries

Each entry has a `kind` that picks the rest of the shape:

- `kind: "number"` — digits 1-9, no repeats within the run, sum equals `sum`.
  Required fields: `id`, `number`, `direction`, `start`, `length`, `sum`.
- `kind: "word"` — letters A-Z, spells `answer` exactly. Required fields:
  `id`, `number`, `direction`, `start`, `length`, `clue`, `answer`.

Common fields:

- `id` — `"{number}{A|D}"`. `number` is shared by across+down runs that start
  at the same cell (crossword convention).
- `direction` — `"across"` or `"down"`.
- `start` — `{ "row": R, "col": C }` of the first cell. The first cell must
  be an entry cell, not a block.
- `length` — number of cells in the run.

A run's cells are `start + (dr*i, dc*i)` for `i = 0..length-1`, where `dr=0,dc=1`
for across and `dr=1,dc=0` for down. Every cell in the run must be an entry
cell in `cells`. Solution keys are only required for cells that are in some
entry; unconstrained entry cells may be omitted.

## Validation rules (what `_validate()` checks)

- Grid shape matches `cells` dimensions.
- Every cell in every entry is an entry cell (not a block) and in bounds.
- For word entries: `answer.length == length`, and the `solution` value at
  each cell equals the corresponding letter of `answer` (case-insensitive).
- For number entries: every cell has a non-null `solution` value. (The model
  does not check that the value is a digit 1-9 or that the sum holds — the
  puzzle author is responsible for correctness.)

Because number and word values occupy the same cell-key space, a cell shared
between a number entry and a word entry would have to hold *both* a digit and
a letter. Avoid that: keep word entries and number entries in disjoint cell
sets.

## Difficulty targets

- **Easy (5x5)** — at most 1 word entry, 2-3 numeric runs, no word longer
  than 3 letters. All sums are pickable with digits 1-9.
- **Medium (7x7)** — 1-2 word entries, 3-5 numeric runs. Words up to 5 letters.
- **Hard (9x9)** — 2-3 word entries, 5+ numeric runs, words up to 5 letters
  (and 4-5-letter words encouraged).

## Metrics

Computed and stored at the top level:

- `maxNumericRunLength` — longest numeric run, in cells.
- `maxWordRunLength` — longest word run, in cells (use `0` if no words).
- `crossingsPerCell` — average number of runs that touch each entry cell,
  rounded to 2 decimals. (Usually 2.0 in a clean Kakuro-style grid.)
- `extremeSumShare` — fraction of numeric runs whose `sum` is at the
  *easy* extreme for that length (sum equals `length` if all 1s, or
  `9 * length` if all 9s). Rounded to 2 decimals.

## Numeric-run tips

For length 2, sums 3-17 (avoid 3 and 17 — both have a single digit combo);
pick sum 7, 11, 13, 14 which have multiple valid digit pairs. For length 3,
sum 6-24; pick 11, 13, 14, 17. For length 7, sum 28-35; the only valid combos
at each end are extreme.

When two runs share a cell, that cell's value must be a valid choice for both.
Solve that cell first, then the other cells, then check the second sum.

## Cross-checking solutions

A handy sanity check: for each cell listed in `solution`, list every entry
that touches it and confirm the value satisfies all of them (digit sum for
number runs, letter for word runs).

## Authoring tool

`tools/karuro_authoring.html` is a static HTML page (no build step) that
loads a puzzle, shows the grid with clue numbers, and lets you fill values to
verify sums and words before committing the JSON. Open it directly in a
browser — no server needed.
