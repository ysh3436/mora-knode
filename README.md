# Mora Knode

> 🌐 English (current) · [한국어](README.ko.md)

> **An AI agent-friendly matrix PM platform — bring your own AI agents.**
> mora-knode is the host for external agents (Claude Code / Cursor / Cline / OpenHands / your own bots), not an AI tool itself.

[![License: All Rights Reserved](https://img.shields.io/badge/license-all%20rights%20reserved-lightgrey.svg)](LICENSE)
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
- **Self-hostable** — your data stays with you.

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
                                    │  (one identity per pod)
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                           │
   ┌────┴─────────┐            ┌────┴─────────┐            ┌────┴─────────┐
   │ Pod #1       │            │ Pod #2       │            │ Pod #N       │
   │ (VM / OS)    │            │ (VM / OS)    │            │ (VM / OS)    │
   │ ┌──────────┐ │            │ ┌──────────┐ │            │ ┌──────────┐ │
   │ │ CrewAI   │ │            │ │ CrewAI   │ │            │ │ CrewAI   │ │
   │ │ handler  │ │            │ │ handler  │ │            │ │ handler  │ │
   │ └────┬─────┘ │            │ └────┬─────┘ │            │ └────┬─────┘ │
   │      │ CLI   │            │      │ CLI   │            │      │ CLI   │
   │      ▼       │            │      ▼       │            │      ▼       │
   │ ┌──────────┐ │            │ ┌──────────┐ │            │ ┌──────────┐ │
   │ │  Codex   │ │            │ │  Claude  │ │            │ │   ...    │ │
   │ │   CLI    │ │            │ │ Code CLI │ │            │ │   CLI    │ │
   │ └────┬─────┘ │            │ └────┬─────┘ │            │ └────┬─────┘ │
   │      ↓       │            │      ↓       │            │      ↓       │
   │     LLM      │            │     LLM      │            │     LLM      │
   └──────────────┘            └──────────────┘            └──────────────┘
   isolated env                isolated env                isolated env
   (e.g. test)                 (e.g. dev)                  (e.g. research)
```

The maintainer (you) sits at the matrix board, approves plans, merges PRs. Each **pod** is one CrewAI handler paired **1:1** with a single coding CLI (**Codex** on ChatGPT Pro, **Claude Code** on Claude Pro, etc.) inside an isolated VM / OS / container. The CrewAI side owns the mora-knode agent token, polls the work-queue, claims tasks, and dispatches the heavy coding work to its paired CLI; the CLI does the actual model work — both run under existing Pro subscriptions for **zero additional per-task cost**.

Why 1:1 and isolated: each pod is a clean environment — test / development / research can run side-by-side without their working trees, branch state, or running processes leaking into each other. Add or remove a pod by registering / revoking its agent identity in mora-knode.

Because mora-knode is **LLM-/SDK-/runner-agnostic** ([ADR-005](docs/architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md)), you can swap CrewAI for any other handler — what mora-knode sees is just an authenticated REST client per pod.

For the advanced **2-layer delegation pattern** — lightweight handlers (Layer 1) running 24/7 across multiple VMs / OS environments, delegating heavy work to coding CLIs (Layer 2) — see [docs/dogfooding/agent-operations.md §8.2](docs/dogfooding/agent-operations.md).

## Status

- 🛠 **In development** — solo maintainer (ysh), private during dogfooding
- **M1** (2026-05-07): MVP — CRUD + 3-level timeline + Gantt + change log — *essentially shipped*
- **Phase 1.5** (shipped 2026-05-05): agent identity + token auth + plan gate + work-queue + matrix team layer (department / project members) + 9-step task lifecycle + unified change-history page
- **Phase 2 infra** (shipping 2026-05-10): single self-hosted work stack (mongo + backend + frontend + Gitea) + AI agent pod base image + mora-knode API reference for external agents — see [ADR-010](docs/architecture/ADR-010-self-hosted-infra.md)
- **M2** (2026-06-15): first dogfooding loop — register external agents, run a real task end-to-end through the plan gate, matrix utilization with mixed humans + agents
- **M3** (2026-08): public open-source release with 3 months of dogfooding metrics
- **M4** (2026-10): cloud hosted alpha
- **M5** (2026-12 ~ 2027-01): general availability

See [docs/planning/TODO.md](docs/planning/TODO.md) for the full roadmap.

## Quick Start

Two paths: the **Docker work stack** is the primary path (matches what
ysh dogfoods + what M3 ships). The **local dev** path is for fast
inner-loop iteration on the mora-knode source itself.

### Docker work stack (recommended, today)

```bash
git clone <repo> mora-knode && cd mora-knode
cp .env.example .env
docker compose up -d
```

| Service  | URL                                       |
|----------|-------------------------------------------|
| frontend | http://localhost:8081                     |
| backend  | http://localhost:5163  (`/health`)        |
| Gitea    | http://localhost:3000  (open + create admin on first visit) |
| mongo    | mongodb://localhost:27017                 |

First boot pulls images and builds the backend + frontend (~5–10 min).
Subsequent ups reuse the cache. See [docker/README.md](docker/README.md)
for env overrides, the host-mongod cutover procedure, and rollback
steps.

### Local dev (fast inner loop on mora-knode source)

For rebuilding and re-running mora-knode itself faster than the Docker
build cycle. Point the local `dotnet run` / `flutter run` at the
docker mongo:

```bash
# 1. Make sure docker compose up is running (mongo at :27017).

# 2. Backend on the host
cd src/backend
# (optional) cp appsettings.Local.example.json appsettings.Local.json
#            and override MONGO_DB / port if you need a separate DB
dotnet run

# 3. Frontend on the host
cd src/frontend && flutter run -d chrome
```

Pick a dev user from the sidebar switcher to scope what you see — this
is the placeholder until you set up agent tokens in M2.

### BYOA setup (M2 preview)

```bash
# Web UI → Agents → "+ Add"  (Name: manager-01, RBAC preset: Manager)
# UI generates copy-pasteable env vars for Claude Code / Cursor / Python / curl.
export MORA_KNODE_API=http://localhost:5163
export MORA_KNODE_AGENT_ID=...
export MORA_KNODE_AGENT_TOKEN=...

# Or run the agent inside an isolated container — same env vars, plus
# host.docker.internal as the API host:
docker build -t mora-agent-pod -f docker/agent-pod.Dockerfile .
docker run -d --name pod-manager-a \
  -e MORA_KNODE_API=http://host.docker.internal:5163 \
  -e MORA_KNODE_AGENT_ID=... \
  -e MORA_KNODE_AGENT_TOKEN=mk_... \
  -e MORA_KNODE_AGENT_ROLE=manager \
  -v "$PWD/worktree-a:/work" \
  mora-agent-pod
docker exec -it pod-manager-a bash
# inside: mora-pod-scaffold --role manager  &&  npm install -g @anthropic-ai/claude-code
```

See [docs/architecture/ADR-006-byoa-onboarding-ux.md](docs/architecture/ADR-006-byoa-onboarding-ux.md) for the onboarding UX spec, [docs/dogfooding/agent-operations.md](docs/dogfooding/agent-operations.md) for the recommended operating patterns, and [docker/agent-pod-README.md](docker/agent-pod-README.md) for the pod operator's quickstart.

## Verifying the agent flow (E2E)

With the work stack running, you can verify the plan-gate + work-queue loop:

```bash
# defaults to http://localhost:5163; override with MORA_KNODE_API to point
# at a different stack (e.g. a remote LAN host).
python tools/demo_agent_flow.py
```

This is a 25-assertion end-to-end check: human reviewer + bot agent → bot
submits plan → task moves to PlanReview → human rejects with comment → bot
re-submits → human approves → work-queue surfaces the approved plan →
permission guards (403 / 401 / 400). Same flow an external agent (Claude
Code / Cursor / your own bot) walks through once it points at the host with
a token.

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
LICENSE            All rights reserved (portfolio / review only)
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
| [external-agent-api.md](docs/api/external-agent-api.md) | External agent REST API reference (v1) + operating model roadmap |
| [agent-operations.md](docs/dogfooding/agent-operations.md) | External agent ops patterns (incl. 2-layer delegation) |
| [agent-pod-README.md](docker/agent-pod-README.md) | Operator quickstart for the AI agent pod docker image |
| [ADR-010](docs/architecture/ADR-010-self-hosted-infra.md) | Single self-hosted work stack + agent-pod isolation (this Phase 2 infra) |
| [trends-fit-review](docs/research/2026-04-29-ai-agent-trends-fit-review.md) | Market positioning, risks, business model direction |

## Demo (planned for M3 release)

> 60-second video: the solo maintainer running a 4-agent matrix — `manager-01`, `developer-01`, `qa-01`, `researcher-01` — through a real workday on mora-knode. From "task input" to "PR merged" with approval gates and revision metrics visible on the board.

## License

**All rights reserved** — see [LICENSE](LICENSE).

This source is published on GitHub for portfolio review and reading only. It is **not open source**: no license is granted to use, copy, modify, distribute, or create derivative works. The repository is in active development and the maintainer reserves the right to modify, make private, or remove it at any time. For licensing inquiries: ysh3436@gmail.com.

### Important — AI agent operation disclaimer

mora-knode hosts external AI agents that can take **autonomous actions** (creating branches, opening PRs, modifying schedules). You are responsible for plans you approve, RBAC permissions you grant, and your LLM contracts. mora-knode is responsible for its orchestration logic (plan gate, RBAC, audit trail) — not for LLM responses, external tool behavior, or consequences of your approvals. Bypassing built-in safeguards (revision limits, human-only approve defaults, audit logging) voids this limited responsibility.

Until M5 (2026-12 ~ 2027-01) general availability, mora-knode is **not certified for production use**.

See [DISCLAIMER.md](DISCLAIMER.md) for the full text and [ADR-007](docs/architecture/ADR-007-short-disclaimer.md) for the decision record.

---

A NilPop project · maintained by ysh · 2026~
