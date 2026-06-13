# CLAUDE.md — Board Box (Claude Code layer)

**Read [`AGENTS.md`](AGENTS.md) first.** It has the project overview, the
3-gate, architecture rules, game invariants, commit conventions, and the
secret-management rules. This file is the Claude-Code-specific layer:
command allowlists, workflow expectations, subagent hints, and the
verification loop. Keep it short — bloated CLAUDE.md files cause Claude to
ignore the real rules (see Anthropic's memory guidance).

For deep-dives, see [`docs/`](docs/README.md).

---

## Order of operations

1. Read this file (you're doing it).
2. Read [`AGENTS.md`](AGENTS.md) — portable project rules.
3. Read `.claude/rules/<path>.md` for the area you're touching (auto-loaded;
   covers `lib/games/`, `lib/screens/`, `lib/services/`, `test/`).
4. Read the relevant `docs/` file (see "Pointer to docs/" below).
5. Then plan, then code, then verify (the 3-gate), then commit.

---

## Pre-approved commands (no prompt needed)

- `flutter pub get`
- `dart format .` (auto-fix, then re-verify)
- `dart format --output=none --set-exit-if-changed .`
- `flutter analyze --fatal-infos`
- `flutter test` (single file or whole suite)
- `flutter test --coverage`
- `flutter build apk --debug`
- `flutter build web --release --base-href /BoardBox/`
- `git status`, `git diff`, `git log`, `git add`, `git commit`, `git push`
- `gh pr create`, `gh pr view`, `gh pr list`, `gh run list`, `gh run view`
- Read-only shell: `cat`, `ls`, `find`, `grep`, `rg`

## Ask before running

- `flutter build appbundle --release` (touches signing config)
- `flutter build ios` (macOS runner, expensive)
- Anything that modifies `android/key.properties`, `*.jks`, `*.der`, or
  `ANDROID_*` GitHub Secrets
- `flutter pub upgrade --major-versions` (review changelogs first)
- `git push --force`, `git reset --hard`, branch deletes on shared branches
- `rm -rf` outside of `build/` and `.dart_tool/`

---

## Plan before code

For any non-trivial change (new game, new screen, model+board refactor,
multi-file feature, dependency change), enter plan mode first. Plans should
name the files to touch, the test files to add/update, and the verification
step (the three quality-gate commands). Trivial fixes (typos, single-line
lints, format-only) can skip plan mode.

---

## Three-gate verification loop (mandatory)

Before saying a task is done, run the three-gate sequence from `AGENTS.md`
and paste the output. "Looks done" is not done. If a gate cannot run (e.g.
no Flutter SDK), say so explicitly.

```
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```

---

## Subagent guidance

Order of dispatch by task shape:

- **Investigate (read-only):** `code-explorer` / `Explore` for "find every
  place that calls X" or "map the architecture."
- **Plan:** `planner` / `Plan` for multi-file features and refactors.
- **Implement:** `flutter-expert` (Flutter patterns) or `code-architect`.
- **Test:** `tdd-guide` (write-tests-first), `flutter-test` (running).
- **Review:** `code-reviewer`, `flutter-reviewer`, `security-reviewer`.
- **Debug:** `debugger` for test failures, `build-error-resolver` for
  `dart analyze` / `flutter build` failures.

**Compact carefully.** Preserve: files modified in the current task; exact
quality-gate command outputs; inline TODO items the user added. If
compaction keeps losing state, add a one-line `compactInstructions` hint
to `.claude/settings.json` — not to this file.

---

## Local-only notes

`CLAUDE.local.md` is for personal scratch (your API keys, your local FVM
path, your WIP reminders). It is in `.gitignore` — keep it that way.
Anything that should be shared with the team belongs in `AGENTS.md`,
`docs/`, or this file.

---

## Pointer to docs/

| For… | Read… |
|---|---|
| How to design a new app / feature / PR | [`docs/design/01-design-process.md`](docs/design/01-design-process.md) |
| Code architecture, model purity, service pattern | [`docs/design/02-architecture.md`](docs/design/02-architecture.md) |
| Design tokens, component state matrix, motion | [`docs/design/03-design-system.md`](docs/design/03-design-system.md) |
| UI/UX rules (Nielsen, Norman, M3, HIG, WCAG) | [`docs/design/04-ui-ux-principles.md`](docs/design/04-ui-ux-principles.md) |
| In-repo component catalog | [`docs/design/05-component-library.md`](docs/design/05-component-library.md) |
| How to break a feature into PRs | [`docs/design/06-feature-decomposition.md`](docs/design/06-feature-decomposition.md) |
| PR review checklist (design) | [`docs/design/07-pr-review-checklist.md`](docs/design/07-pr-review-checklist.md) |
| AI guardrails (prompts, hard enforcement) | [`docs/design/08-ai-assistant-guide.md`](docs/design/08-ai-assistant-guide.md) |
| Dart 3 / Flutter idioms + lint rationale | [`docs/engineering/flutter-dart-style.md`](docs/engineering/flutter-dart-style.md) |
| Tests (unit/widget/integration/golden) + async | [`docs/engineering/testing-strategy.md`](docs/engineering/testing-strategy.md) |
| CI/CD + GitHub Actions + secrets in CI | [`docs/engineering/ci-cd.md`](docs/engineering/ci-cd.md) |
| Bug-hunt process (adversarial review, severity) | [`docs/engineering/bug-hunt-process.md`](docs/engineering/bug-hunt-process.md) |
| Per-PR code review checklist | [`docs/engineering/code-review-checklist.md`](docs/engineering/code-review-checklist.md) |
| Secrets & privacy policy | [`docs/engineering/secrets-and-privacy.md`](docs/engineering/secrets-and-privacy.md) |
| UI/UX reference (citations) | [`docs/engineering/ui-ux-reference.md`](docs/engineering/ui-ux-reference.md) |

*Keep this file ≤120 lines — bloat kills the rules.*
