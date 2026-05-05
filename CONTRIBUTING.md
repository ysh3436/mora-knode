# Contributing

mora-knode is in private dogfooding (Phase 1.5 shipped 2026-05-05, public
release targeted for M3 ~2026-08). External PR policy will be defined when
the repo goes public; this file is the self-onboarding guide for the solo
maintainer and any private collaborators in the meantime.

## Setup

See the [README's Quick Start](README.md#quick-start) — local dev needs
MongoDB on `:27017`, .NET 10 SDK, and Flutter (web).

After the backend and frontend come up, verify the agent loop end-to-end:

```bash
python tools/demo_agent_flow.py
```

25 assertions covering the plan-gate + work-queue path. If this passes,
the host is ready for an external agent.

## Language

- Prose, design docs, comments inside design docs: **Korean**
- Code, identifiers, file names, commit messages: **English**
- Tech terms keep their original spelling inside Korean prose ("이 endpoint는...").

ADRs in [`docs/architecture/`](docs/architecture/) are sometimes bilingual —
Korean rationale with English code blocks. That's intentional, not a bug.

## Commit messages — Conventional Commits

```
<type>(<scope>): <subject>

<body — optional>
```

- type: `feat` `fix` `docs` `refactor` `test` `chore` `perf` `build` `ci` `style`
- scope: optional, module-level (`readme`, `auth`, `gantt`, `matrix`, ...)
- subject: imperative, lowercase, no trailing period, ≤ 72 chars
- one concern per commit — split unrelated changes into separate commits

## Branch workflow

- **No direct commits to `master`.** Branch per work unit:
  `<type>/<short-desc>` (e.g. `feat/plan-gate`, `chore/readme-polish-mk80`)
- Merge with `--no-ff` so the merge point survives in the history.
- TODO/in-app task updates ride in the same commit as the change they
  describe — don't create separate "checkpoint" commits.

## Verification expectations

- Backend changes: `dotnet build src/backend` clean
- Frontend changes: `flutter analyze` (in `src/frontend/`) no new warnings
- Cross-cutting agent / plan / work-queue changes: rerun
  `python tools/demo_agent_flow.py` to keep the 25-assertion E2E green
- UI work: launch the dev server fresh and exercise the feature in Chrome
  before declaring done — type-check passing ≠ the feature works

## In-app task tracking (dogfooding)

The maintainer's TODO board is the **mora-knode itself** project inside
the running mora-knode instance (`MK-N` numbering). Phase 1.5 sub-tasks
live there as MK-75's children. When you start a task:

1. Mark its status `InProgress` in the inspector
2. Branch (`<type>/<short-desc>`)
3. Work, commit, merge with `--no-ff`
4. Mark `Done` — parent rolls up automatically via `StatusAggregator`

Convenience helper: `python tools/mark_done.py <taskId>` (avoids the
PowerShell cp949 mojibake that mangles Korean titles on PUT round-trip).

## Where things live

| | |
|---|---|
| Project conventions | [CLAUDE.md](CLAUDE.md) |
| Architecture decisions | [docs/architecture/](docs/architecture/) (ADR-NNN) |
| Phase / milestone roadmap | [docs/planning/TODO.md](docs/planning/TODO.md) |
| Agent operating patterns | [docs/dogfooding/agent-operations.md](docs/dogfooding/agent-operations.md) |
| Schema integration plan | [docs/architecture/schema-integration-for-agents.md](docs/architecture/schema-integration-for-agents.md) |

For conventions covering all NilPop projects (not just this one), see the
workspace [CLAUDE.md](../../CLAUDE.md) one level up.
