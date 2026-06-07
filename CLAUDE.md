# Board Box — Developer Guide

**Package:** `com.boardbox.app`
**Flutter SDK:** `^3.12.0` · **Target SDK:** 35 · **Min SDK:** Flutter default (21)
**Java/Kotlin target:** JVM 17

Five classic local-multiplayer board games in one Flutter app:
Gomoku · Othello · Checkers · Dots & Boxes · Tic Tac Toe

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
├── main.dart                  # App entry point; initializes GameStats + SettingsService
├── models/
│   └── game_mode.dart         # GameMode (twoPlayer/singlePlayer), AiDifficulty
├── screens/
│   ├── splash_screen.dart     # Animated launch screen
│   ├── home_screen.dart       # 2-column game grid, stats, settings link
│   ├── mode_select_screen.dart# 2-player vs AI; difficulty picker; game rules
│   ├── game_screen.dart       # Hosts board widget; save/restore; stats; game-over dialog
│   ├── settings_screen.dart   # Hints, haptics, fast AI, dark mode
│   └── privacy_policy_screen.dart
├── games/
│   ├── gomoku/                # 15×15 board, win on 5-in-a-row
│   ├── othello/               # 8×8 Reversi with disc-flip logic
│   ├── checkers/              # 8×8, mandatory captures, multi-jump, king promotion
│   ├── dots_and_boxes/        # 5×5–7×7 dots, box-capture bonus turn
│   └── tictactoe/             # 3×3, 4×4, or 5×5 boards
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

### Model state
Current models are mutable pure-Dart objects. Board widgets mutate model state,
then call `setState`, push JSON to `stateNotifier`, and notify game-over when
needed. If you refactor toward immutable models, update every board widget and
the save/undo contract together.

### Services
`GameStats` and `SettingsService` are initialized in `main.dart`. Settings are
managed by the `SettingsService` singleton; do not write gameplay settings
directly to `SharedPreferences` from widgets.

### AI lives in the board widget
AI difficulty logic (`_easyMove`, `_mediumMove`, `_hardMove`) is in each
`*_board.dart`. If it grows large, extract to `*_ai.dart` in the same directory.

---

## Game invariants — never break these

| Game | Critical rules |
|------|---------------|
| **Gomoku** | 15×15 grid; five or more consecutive stones currently wins; black moves first |
| **Othello** | 8×8; player must pass if no valid moves; game ends when neither player can move |
| **Checkers** | Mandatory captures; multi-jump chains must complete; red moves first; kings move/capture both directions |
| **Dots & Boxes** | Completing a box grants an extra turn; game ends when all boxes are claimed |
| **Tic Tac Toe** | 3×3 and 4×4 win with 3; 5×5 wins with 4; X moves first |

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
3. Cover edge cases specific to the game (mandatory captures in checkers, pass in Othello, out-of-bounds inputs, etc.)

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

Pipeline: `.github/workflows/ci.yml`

### Pipeline overview

| Job | Runs on | Trigger | What it does |
|-----|---------|---------|-------------|
| `quality` | ubuntu-latest | every push & PR | format check · analyze · test + coverage |
| `build-debug` | ubuntu-latest | every push & PR | debug APK → artifact (7 days) |
| `build-android-release` | ubuntu-latest | `main` push | signed AAB → artifact (30 days) |
| `build-web` | ubuntu-latest | `main` push | web build → artifact (30 days) |
| `build-ios` | macos-latest | `main` push | iOS no-codesign compile check |

`quality` must pass before any build job starts. A failing `quality` job blocks
everything downstream and prevents merging if branch protection is enabled.

---

### 1. Local machine requirements

Everything CI uses must also work locally. Mismatches are the #1 source of
"passes locally, fails in CI" bugs.

| Requirement | Version | How to check |
|-------------|---------|-------------|
| Flutter SDK | `3.44.0` stable (pinned in CI) | `flutter --version` |
| Dart SDK | bundled with Flutter | `dart --version` |
| Java JDK | 17 | `java -version` |
| Android SDK | via Flutter / Android Studio | `flutter doctor` |
| Git | any recent | `git --version` |

Install / switch Flutter version:
```bash
flutter upgrade                     # upgrade to latest stable
# or use FVM to pin exactly:
dart pub global activate fvm
fvm install 3.44.0
fvm use 3.44.0
```

Check everything is wired correctly:
```bash
flutter doctor -v                   # fix any ✗ before pushing
```

---

### 2. Local signing setup (one-time, per machine)

`android/key.properties` is gitignored. Without it, debug builds still work
but release builds fail.

```bash
# Copy the template
cp android/key.properties.example android/key.properties

# Edit the file — use an absolute path for storeFile
nano android/key.properties
```

`key.properties` must contain:
```
storePassword=<store password>
keyPassword=<key password>
keyAlias=upload
storeFile=/absolute/path/to/android/upload-keystore.jks
```

The keystore file `android/upload-keystore.jks` is already in the repo
(gitignored by `*.jks` rule — keep it that way). If it's missing on a new
machine, obtain it from a team member or the secure key vault; never regenerate
it (Play Store will reject a new key for an existing app).

---

### 3. GitHub repository — one-time setup checklist

Complete these once after the repo is created. CI will fail silently or
partially until they are all done.

#### 3a. GitHub Actions permissions
`Settings → Actions → General → Workflow permissions`
- Select **Read and write permissions**
- Check **Allow GitHub Actions to create and approve pull requests**

