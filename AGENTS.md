# AGENTS.md — Board Box

**Package:** `common_games` · **App:** Board Box · **Android:** `com.boardbox.app`
**Flutter:** 3.44.0 stable (CI-pinned) · **Dart:** `^3.12.0` · **JVM:** 17

A Flutter app with local-multiplayer board games. Currently shipping: Gomoku,
Othello, Checkers, Dots & Boxes, Tic Tac Toe, Sudoku, Karuro, Klondike,
Minesweeper.

This file is the **portable baseline** for any coding agent. Tool-specific
extensions belong in `CLAUDE.md` (Claude Code) or similar — not here.
Everything below points to a deep-dive in `docs/`.

---

## Setup

```bash
flutter pub get
flutter --disable-analytics && flutter precache --force
flutter doctor -v
cp android/key.properties.example android/key.properties  # gitignored
```

Pin Flutter to the CI version (3.44.0) — mismatches are the #1 source of
"passes locally, fails in CI" bugs. Use FVM or `flutter upgrade`.

---

## Architecture pointers

Full rules: [docs/design/02-architecture.md](docs/design/02-architecture.md).
TL;DR:

- **Feature-folder layout.** `lib/games/<name>/`, `lib/screens/<feature>/`,
  `lib/services/`, `lib/models/`. One folder per game, two files minimum.
- **Model purity.** `lib/games/<name>/<name>_model.dart` has zero
  `package:flutter/*` imports. Sibling `<name>_assets.dart` is the only
  Flutter-importing exception (it reads `rootBundle`).
- **Two-file game pattern.** `*_model.dart` (pure Dart) + `*_board.dart`
  (Flutter widget + AI). Extract `*_ai.dart` if AI > 150 LOC.
- **Service pattern.** Singletons with `Completer<void> _ready`. All public
  reads/writes `await _ready.future` first. `init()` is idempotent. Worked
  example: [`GameStats`](lib/services/game_stats.dart).
- **State pattern.** Sealed `*State` classes (`*Playing` / `*Won` / `*Lost`
  / `*Draw`). No bare enum state.
- **Layer boundaries.** One-directional imports: presentation → application
  → domain → data. No back-edges.

---

## The 3-gate

