# AGENTS.md — Board Box

**Package:** `common_games` · **App:** Board Box · **Android:** `com.boardbox.app`
**Flutter:** 3.44.0 stable (CI-pinned) · **Dart:** `^3.12.0` · **JVM:** 17

A Flutter app with local-multiplayer board games. Currently shipping: Gomoku,
Othello, Checkers, Dots & Boxes, Tic Tac Toe, Sudoku, Karuro. New games follow
the two-file pattern described in [§ Project structure](#project-structure).

This file is the **portable baseline** for any coding agent (Claude Code, Codex,
Aider, Gemini CLI, Cursor, etc.). Tool-specific extensions belong in
`CLAUDE.md` (Claude Code) or similar — not here.

---

## Setup

```bash
flutter pub get
flutter --disable-analytics && flutter precache --force
flutter doctor -v
cp android/key.properties.example android/key.properties  # gitignored
```

Pin the local Flutter to the CI version (3.44.0) — mismatches are the #1 source
of "passes locally, fails in CI" bugs.

---

## Quality gate (must pass before declaring work done)

Run, in order, with zero failures:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```

Do not relax lints, suppress warnings, or skip tests to make CI pass. The
`--fatal-infos` flag is non-negotiable — info-level lints block the build.

---

## Project structure

```
lib/
  main.dart                # initializes GameStats + SettingsService
  models/                  # GameMode, AiDifficulty, json_helpers
  screens/                 # splash, home, mode_select, settings, privacy
    sudoku/                # sudoku_setup_screen + sudoku_game_screen
    karuro/                # karuro_setup_screen + karuro_game_screen
  games/<name>/            # <name>_model.dart (pure Dart) + <name>_board.dart
  services/                # game_stats, settings_service, haptic_service
  widgets/                 # shared UI
  theme/                   # Material 3, seed 0xFF5C35CC
assets/                    # images, fonts, puzzles
  puzzles/karuro/          # hand-authored Karuro puzzles
test/                      # mirror lib/games/<name>/<name>_model_test.dart
```

**Two-file game pattern:** `lib/games/<name>/<name>_model.dart` is pure Dart
(no Flutter imports). `<name>_board.dart` is the Flutter widget + AI
implementation. A `karuro/` game adds an extra `karuro_puzzle.dart` for value
types and `karuro_assets.dart` for bundled-puzzle loading — both still
Flutter-free.

---

## Architecture rules

- **Model-purity rule.** `lib/games/*/*_model.dart` MUST be pure Dart — no
  `package:flutter/*` imports. Game logic must be unit-testable without a
  widget tree. If a model needs to read assets (e.g. Karuro puzzles), put the
  `rootBundle` call in a sibling `*_assets.dart` and pass the parsed value
  types in.
- **AI lives in the board widget.** `_easyMove` / `_mediumMove` / `_hardMove`
  live in `*_board.dart`. If any one grows past ~150 lines, extract to
  `<name>_ai.dart` in the same directory.
- **Services are singletons.** `GameStats` and `SettingsService` are
  initialized in `main.dart`. Do not write gameplay settings directly to
  `SharedPreferences` from widgets — go through the service.
- **Imports are package-only.** Use `package:common_games/...` imports
  everywhere. No relative `../` imports (enforced by
  `always_use_package_imports`).
- **State classes are sealed.** Each game exposes a sealed `*State` with
  concrete `*Playing` / `*Won` / `*Lost` (or `*Draw`) final classes. Avoid
  bare enum state.

---

## Code style (lint-enforced — see `analysis_options.yaml`)

- Single quotes throughout.
- `const` constructors and `const` collections wherever the linter allows.
- `final` for locals, `var` only when reassigned.
- Keys on all stateful widgets (`use_key_in_widget_constructors`).
- No `print()` — use `debugPrint` behind a `kDebugMode` guard.
- `unawaited_futures` is on: every `Future` must be awaited or wrapped in
  `unawaited(...)`.
- `strict-casts`, `strict-inference`, `strict-raw-types` are on.

---

## Game invariants — never break these

If a change to a game's logic risks breaking one of these invariants, the
corresponding `test/<game>_model_test.dart` must be updated to cover the new
behavior. Failing these silently ships a broken game.

| Game | Critical rules |
|------|---------------|
| **Gomoku** | 15×15 grid; **five or more** contiguous stones wins (current implementation uses `count >= 5`; do not tighten to `== 5` without a model test covering 6+). Black moves first. |
| **Othello** | 8×8; invalid moves rejected; pass when no valid move exists; game ends when neither player can move. |
| **Checkers** | 8×8 English draughts; red moves first; mandatory captures; multi-jump chains must complete (the model's `_midJump` field is set while a chain is in progress and cleared at its end; do not "refactor" this away without preserving the turn-stays-the-same semantics). Kings move and capture both directions. |
| **Dots & Boxes** | 5×5 / 6×6 / 7×7 dots; completing a box grants an extra turn; game ends when all boxes are claimed. |
| **Tic Tac Toe** | 3×3 and 4×4 win on 3-in-a-row; 5×5 wins on 4-in-a-row. X moves first. |
| **Sudoku** | 9×9 grid; uses `fludoku: 4.0.5` for puzzle generation/validation; save format is versioned (`version: 2`); mistake limit and timer live on the model. |
| **Karuro** | Hybrid Kakuro/crossword. Numeric runs: digits 1-9, no repeats within a run, sum equals the clue. Word runs: letters A-Z, spells the `answer` from `entries`. The per-cell `solution` map in the puzzle JSON is the source of truth for "show errors" — no runtime solver. |

---

## Testing

- `flutter test` (all) or `flutter test test/<game>_model_test.dart` (one).
- **Minimum 80% coverage** on changed files. `flutter test --coverage` then
  `genhtml coverage/lcov.info -o coverage/html`.
- New game logic MUST have a corresponding `test/<name>_model_test.dart`
  covering: initial state, valid moves, win, draw (if applicable), restart,
  and game-specific edge cases (multi-jump in checkers, pass in othello,
  first-tap-safe in minesweeper, etc.).
- Board (widget) files need at minimum a pump-and-tap golden path test.
- New model fields that change save/load round-trip behavior must extend the
  existing round-trip test in that game's `_model_test.dart` (do not create
  a new test file just for the round-trip).

---

## Commit & PR conventions

- **Conventional Commits:** `feat:`, `fix:`, `refactor:`, `docs:`, `test:`,
  `chore:`, `perf:`, `ci:`.
- **One logical change per commit.** When a feature is large, split it into
  multiple commits and ship them in order.
- PR description: what changed, why, how it was verified (paste the
  three-gate output).
- Do not include "Generated with Claude Code" footers or co-author lines
  (`Co-Authored-By: Claude …`) in commits or PR bodies.

---

## Common pitfalls

- **`key.properties` is gitignored.** Without it, debug builds still work
  but release builds fail with a Gradle signing error. On a new machine:
  `cp android/key.properties.example android/key.properties` and fill in real
  values.
- **Gradle OOM on low-RAM machines.** Lower the heap in
  `android/gradle.properties`: `org.gradle.jvmargs=-Xmx4g`. The default is 8g.
- **Flutter SDK version mismatch.** CI pins Flutter 3.44.0. Use the same
  locally via `flutter upgrade` or FVM.
- **Web build base-href must match the repo name** (`/BoardBox/`). Mismatch
  breaks asset loading on GitHub Pages.
- **Checkers multi-jump semantics.** When a piece has a mandatory follow-up
  capture, the model's `_midJump` flag is set and the turn does not change.
  The `checkers_model_test.dart` covers this — do not "simplify" the field
  away without preserving the semantics and a regression test.
- **Gomoku win count.** `count >= 5`, not `== 5`. The 6-in-a-row regression
  test in `gomoku_model_test.dart` will fail if this drifts.

---

## Android signing & CI/CD

See `docs/ci.md` for the long form (CI workflow, secrets, branch strategy,
artifact retention). Short version:

- Keystores, certs, and `key.properties` are **never** committed.
- The `android/upload-keystore.jks` is gitignored by `*.jks` — keep that rule.
- The four `ANDROID_*` GitHub Secrets are required for the `release-aab`
  artifact job; missing secrets fail only that job.

---

## Out of scope

Do not modify these under any circumstances — report issues instead:

- `android/key.properties`
- `android/*.jks`, `android/*.der`, any keystore
- Any `ANDROID_*` GitHub Secret
- `google-services.json` or other platform credentials
- Anything in `.claude/` other than `AGENTS.md` / `CLAUDE.md` (skills, hooks,
  and local settings are personal)