This is required for the web deployment job to write to GitHub Pages.

#### 3b. GitHub Secrets — Android signing
`Settings → Secrets and variables → Actions → New repository secret`

Add all four secrets:

| Secret name | How to get the value |
|-------------|---------------------|
| `ANDROID_KEYSTORE_BASE64` | Run `base64 -w 0 android/upload-keystore.jks` locally and paste the output |
| `ANDROID_KEY_ALIAS` | `upload` (the alias used when the keystore was created) |
| `ANDROID_KEY_PASSWORD` | The key password from your `key.properties` |
| `ANDROID_STORE_PASSWORD` | The store password from your `key.properties` |

Encoding the keystore (Linux/macOS):
```bash
base64 -w 0 android/upload-keystore.jks | pbcopy   # macOS — copies to clipboard
base64 -w 0 android/upload-keystore.jks             # Linux  — copy output manually
```

> If any of these four secrets are missing, the `build-android-release` job
> will fail with a Gradle signing error. The other jobs are unaffected.

#### 3c. GitHub Pages
`Settings → Pages → Build and deployment → Source`
- Select **GitHub Actions** (not "Deploy from a branch")

The `build-web` job writes directly to Pages via `actions/deploy-pages`.
The live URL will be: `https://learn-by-exploration.github.io/BoardBox/`

#### 3d. Branch protection (recommended)
`Settings → Branches → Add branch protection rule` for `main`:
- Check **Require status checks to pass before merging**
- Add required checks: `Analyze & Test`, `Build Debug APK`
- Check **Require branches to be up to date before merging**

This prevents any code from merging that would break the build or tests.

---

### 4. What each job requires

#### `quality` (blocks everything)
- No secrets needed
- Fails if: formatting is off · any lint warning · any test fails
- Fix locally before pushing:
  ```bash
  dart format .                          # auto-fix formatting
  flutter analyze --fatal-infos          # must show zero issues
  flutter test                           # must show zero failures
  ```

#### `build-debug`
- No secrets needed
- Just needs Flutter + Android SDK on the runner (provided by `subosito/flutter-action`)
- Artifact available for 7 days under **Actions → the run → Artifacts**

#### `build-android-release`
- Requires all 4 `ANDROID_*` secrets (see §3b above)
- CI writes keystore to `android/upload-keystore.jks` at runtime from the secret
- CI writes `android/key.properties` at runtime from the secrets
- Neither file is persisted — they exist only during the job
- AAB artifact available for 30 days; download and upload to Play Store manually
  or wire up `google-github-actions/upload-to-play` for automated delivery

#### `build-web`
- Uploads the compiled web bundle as an Actions artifact
- Base href is `/BoardBox/` — matches the repo name; change if the repo is renamed
- Uses Flutter's default web renderer for the pinned SDK

#### `build-ios`
- Requires a **macOS runner** (billed at 10× the cost of ubuntu-latest on GitHub's
  free tier — ~10 min macOS ≈ 100 min ubuntu equivalent)
- No signing secrets needed (`--no-codesign`)
- Only verifies the iOS target compiles; does not produce an `.ipa`
- For App Store distribution, add Apple signing secrets and switch to
  `fastlane match` or the `apple-actions/import-codesign-certs` action

---

### 5. Artifacts — where to find them

After a pipeline run completes:
1. Go to **Actions** tab in GitHub
2. Click the specific workflow run
3. Scroll to **Artifacts** at the bottom of the summary page

| Artifact name | Job | Retention |
|---------------|-----|-----------|
| `debug-apk-<sha>` | `build-debug` | 7 days |
| `release-aab-<sha>` | `build-android-release` | 30 days |
| Web build | deployed live to Pages — no download needed | permanent |

---

### 6. Branch and trigger strategy

| Branch / event | Jobs that run |
|----------------|---------------|
| Push to `main` | All 5 jobs |
| Push to `develop` | `quality` + `build-debug` only |
| Pull request → `main` | `quality` + `build-debug` only |

Keep `develop` as the integration branch. Only merge to `main` when ready to
ship; merging to `main` triggers the release pipeline.

---

### 7. Concurrency — no duplicate runs

The workflow uses `cancel-in-progress: true` grouped by workflow + ref. If you
push two commits quickly, the first run is cancelled when the second starts.
This saves runner minutes on fast-moving branches.

---

### 8. CI troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `dart format` step fails | Local code not formatted | Run `dart format .` and commit |
| `flutter analyze` fails | Lint warning or type error | Fix the reported issue; `--fatal-infos` means warnings also block |
| Test failure | Broken game logic | Fix the code, not the test |
| `Keystore file not found` | `ANDROID_KEYSTORE_BASE64` secret missing or wrong | Re-encode and re-add the secret |
| `Pages not found` error in deploy job | GitHub Pages not set to GitHub Actions source | See §3c |
| iOS job fails with Xcode error | Xcode version on runner changed | Pin `xcode-version` in the step or check Flutter iOS compatibility matrix |
| Job queued but never starts | All runners busy (free tier limit) | Wait, or upgrade to a paid plan |

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
CI pins Flutter to `3.44.0` stable. Use the same version locally:
```bash
flutter upgrade
flutter --version
```

**Web build works but game is slow**
CI and deployment use Flutter's default web renderer for the pinned SDK. For a
local production-style smoke test, run:
```bash
flutter build web --release --base-href /BoardBox/
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
