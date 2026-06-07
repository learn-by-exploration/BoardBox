# Board Box - Codex Guide

Use this guide with `CLAUDE.md`. That file is the broader developer/release
guide; this file captures the repo-specific expectations Codex should follow
when reviewing or changing the app.

## Project Snapshot

- Flutter app package: `common_games`
- Public app name: `Board Box`
- Android package: `com.boardbox.app`
- CI Flutter version: `3.44.0` stable
- Dart SDK constraint in `pubspec.yaml`: `^3.12.0`
- Games: Gomoku, Othello, Checkers, Dots & Boxes, Tic Tac Toe
- Main release checks in CI: format, analyze with `--fatal-infos`, tests with
  coverage, debug APK, release AAB, web build, iOS no-codesign build

## Commands

Run from the repo root, `board_box/`.

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter build apk --debug
flutter build appbundle --release
```

For release parity, use CI's pinned Flutter version where possible. If local
Flutter differs, call that out in review notes.

## Architecture Notes

- Model files live under `lib/games/*/*_model.dart` and should remain pure Dart.
  Do not import Flutter widgets/material into model files.
- Board files live beside each model and own UI plus AI behavior.
- Current models are mutable: methods such as `play`, `tap`, `drawHLine`, and
  `restart` mutate internal state and expose read-only board views. Do not
  assume immutable model replacement unless the app is deliberately refactored.
- Persistence uses `SharedPreferences` through `GameStats`, `SettingsService`,
  and the board JSON save/restore flow in `GameScreen`.
- Undo is conditional: only show or expect undo when a board has supplied an
  undo callback. At present, Gomoku and Tic Tac Toe provide move history.
- Prefer package imports like `package:common_games/...`; linting enforces this.

## Game Invariants

Preserve these rules and add/update model tests for any game-logic change.

| Game | Critical behavior |
| --- | --- |
| Gomoku | 15x15 board, black first, five or more contiguous stones currently wins |
| Othello | 8x8 Reversi, invalid moves rejected, player passes when no valid move exists, game ends when neither player can move |
| Checkers | 8x8 English draughts, red first, mandatory captures, multi-jump chains, kings move/capture both directions |
| Dots & Boxes | 5x5, 6x6, or 7x7 dots; box capture grants another turn; game ends after every box is claimed |
| Tic Tac Toe | 3x3/4x4 use 3-in-a-row, 5x5 uses 4-in-a-row |

Note: `CLAUDE.md` says Gomoku requires exactly five stones and references a
checkers `mustContinueFrom` field. The current code uses `count >= 5` in
Gomoku and `_midJump`/selected coordinates in Checkers. Treat those as current
implementation facts when reviewing.

## Review Priorities

For public-release review, lead with bugs and risks before summaries.

- Run format/analyze/tests when possible.
- Inspect game-rule edge cases, especially out-of-bounds taps, game-over state,
  AI moves, pass/skip logic, draw detection, and restart behavior.
- Check widget behavior for async timers or delayed AI moves firing after a game
  is reset, disposed, or navigated away from.
- Verify saved game restore by pausing/leaving a game and reopening the same
  game/mode/board-size path.
- Verify release-sensitive files: Android signing config, package name, version,
  app icon resources, privacy policy, and CI workflow.
- Do not modify keystores, certificates, `android/key.properties`, or other
  secrets. Report issues instead.

## Editing Rules

- Respect the existing dirty worktree. Treat uncommitted changes as user work.
- Keep changes narrowly scoped to the requested fix or review artifact.
- Use `dart format .` after Dart edits.
- Do not relax lints or tests to make CI pass.
- When adding a new game or changing game logic, update the corresponding
  `test/<game>_model_test.dart` file.

## Release Checklist

Before saying the app is release-ready, verify or explicitly mark unverified:

- `dart format --output=none --set-exit-if-changed .`
- `flutter analyze --fatal-infos`
- `flutter test`
- `flutter build apk --debug`
- `flutter build appbundle --release`
- App version in `pubspec.yaml`
- Android application id and signing setup
- Privacy policy route/content
- No secrets accidentally staged or committed
