# CLAUDE.md — Board Box (Claude Code layer)

**Read [`AGENTS.md`](AGENTS.md) first.** It has the project overview, quality
gate, architecture, code style, game invariants, commit conventions, and the
secret-management rules. This file is the Claude-Code-specific layer:
command allowlists, workflow expectations, skill hints, and the verification
loop. Keep it short — bloated CLAUDE.md files cause Claude to ignore the
real rules (see Anthropic's memory guidance).

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

## Workflow expectations

### Plan before code

For any non-trivial change (new game, new screen, model+board refactor,
multi-file feature, dependency change), enter plan mode first. Plans should
name the files to touch, the test files to add/update, and the verification
step (the three quality-gate commands).

### Verification loop is mandatory

Before saying a task is done, run the three-gate sequence from `AGENTS.md`
and paste the output. "Looks done" is not done. If a gate cannot run (e.g.
no Flutter SDK in this environment), say so explicitly and explain why.

### Prefer parallel subagents for investigation

Use subagents to investigate (e.g. "find every place that calls
`SharedPreferences` and list the keys") so exploration doesn't bloat the
main context. The `flutter-expert`, `code-reviewer`, and `code-explorer`
subagent types are good fits.

### Skills to prefer

- `flutter-test` — write/run tests for game model changes
- `flutter-review` — pre-PR review pass
- `flutter-build` — debug/web/iOS smoke builds
- `code-review` — bundled review skill, runs in a fresh subagent
- `tdd-guide` — for any new feature work (write tests first)

### Compact carefully

When the context compacts, preserve:

- The list of files modified in the current task
- The exact quality-gate command outputs
- Any TODO items the user added inline during the session

If compaction is losing important state, add a one-line rule to
`.claude/settings.json` (e.g. a `compactInstructions` hint) — not to this file.

---

## Local-only notes

`CLAUDE.local.md` is for personal scratch (your API keys, your local FVM path,
your WIP reminders). It is in `.gitignore` — keep it that way. Anything that
should be shared with the team belongs in `AGENTS.md` or this file.

---

## References

- [`AGENTS.md`](AGENTS.md) — portable project rules (read first)
- `docs/ci.md` — CI/CD deep dive (signing secrets, Pages, branch protection)
- `docs/design/` — architecture decision records
- `analysis_options.yaml` — full lint rule list
- `.github/workflows/ci.yml` — pipeline definition
