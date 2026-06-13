# Path-scoped rules — `lib/games/`

Auto-loaded by Claude Code when you open a file in
`lib/games/`. Read these rules before writing code in this area.

For the long form, see
[`../docs/design/02-architecture.md`](../docs/design/02-architecture.md).

---

## 1. Model purity

`lib/games/<name>/<name>_model.dart` MUST be pure Dart — no
`package:flutter/*` imports. Game logic must be unit-testable
without a widget tree.

**Sole exception:** sibling `<name>_assets.dart` (e.g.
`karuro_assets.dart`) may import `package:flutter/services.dart`
for `rootBundle`. Returned types are still pure-Dart value
objects.

**Verifiable:**
```bash
grep -l "import 'package:flutter/" lib/games/*/[a-z]*_model.dart
# Must print nothing.
```

If it prints, the file is violating the rule.

---

## 2. Two-file rule

The minimum for a new game is two files:

- `<name>_model.dart` — pure Dart. State, transitions, win/loss
  detection, save/load, simple AI.
- `<name>_board.dart` — Flutter widget. Renders the model,
  handles user input, runs the AI (or imports `*_ai.dart`).

Extract `<name>_ai.dart` if the AI implementation grows past
~150 LOC (Klondike is the one case today) or if the AI is
independently testable.

---

## 3. State pattern

Each game exposes a sealed `*State` hierarchy. Not bare enums.

```dart
sealed class KlondikeState {}
final class KlondikePlaying extends KlondikeState { ... }
final class KlondikeWon extends KlondikeState { ... }
```

All state classes are immutable. State transitions return *new*
model instances; never mutate. `switch (state)` over a sealed
class is exhaustive at compile time.

---

## 4. Test mirror

Every `lib/games/<name>/<name>_model.dart` has a corresponding
`test/<name>_model_test.dart` covering:

- Initial state
- Valid moves (one happy path)
- Win condition
- Loss condition (or draw, if applicable)
- Restart
- Game-specific edge cases (multi-jump in checkers, pass in
  othello, first-tap-safe in minesweeper, etc.)
- Round-trip for `toJson` / `fromJson` (extending the existing
  test, not a new file)

Every `lib/games/<name>/<name>_board.dart` has a corresponding
`test/<name>_widget_test.dart` covering the golden path:
pump → tap → verify.

---

## 5. Lint set

The 18 lints in `analysis_options.yaml` apply. Most relevant
to this area:

- `unawaited_futures` — every `Future` is `await`ed or
  wrapped in `unawaited(...)`. The GameStats async-gate
  (commit 43) is the reason this lint is loud.
- `prefer_final_locals` — `final` for locals; `var` only when
  reassigned.
- `always_use_package_imports` — `package:common_games/...`
  only.
