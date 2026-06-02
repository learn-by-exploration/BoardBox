# Board Box — Developer Guide

**Package:** `com.boardbox.app`
**Flutter SDK:** `^3.12.0` · **Target SDK:** 35 · **Min SDK:** Flutter default (21)
**Java/Kotlin target:** JVM 17

Four classic local-multiplayer board games in one Flutter app:
Gomoku · Othello · Checkers · Dots & Boxes

---

## Quick start

```bash
# Install dependencies
flutter pub get

# Run on a connected device or emulator
flutter run

# Run on Chrome (web)
flutter run -d chrome

# Run all tests
flutter test

# Analyze (zero tolerance — CI uses --fatal-infos)
flutter analyze --fatal-infos

# Check formatting
dart format --output=none --set-exit-if-changed .
```

---

## Project structure

```
lib/
├── main.dart                  # App entry point; wires SettingsService provider
├── models/
│   └── game_mode.dart         # GameMode (twoPlayer/singlePlayer), AiDifficulty
├── screens/
│   ├── splash_screen.dart     # Animated launch screen
│   ├── home_screen.dart       # 2-column game grid, stats, settings link
│   ├── mode_select_screen.dart# 2-player vs AI; difficulty picker; game rules
│   ├── game_screen.dart       # Hosts board widget; records stats; game-over dialog
│   ├── settings_screen.dart   # Hints, haptics, fast AI, dark mode
│   └── privacy_policy_screen.dart
├── games/
│   ├── gomoku/                # 15×15 board, win on 5-in-a-row
│   ├── othello/               # 8×8 Reversi with disc-flip logic
│   ├── checkers/              # 8×8, mandatory captures, multi-jump, king promotion
│   └── dots_and_boxes/        # 5×5 dots (4×4 boxes), box-capture bonus turn
├── services/
│   ├── game_stats.dart        # SharedPreferences-backed win/loss/draw counts
│   ├── settings_service.dart  # ChangeNotifier; showMoveHints / haptics / themeMode
│   └── haptic_service.dart    # Gated HapticFeedback calls
├── widgets/
│   └── game_status_bar.dart   # Reusable turn indicator + score chip
└── theme/
    └── app_theme.dart         # Material 3, seed color 0xFF5C35CC (deep purple)
```

Each game follows the same two-file pattern:
- `*_model.dart` — pure Dart game logic (no Flutter imports); sealed state classes
- `*_board.dart` — Flutter widget + AI implementation

---

## Architecture rules

### Model layer is pure Dart
`games/*/` model files must not import `flutter/material.dart` or any widget.
This keeps game logic unit-testable without a widget tree.

### Immutability
Every move returns a new model instance — never mutate the existing state.
The board files rely on this for correct widget rebuilds.

### Services are singletons via ChangeNotifier
`SettingsService` and `GameStats` are injected at the top of the widget tree in
`main.dart`. Access them with `context.watch<SettingsService>()` (rebuild) or
`context.read<SettingsService>()` (action only).

### AI lives in the board widget
AI difficulty logic (`_easyMove`, `_mediumMove`, `_hardMove`) is in each
`*_board.dart`. If it grows large, extract to `*_ai.dart` in the same directory.

---

## Game invariants — never break these

| Game | Critical rules |
|------|---------------|
| **Gomoku** | 15×15 grid; exactly 5 consecutive stones wins (not 6+); black moves first |
| **Othello** | 8×8; player must pass if no valid moves; game ends when neither player can move |
| **Checkers** | Mandatory captures; multi-jump chains must complete; red moves first; kings move/capture both directions |
| **Dots & Boxes** | Completing a box grants an extra turn; game ends when all boxes are claimed |

Write a model test for any change to game logic. Failing these silently would
ship a broken game.

---

## Testing

```bash
# All tests
flutter test

# Single file
flutter test test/checkers_model_test.dart

# With coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

**Minimum coverage: 80%.**
Every model file must have a corresponding test file in `test/`.
Board (widget) files need at minimum a pump-and-tap golden path test.

### Adding tests for new game logic
1. Create `test/<game>_model_test.dart`
2. Cover: initial state, valid moves, win detection, draw detection, restart
3. Cover edge cases specific to the game (mandatory captures in checkers, pass in Othello, etc.)

---

## Android build & signing

### Debug (local development)
```bash
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk
```

### Release AAB (Play Store)
```bash
# key.properties must exist at android/key.properties (never commit it)
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### Signing setup (one-time, per machine)
`android/key.properties` is gitignored. Copy the example and fill in real values:
```bash
cp android/key.properties.example android/key.properties
# Edit: storeFile must be an absolute path to upload-keystore.jks
```

