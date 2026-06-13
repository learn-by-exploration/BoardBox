# Board Box Docs

The single discoverable source of truth for design, development, testing,
AI guardrails, bug-hunt process, UI/UX, and PR review in Board Box.

**Start here.** New contributor? Read [`../AGENTS.md`](../AGENTS.md) next,
then this index. New AI agent? Same order, but also read the path-scoped
rule in [`.claude/rules/`](../.claude/rules/) for the area you're touching.

---

## Conventions summary (one paragraph)

Board Box is a Flutter 3.44.0 / Dart `^3.12.0` app, Material 3, seed color
`0xFF5C35CC`, 9 games shipped, 236 tests green. Game logic lives in pure
Dart `*_model.dart` files (no Flutter imports); Flutter widgets and AI
live in `*_board.dart` siblings. Services are singletons with a
`Completer<void> _ready` gate (see [`engineering/testing-strategy.md`](engineering/testing-strategy.md)
§"Async patterns" and [`design/02-architecture.md`](design/02-architecture.md)
§"Service pattern"). The 3-gate is mandatory before declaring work done:
`dart format --output=none --set-exit-if-changed .` · `flutter analyze
--fatal-infos` · `flutter test`. Conventional Commits, no AI co-author
footers. Minimum 80% coverage on changed files. The 18 enabled lints in
[`analysis_options.yaml`](../../analysis_options.yaml) are the contract;
don't suppress them.

---

## Design (`docs/design/`)

How to design an app, what the architecture looks like, the design system,
UI/UX rules, the component catalog, and how to break features into PRs.

| File | Read this when… |
|---|---|
| [`01-design-process.md`](design/01-design-process.md) | You're starting a new app, a new feature, or want the PRD/feature-spec/DoR/DoD templates. |
| [`02-architecture.md`](design/02-architecture.md) | You need the model-purity rule, the service pattern, the state pattern, or the layer-boundary rules. |
| [`03-design-system.md`](design/03-design-system.md) | You're adding a color/typography/spacing/motion token, or wondering "what's the right elevation here?" |
| [`04-ui-ux-principles.md`](design/04-ui-ux-principles.md) | You want the Nielsen 10 + Norman 7 + M3 + HIG + WCAG 2.2 AA reference, or the mobile-first rules. |
| [`05-component-library.md`](design/05-component-library.md) | You're about to build a new widget. Check if it exists first. |
| [`06-feature-decomposition.md`](design/06-feature-decomposition.md) | A feature is large and you need to split it into PRs. Worked example: Minesweeper. |
| [`07-pr-review-checklist.md`](design/07-pr-review-checklist.md) | You're reviewing a PR. Pre-flight, code review, test review, UI/UX review, security review, a11y, performance, AC. |
| [`08-ai-assistant-guide.md`](design/08-ai-assistant-guide.md) | You're an AI assistant, or you're prompting one. The guardrails, do/don't, and hard-enforcement rules. |

## Engineering (`docs/engineering/`)

How to write Dart/Flutter code, how to test it, the CI pipeline, how to
run a bug hunt, the per-PR code review checklist, and the secrets policy.

| File | Read this when… |
|---|---|
| [`flutter-dart-style.md`](engineering/flutter-dart-style.md) | You want the rationale behind each of the 18 lints, or the type-system / null-safety / async / collections / classes / error-handling rules. |
| [`testing-strategy.md`](engineering/testing-strategy.md) | You're writing tests, debugging a flaky test, or designing the test pyramid for a new subsystem. |
| [`ci-cd.md`](engineering/ci-cd.md) | You want the local 3-gate + the CI pipeline in `.github/workflows/ci.yml` explained job-by-job. |
| [`bug-hunt-process.md`](engineering/bug-hunt-process.md) | You're auditing a working app for defects. The 6-lens review, severity ladder, repro template, triage flow. |
| [`code-review-checklist.md`](engineering/code-review-checklist.md) | You want the per-PR reviewer's checklist (code-quality focus; bridges `design/07-pr-review-checklist.md`). |
| [`secrets-and-privacy.md`](engineering/secrets-and-privacy.md) | You need to handle a secret, set up a new one, or respond to a leak. |
| [`ui-ux-reference.md`](engineering/ui-ux-reference.md) | You want Nielsen/Norman/M3/HIG citations to back a UX claim. (Stub — web research pending.) |

---

## How to contribute to these docs

- Same rules as code: PR, conventional commit, paste the 3-gate output.
- Update this README when adding or removing a doc.
- If the new doc is path-scoped (only relevant when editing a particular
  folder), also add a `.claude/rules/<path>.md` entry.
- Keep each doc focused — split a doc when it grows past 500 lines.
