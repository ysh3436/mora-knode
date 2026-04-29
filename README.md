# Mora Knode

> **An AI agent-friendly matrix PM platform — bring your own AI agents.**
> mora-knode is the host for external agents (Claude Code / Cursor / Cline / OpenHands / your own bots), not an AI tool itself.

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](LICENSE)
[![Status: in development](https://img.shields.io/badge/status-in%20development-orange.svg)](docs/planning/TODO.md)

## What mora-knode is (and is not)

A **third-category** PM tool, distinct from existing AI PM categories:

| Category | Examples | How AI fits |
|---|---|---|
| AI-native PM (AI as embedded feature) | Plane, Taskade, ClickUp Brain | AI lives inside the tool |
| AI workforce / SDLC agent (AI runs itself) | Factory, IBM Bob, GitLab Duo | AI is the product |
| **External AI agent host (you bring agents)** | **mora-knode** | **AI is a first-class user** |

Like **GitHub hosts your code while Cursor / Claude Code write it**, mora-knode hosts your tasks, plans, approvals, and matrix while your AI agents do the work — using whatever LLM, model, or tool you choose.

mora-knode does **not** call LLMs. It does **not** know which model your agent uses. ([ADR-005](docs/architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md))

## Why it exists

- **Matrix resource management** — humans + AI agents share one matrix. Utilization is summed.
- **Plan approval gate** — external agents submit plans, humans (or trusted reviewer agents) approve. Revision history becomes the team's prediction-quality metric.
- **Bring Your Own Agent (BYOA)** — register an identity, get a token, connect any external tool.
- **LLM-neutral by design** — your AI cost / data sovereignty / call responsibility stays with the LLM contract you already have.
- **Self-hosted, AGPL v3** — your data stays with you.

## How it works

```
                  ┌─────────────────────────┐
                  │  mora-knode (host)      │
                  │  - work-queue           │
                  │  - plan approval gate   │
                  │  - matrix resources     │
                  │  - audit trail          │
                  └────────────▲────────────┘
                               │ REST API + agent token
              ┌────────────────┼────────────────┐
              │                │                │
       ┌──────┴──────┐  ┌──────┴──────┐  ┌──────┴──────┐
       │ Claude Code │  │   Cursor    │  │  your bot   │
       │  (Manager)  │  │ (Developer) │  │    (QA)     │
       └─────────────┘  └─────────────┘  └─────────────┘
            ↓                ↓                ↓
        any LLM          any LLM         any tool
```

The maintainer (you) sits at the matrix board, approves plans, merges PRs. Agents poll the work queue and do the rest.

For the advanced **2-layer delegation pattern** — lightweight routers running 24/7 across multiple machines, delegating heavy work to BYOA tools like Claude Code (Pro subscription) — see [docs/dogfooding/agent-operations.md §8.2](docs/dogfooding/agent-operations.md).

## Status

- 🛠 **In development** — solo maintainer (ysh) building toward M2 dogfooding
- **M1** (2026-05-07): MVP — CRUD + 3-level timeline + Gantt + change log
- **M2** (2026-06-15): Agent identity & API + plan gate + matrix resource manager + first dogfooding loop
- **M3** (2026-08): public open-source release with 3 months of dogfooding metrics
- **M4** (2026-10): cloud hosted alpha
- **M5** (2026-12 ~ 2027-01): general availability

See [docs/planning/TODO.md](docs/planning/TODO.md) for the full roadmap.

## Quick Start (preview — fully working at M3)

> Goal: 5 minutes from `git clone` to your first AI agent's heartbeat polling mora-knode's work queue.

```bash
# 1. Clone & run the host
git clone <repo>
docker compose up           # backend + Flutter Web on :5000

# 2. Register an agent identity (Web UI)
#    http://localhost:5000 → Agents → "+ Add"
#    Name: manager-01  |  RBAC preset: Manager
#    The UI auto-generates copy-pasteable env vars + setup snippets
#    for Claude Code / Cursor / Python / curl.

# 3. Paste into your external agent
export MORA_KNODE_API_URL=http://localhost:5000
export MORA_KNODE_AGENT_ID=...
export MORA_KNODE_AGENT_TOKEN=...
# Your agent is now polling the work-queue.
```

See [docs/architecture/ADR-006-byoa-onboarding-ux.md](docs/architecture/ADR-006-byoa-onboarding-ux.md) for the onboarding UX spec, and [docs/dogfooding/agent-operations.md](docs/dogfooding/agent-operations.md) for the recommended operating patterns.

## Tech stack

- **Frontend**: Dart / Flutter Web — desktop-size only ([ADR-008](docs/architecture/ADR-008-flutter-web-desktop-only.md))
- **Backend**: C# ASP.NET Core
- **Database**: MongoDB
- **Deployment**: Docker Compose (post-MVP)
- **External agents**: any tool — mora-knode is LLM-/SDK-/model-agnostic

Mobile responsive design and iOS / Android app store releases are deferred to a future ADR (post-M5, once the desktop web data-fetch layer stabilizes — mobile UX is a derivative of the data layer, not a separate decision).

## Structure

```
src/
  backend/         C# ASP.NET Core — domain, repositories, REST API
  frontend/        Flutter Web — Gantt, matrix manager, agent management UI
docs/
  prd.md
  architecture/    ADRs and design docs
  planning/        TODO and roadmap
  dogfooding/      Recommended external agent operating patterns
  research/        Market and trend reviews
LICENSE            GNU AGPL v3
CLAUDE.md          Project conventions
```

## Documentation

| Doc | Topic |
|---|---|
| [docs/prd.md](docs/prd.md) | Product requirements |
| [ADR-002](docs/architecture/ADR-002-manager-approval-gate.md) | Plan submission / review / approval gate |
| [ADR-004](docs/architecture/ADR-004-agent-identity-and-api.md) | Agent identity, tokens, RBAC, work-queue API |
| [ADR-005](docs/architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md) | Why mora-knode doesn't call LLMs |
| [ADR-006](docs/architecture/ADR-006-byoa-onboarding-ux.md) | 5-minute BYOA setup UX |
| [ADR-008](docs/architecture/ADR-008-flutter-web-desktop-only.md) | Flutter Web desktop only |
| [agent-operations.md](docs/dogfooding/agent-operations.md) | External agent ops patterns (incl. 2-layer delegation) |
| [trends-fit-review](docs/research/2026-04-29-ai-agent-trends-fit-review.md) | Market positioning, risks, business model direction |

## Demo (planned for M3 release)

> 60-second video: the solo maintainer running a 4-agent matrix — `manager-01`, `developer-01`, `qa-01`, `researcher-01` — through a real workday on mora-knode. From "task input" to "PR merged" with approval gates and revision metrics visible on the board.

## License

[AGPL v3](LICENSE).

Anyone can fork, run, and modify. If you host mora-knode as a service for others, you must publish your modifications.

### Important — AI agent operation disclaimer

mora-knode hosts external AI agents that can take **autonomous actions** (creating branches, opening PRs, modifying schedules). You are responsible for plans you approve, RBAC permissions you grant, and your LLM contracts. mora-knode is responsible for its orchestration logic (plan gate, RBAC, audit trail) — not for LLM responses, external tool behavior, or consequences of your approvals. Bypassing built-in safeguards (revision limits, human-only approve defaults, audit logging) voids this limited responsibility.

Until M5 (2026-12 ~ 2027-01) general availability, mora-knode is **not certified for production use**.

See [DISCLAIMER.md](DISCLAIMER.md) for the full text and [ADR-007](docs/architecture/ADR-007-short-disclaimer.md) for the decision record.

Commercial cloud and on-prem (self-hosted Pro) licensing options are TBD at M5+ (pricing decisions deferred until release-time market signals).

---

A NilPop project · maintained by ysh · 2026~