### CI signing
The keystore and passwords live in GitHub Secrets (see CI/CD section below).
Never hardcode credentials anywhere — not in Gradle files, not in comments.

### ProGuard / R8
Release builds enable minification (`isMinifyEnabled = true`) and resource
shrinking. If a class is unexpectedly missing at runtime, check
`android/app/proguard-rules.pro`. The `shared_preferences` and `flutter` rules
are handled automatically by their plugins.

### Gradle properties
`android/gradle.properties` sets `-Xmx8g` for the Gradle daemon. Reduce this
on machines with less RAM:
```
org.gradle.jvmargs=-Xmx4g -XX:+HeapDumpOnOutOfMemoryError
```

---

## CI/CD

Pipeline is defined in `.github/workflows/ci.yml`.

| Job | Trigger | What it does |
|-----|---------|-------------|
| `quality` | every push & PR | `dart format`, `flutter analyze --fatal-infos`, `flutter test --coverage` |
| `build-debug` | every push & PR | builds debug APK, uploads as artifact |
| `build-android-release` | push to `main` | builds signed AAB, uploads as artifact |
| `build-web` | push to `main` | builds web (CanvasKit), deploys to GitHub Pages |
| `build-ios` | push to `main` | builds iOS no-codesign on macOS runner |

### Required GitHub Secrets
Go to **Settings → Secrets and variables → Actions** and add:

| Secret | Value |
|--------|-------|
| `ANDROID_KEYSTORE_BASE64` | `base64 android/upload-keystore.jks` |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | key password from key.properties |
| `ANDROID_STORE_PASSWORD` | store password from key.properties |

To encode the keystore:
```bash
base64 -w 0 android/upload-keystore.jks
```

### GitHub Pages
Enable under **Settings → Pages → Source → GitHub Actions**.
The web build deploys automatically on every push to `main` with base href
`/BoardBox/`.

---

## Adding a new game

1. Create `lib/games/<name>/` with `<name>_model.dart` and `<name>_board.dart`
2. Add the game to `home_screen.dart` game grid (follow existing card pattern)
3. Register the board widget in `game_screen.dart` switch statement
4. Add rules text to `mode_select_screen.dart`
5. Add stats keys to `game_stats.dart` (follow `GameType` enum pattern)
6. Add model tests in `test/<name>_model_test.dart` (min: initial state + win + draw + restart)

---

## Code style

- **Formatting:** `dart format` — enforced by CI. Run before every commit.
- **Linting:** `flutter analyze --fatal-infos` — zero warnings policy.
- **Null safety:** fully sound null safety. No `!` force-unwraps on user-supplied data.
- **Const:** use `const` constructors everywhere the linter allows.
- **Strings:** single quotes throughout (enforced by `prefer_single_quotes` lint).
- **Imports:** package imports only (`package:common_games/...`), no relative imports.
- **Widget keys:** always pass a `key` parameter to stateful widgets (`use_key_in_widget_constructors`).
- **No print:** use `debugPrint` behind a `kDebugMode` guard; remove before PR.

---

## Common pitfalls

**key.properties not found → release build fails**
The file is gitignored intentionally. On a new machine run:
```bash
cp android/key.properties.example android/key.properties
# then fill in real values
```

**Gradle OOM on low-RAM machines**
Lower the heap in `android/gradle.properties`:
```
org.gradle.jvmargs=-Xmx4g
```

**Flutter SDK version mismatch**
CI pins Flutter to `3.32.0` stable. Use the same version locally:
```bash
flutter upgrade
flutter --version
```

**Web build works but game is slow**
The CI and deployment use `--web-renderer canvaskit`. Locally `auto` may choose
HTML renderer. For parity with prod, test with:
```bash
flutter run -d chrome --web-renderer canvaskit
```

**Checkers multi-jump not completing**
The model enforces that when a piece has a mandatory follow-up capture after a
jump, `mustContinueFrom` is set and the turn does not change. Any change to move
handling must preserve this; the `checkers_model_test.dart` has coverage for it.

---

## Dependency management

```bash
# Check for outdated packages
flutter pub outdated

# Upgrade within constraints
flutter pub upgrade

# Upgrade past major versions (review changelog first)
flutter pub upgrade --major-versions
```

Current dependencies are intentionally minimal:
- `shared_preferences` — game stats & settings persistence
- `cupertino_icons` — iOS-style icon set

Do not add dependencies without a strong reason. The lighter the dependency tree,
the fewer supply-chain and compatibility issues.