Run, in order, with zero failures. **All three must pass before a task is
done.** Paste the output in the PR / completion message.

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```

Do not relax lints, suppress warnings, or skip tests. `--fatal-infos` is
non-negotiable — info-level lints block the build. See
[docs/engineering/ci-cd.md](docs/engineering/ci-cd.md) for the CI wiring.

---

## Game invariants — never break these

If a change to a game's logic risks breaking one of these invariants, the
corresponding `test/<game>_model_test.dart` must be updated to cover the
new behavior. Failing these silently ships a broken game.

| Game | Critical rules |
|------|---------------|
| **Gomoku** | 15×15 grid; **five or more** contiguous stones wins (current implementation uses `count >= 5`; do not tighten to `== 5` without a model test covering 6+). Black moves first. |
| **Othello** | 8×8; invalid moves rejected; pass when no valid move exists; game ends when neither player can move. |
| **Checkers** | 8×8 English draughts; red moves first; mandatory captures; multi-jump chains must complete (the model's `_midJump` field is set while a chain is in progress and cleared at its end; do not "refactor" this away without preserving the turn-stays-the-same semantics). Kings move and capture both directions. |
| **Dots & Boxes** | 5×5 / 6×6 / 7×7 dots; completing a box grants an extra turn; game ends when all boxes are claimed. |
| **Tic Tac Toe** | 3×3 and 4×4 win on 3-in-a-row; 5×5 wins on 4-in-a-row. X moves first. |
| **Sudoku** | 9×9 grid; uses `fludoku: 4.0.5` for puzzle generation/validation; save format is versioned (`version: 2`); mistake limit and timer live on the model. |
| **Karuro** | Hybrid Kakuro/crossword. Numeric runs: digits 1-9, no repeats within a run, sum equals the clue. Word runs: letters A-Z, spells the `answer` from `entries`. The per-cell `solution` map in the puzzle JSON is the source of truth for "show errors" — no runtime solver. |
| **Klondike** | 7 tableau columns, 4 foundations, 24-card stock, draw-1 only. Standard Klondike turn-1 deal: after `deal()`, every column has exactly one face-up card at the top (column 1 included). Win = all four foundations built to King by suit. Hint, auto-complete, undo, timer, and move counter are part of the model layer (not screen-side). |
| **Minesweeper** | Beginner 9×9 / 10 mines, Intermediate 16×16 / 40 mines, Expert 16×30 / 99 mines. First-tap safety: the minefield is generated on the first reveal, and the tapped cell plus its 8 neighbors are guaranteed mine-free. Cascade reveal: revealing a cell with 0 adjacent mines reveals all 8 neighbors and recursively reveals any of those with 0. Win = all safe cells revealed. Loss = a mine revealed. No chord-reveal, no undo in v1. |

---

## Testing

- `flutter test` (all) or `flutter test test/<game>_model_test.dart` (one).
- **Minimum 80% coverage** on changed files. `flutter test --coverage`
  → `genhtml coverage/lcov.info -o coverage/html`.
- New game logic MUST have a corresponding
  `test/<name>_model_test.dart` covering: initial state, valid moves, win,
  draw (if applicable), restart, and game-specific edge cases (multi-jump
  in checkers, pass in othello, first-tap-safe in minesweeper, etc.).
- Board (widget) files need at minimum a pump-and-tap golden path test.
- New model fields that change save/load round-trip behavior must extend
  the existing round-trip test in that game's `_model_test.dart` (do not
  create a new test file just for the round-trip).
- Async widgets: `tester.runAsync` to step out of the fake-async zone for
  real `Future`s (`SharedPreferences`, `Future.delayed` on real time). Use
  `tester.pump()`, **never** `pumpAndSettle()` after a drag (scroll physics
  loops forever). Full pattern: [docs/engineering/testing-strategy.md](docs/engineering/testing-strategy.md) §"Async patterns".

---

## Commit & branch

- **Conventional Commits:** `feat:`, `fix:`, `refactor:`, `docs:`, `test:`,
  `chore:`, `perf:`, `ci:`.
- **One logical change per commit.** When a feature is large, split it
  into multiple commits and ship them in order. Decomposition playbook:
  [docs/design/06-feature-decomposition.md](docs/design/06-feature-decomposition.md).
- PR description: what changed, why, how it was verified (paste the
  three-gate output).
- **Banned in commits:** AI co-author footers (`Co-Authored-By: Claude …`),
  "Generated with Claude Code" trailers, `key.properties`, `*.jks`, `*.der`,
  any `ANDROID_*` env value, `google-services.json`, or any keystore. See
  [docs/engineering/secrets-and-privacy.md](docs/engineering/secrets-and-privacy.md).
- Push only when the user asks. Do not push directly to `main` without an
  approved PR (unless explicitly told to).

---

## Style highlights (lint-enforced — see [`analysis_options.yaml`](analysis_options.yaml))

The 18 enabled lints, with the three most opinionated:

- **`avoid_print`** — `print()` is banned. Use `debugPrint` behind a
  `kDebugMode` guard, or surface the message to the UI.
- **`unawaited_futures`** — every `Future` must be `await`ed or wrapped in
  `unawaited(...)` from `dart:async`. The GameStats async-gate (commit 43)
  is the reason this lint is loud.
- **`always_use_package_imports`** — `package:common_games/...` imports
  only. No relative `../` imports. (Strict, strict-raw types are on too.)
- The other 15: `prefer_const_constructors`, `prefer_const_declarations`,
  `prefer_const_literals_to_create_immutables`, `prefer_final_locals`,
  `prefer_single_quotes`, `use_key_in_widget_constructors`,
  `prefer_is_empty`, `prefer_is_not_empty`, `unnecessary_this`,
  `avoid_unnecessary_containers`, `sized_box_for_whitespace`,
  `use_colored_box`, `sort_child_properties_last`, `unnecessary_lambdas`,
  `avoid_redundant_argument_values`.

Full rationale + before/after for each:
[docs/engineering/flutter-dart-style.md](docs/engineering/flutter-dart-style.md).

---

## Path-scoped rules (auto-loaded by Claude Code)

If your task touches a path, the matching `.claude/rules/<path>.md` will
load automatically:

- `lib/games/**` → [`.claude/rules/lib-games.md`](.claude/rules/lib-games.md) — model purity, two-file pattern.
- `lib/screens/**` → [`.claude/rules/lib-screens.md`](.claude/rules/lib-screens.md) — `StatefulWidget` for async, dimmed placeholders, 48dp targets.
- `lib/services/**` → [`.claude/rules/lib-services.md`](.claude/rules/lib-services.md) — singleton + `_ready` gate, no Flutter imports.
- `test/**` → [`.claude/rules/test.md`](.claude/rules/test.md) — coverage, `runAsync`, no skipped tests.

---

## Out of scope

Do not modify these — report issues instead:

- `android/key.properties`
- `android/*.jks`, `android/*.der`, any keystore
- Any `ANDROID_*` GitHub Secret
- `google-services.json` or other platform credentials
- Anything in `.claude/` other than `AGENTS.md` / `CLAUDE.md` / `rules/`

---

## Common pitfalls

- **`key.properties` is gitignored.** Debug builds work without it; release
  fails with a Gradle signing error. On a new machine:
  `cp android/key.properties.example android/key.properties`.
- **Gradle OOM on low-RAM machines.** Set
  `org.gradle.jvmargs=-Xmx4g` in `android/gradle.properties` (default 8g).
- **Flutter SDK version mismatch.** CI pins 3.44.0. Use the same locally
  via FVM.
- **Web build base-href must match the repo name** (`/BoardBox/`). Mismatch
  breaks asset loading on GitHub Pages.
- **Checkers multi-jump.** The model's `_midJump` flag is set during a
  chain; turn does not change. `checkers_model_test.dart` covers it — do
  not "simplify" the field away.
- **Gomoku win count.** `count >= 5`, not `== 5`. The 6-in-a-row regression
  test in `gomoku_model_test.dart` will fail if this drifts.
- **`tester.runAsync` is not re-entrant.** Don't nest. Don't
  `pumpAndSettle()` after a drag — scroll physics loops forever. Use
  `pump()` + a short `pump(duration)`.
- **GameStats reads return `Future<int>`.** All callers must `await`. The
  ready-gate (commit 43) prevents a silent zero return on cold start.
  See [lib/services/game_stats.dart](lib/services/game_stats.dart).

*Everything else — design system, UI/UX, PR review, AI guide, bug-hunt,
secrets, CI — is in [`docs/`](docs/README.md).*
