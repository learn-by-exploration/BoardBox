# Sudoku Implementation Plan

## Goal

Add a reliable, offline 9x9 Sudoku experience to Board Box without forcing a
single-player puzzle into the app's two-player game abstractions.

## Open-Source Review

### Selected: fludoku 4.0.5

- License: MIT
- Pure Dart solver and generator
- Generates puzzles with exactly one solution
- Supports generation timeouts
- Includes unit tests for board validation, solving, multiple solutions,
  uniqueness, and generation
- Latest package release: June 2025

Board Box will use it behind a local adapter. UI and gameplay state remain
owned by Board Box so the dependency can be replaced without rewriting screens.

### Rejected: sudoku_dart 1.2.0

- BSD-3-Clause and supports unique solutions
- No test directory in the source repository
- Difficulty is based only on removed-cell counts
- Generator mutates supplied lists and retries recursively

### Rejected: sudoku_generator 1.0.5

- MIT and provides a complete Flutter widget
- Requires introducing Riverpod across the app
- Removes cells without verifying that the puzzle still has one solution
- No tests were present in the inspected repository

### Rejected: Hi Sudoku Puzzle Library

- Strong human-technique-based puzzle curation
- CC BY-NC-SA 4.0 prevents use in a potentially commercial app

## Product Decisions

- Standard 9x9 Sudoku only for the first release.
- Difficulties: Easy, Medium, Hard.
- Sudoku gets its own setup and game screens, not `GameMode`.
- A valid puzzle must have exactly one solution.
- Generation happens off the UI thread and has a timeout plus retry/fallback.
- Initial difficulty labels use the engine's clue-based levels. Technique-based
  rating is a later quality phase and must not be implied before it exists.

## Phases

### Phase 1: Engine and Domain Foundation

- Add the `fludoku` dependency and license notice.
- Add a Board Box puzzle factory that verifies one solution.
- Add a pure-Dart mutable model for values, notes, mistakes, hints, completion,
  and JSON save/restore.
- Add deterministic model tests and an adapter integration test.

Acceptance:

- Invalid edits and fixed-cell edits are rejected.
- Notes cannot be placed in fixed or filled cells.
- Incorrect entries are tracked.
- Completion requires the exact unique solution.
- State round-trips through JSON.
- Generated puzzles are valid and have one solution.

### Phase 2: Playable Core UI

- Add Sudoku to the home catalog.
- Add a Sudoku setup screen with Easy, Medium, and Hard.
- Build a responsive 9x9 board, number pad, erase, notes, undo, and highlighting.
- Generate puzzles in an isolate with loading and retry states.
- Save one in-progress puzzle per difficulty.

Acceptance:

- No frame stalls during generation.
- Board works on narrow phones and tablets in light and dark themes.
- Fixed cells are visually distinct and inaccessible to editing.
- Rotation/background/restore preserves the exact puzzle and progress.
- Widget tests cover selection, entry, notes, undo, and restore.

### Phase 3: Player Assistance and Accessibility

- Add optional mistake checking and mistake limits.
- Add hints with a clear counter.
- Add timer, pause, and resume.
- Add row, column, box, and matching-number highlighting.
- Add complete semantics for cells, notes, controls, and status.

Acceptance:

- TalkBack can identify row, column, value, fixed/editable state, and notes.
- Every control has at least a 48dp touch target.
- Timer does not advance while paused or backgrounded.
- Hints and mistakes persist after restore.

### Phase 4: Sudoku Statistics and Daily Play

- Add Sudoku-specific statistics: completed, best time, average time, streak,
  mistakes, and hints by difficulty.
- Add a deterministic daily puzzle stored locally.
- Show Sudoku progress on the home card without using W/L/D labels.

Acceptance:

- A completed puzzle is recorded exactly once.
- Daily puzzle identity is stable for a local calendar date.
- Existing board-game statistics are unchanged.

### Phase 5: Difficulty Quality

- Add a human-style logical solver for naked/hidden singles, pairs, pointing
  pairs, and box-line reduction.
- Rate generated puzzles by required techniques rather than clue count.
- Add logical, explainable hints.
- Build a regression corpus for every supported technique.

Acceptance:

- Easy puzzles require singles only.
- Medium and Hard ratings are determined by documented techniques.
- Hints name the technique and identify the relevant cells.
- Every shipped/generated puzzle remains uniquely solvable.

## Risks and Controls

- Generation latency: isolate, timeout, retry, and optional bundled fallback.
- Misleading difficulty: describe Phase 2 levels as engine-rated until Phase 5.
- Save corruption: version JSON and reject malformed dimensions/values.
- Dependency regression: pin the package version and keep adapter integration
  tests in Board Box.
- Licensing: retain the MIT notice and avoid non-commercial puzzle datasets.

