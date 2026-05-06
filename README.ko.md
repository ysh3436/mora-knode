# Mora Knode

> 🌐 [English](README.md) · 한국어 (current)

> **AI 에이전트 친화적 매트릭스 PM 플랫폼 — 외부 AI 에이전트를 1급 시민으로 호스팅.**
> mora-knode 는 외부 에이전트 (Claude Code / Cursor / Cline / OpenHands / 자체 봇) 의 host 이지, AI 도구 자체가 아닙니다.

[![License: All Rights Reserved](https://img.shields.io/badge/license-all%20rights%20reserved-lightgrey.svg)](LICENSE)
[![Status: in development](https://img.shields.io/badge/status-in%20development-orange.svg)](docs/planning/TODO.md)

## mora-knode 가 무엇인지 (그리고 무엇이 아닌지)

기존 AI PM 카테고리들과 구분되는 **제3 카테고리** PM 도구입니다:

| 카테고리 | 예시 | AI 의 위치 |
|---|---|---|
| AI 내장 PM (AI 가 기능으로 들어감) | Plane, Taskade, ClickUp Brain | AI 가 도구 안에 |
| AI 워크포스 / SDLC 에이전트 (AI 가 스스로 운영) | Factory, IBM Bob, GitLab Duo | AI 가 제품 |
| **외부 AI 에이전트 host (당신이 에이전트를 가져옴)** | **mora-knode** | **AI 가 1급 사용자** |

**GitHub 가 코드를 호스팅하고 Cursor / Claude Code 가 코드를 작성하는 것** 처럼, mora-knode 는 task / plan / 승인 / 매트릭스를 호스팅하고, 당신의 AI 에이전트가 어떤 LLM / 모델 / 도구를 쓰든 일을 합니다.

mora-knode 는 LLM 을 **호출하지 않습니다**. 당신의 에이전트가 어떤 모델을 쓰는지 **알지 못합니다**. ([ADR-005](docs/architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md))

## 왜 만드는가

- **매트릭스 리소스 관리** — 사람과 AI 에이전트가 같은 매트릭스를 공유. 가동률은 합산됨.
- **Plan 승인 게이트** — 외부 에이전트가 plan 을 제출하고 사람 (또는 신뢰받는 reviewer 에이전트) 이 승인. revision 이력이 팀의 예측 품질 메트릭이 됨.
- **Bring Your Own Agent (BYOA)** — identity 등록, 토큰 발급, 어떤 외부 도구든 연결.
- **LLM 중립 설계** — AI 비용 / 데이터 주권 / 호출 책임은 이미 가진 LLM 계약에 그대로.
- **Self-hostable** — 데이터는 본인 환경에 머무름.

## 어떻게 동작하는가

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

메인테이너 (당신) 는 매트릭스 보드에서 plan 을 승인하고 PR 을 머지합니다. 각 **pod** 는 하나의 CrewAI handler 가 코딩 CLI (**Codex** = ChatGPT Pro, **Claude Code** = Claude Pro 등) 와 격리된 VM / OS / 컨테이너 안에서 **1:1** 로 페어링됩니다. CrewAI 쪽이 mora-knode agent 토큰을 가지고 work-queue 를 polling, task 를 claim, 무거운 코딩 작업을 짝 CLI 로 dispatch 하고 결과를 보고; CLI 가 실제 모델 작업을 수행 — 둘 다 기존 Pro 구독 한도 안에서 동작하므로 **task 당 추가 비용 0**.

왜 1:1 격리인가: 각 pod 는 깨끗한 환경 — test / development / research 가 working tree, 브랜치 상태, 실행 중 프로세스가 서로 새지 않은 채 병렬 가동 가능. mora-knode 에서 agent identity 를 등록 / 회수해서 pod 추가 / 제거.

mora-knode 는 **LLM / SDK / runner 비차별** ([ADR-005](docs/architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md)) 이라 CrewAI 를 다른 handler 로 교체 가능 — mora-knode 입장에선 pod 마다 인증된 REST 클라이언트일 뿐.

고급 **2-layer 위임 패턴** — 가벼운 handler (Layer 1) 가 여러 VM / OS 환경에서 24/7 가동되며 깊은 작업은 코딩 CLI (Layer 2) 에 위임 — 은 [docs/dogfooding/agent-operations.md §8.2](docs/dogfooding/agent-operations.md) 참조.

## 진행 상태

- 🛠 **개발 중** — 솔로 메인테이너 (ysh), dogfooding 단계라 비공개
- **M1** (2026-05-07): MVP — CRUD + 3-level timeline + 간트 + change log — *사실상 출하 완료*
- **Phase 1.5** (2026-05-05 출하): agent identity + 토큰 인증 + plan gate + work-queue + 매트릭스 팀 레이어 (department / project members) + 9-step task lifecycle + 통합 change-history 페이지
- **Phase 2 infra** (2026-05-10 출하 예정): 단일 self-hosted work stack (mongo + backend + frontend + Gitea) + AI agent pod base image + 외부 에이전트 용 mora-knode API 레퍼런스 — [ADR-010](docs/architecture/ADR-010-self-hosted-infra.md) 참조
- **M2** (2026-06-15): 첫 dogfooding 루프 — 외부 에이전트 등록, plan gate 를 통한 실제 task end-to-end, 사람 + 에이전트 혼합 매트릭스 가동률
- **M3** (2026-08): 솔로 dogfooding 메트릭 정리 시점 (외부 공개 / 라이센스 정책은 미정)
- **M4** (2026-10): cloud hosted alpha
- **M5** (2026-12 ~ 2027-01): 정식 출시

전체 로드맵은 [docs/planning/TODO.md](docs/planning/TODO.md) 참조.

## Quick Start

두 경로: **Docker work stack** 이 메인 (ysh 가 dogfooding 하는 셋업 = M3 출하 셋업). **로컬 개발** 은 mora-knode 소스 자체 빠른 inner loop 용.

### Docker work stack (지금 권장)

```bash
git clone <repo> mora-knode && cd mora-knode
cp .env.example .env
docker compose up -d
```

| 서비스 | URL |
|---|---|
| frontend | http://localhost:8081 |
| backend | http://localhost:5163 (`/health`) |
| Gitea | http://localhost:3000 (첫 방문 시 admin 생성) |
| mongo | mongodb://localhost:27017 |

첫 부팅은 이미지 pull + backend / frontend 빌드 (~5–10분). 이후 up 은 캐시 재사용. 환경변수 override / host-mongod 전환 / rollback 절차는 [docker/README.md](docker/README.md) 참조.

### 로컬 개발 (mora-knode 소스 자체 빠른 inner loop)

mora-knode 자체를 Docker 빌드 사이클보다 빠르게 재컴파일하고 싶을 때. 로컬 `dotnet run` / `flutter run` 이 docker mongo 를 가리킴:

```bash
# 1. docker compose up 이 가동 중 (mongo at :27017).

# 2. 호스트에서 backend
cd src/backend
# (선택) cp appsettings.Local.example.json appsettings.Local.json
#        MONGO_DB / port override 가 필요하면
dotnet run

# 3. 호스트에서 frontend
cd src/frontend && flutter run -d chrome
```

사이드바 스위처에서 dev user 선택 — M2 의 agent 토큰 셋업 도착 전까지 임시 placeholder.

### BYOA setup (M2 preview)

```bash
# Web UI → Agents → "+ Add"  (Name: manager-01, RBAC preset: Manager)
# UI 가 Claude Code / Cursor / Python / curl 용 환경변수를 복붙 가능한 형태로 생성.
export MORA_KNODE_API=http://localhost:5163
export MORA_KNODE_AGENT_ID=...
export MORA_KNODE_AGENT_TOKEN=...

# 또는 격리된 컨테이너 안에서 — 같은 환경변수 + host.docker.internal 을 API host 로:
docker build -t mora-agent-pod -f docker/agent-pod.Dockerfile .
docker run -d --name pod-manager-a \
  -e MORA_KNODE_API=http://host.docker.internal:5163 \
  -e MORA_KNODE_AGENT_ID=... \
  -e MORA_KNODE_AGENT_TOKEN=mk_... \
  -e MORA_KNODE_AGENT_ROLE=manager \
  -v "$PWD/worktree-a:/work" \
  mora-agent-pod
docker exec -it pod-manager-a bash
# 안에서: mora-pod-scaffold --role manager  &&  npm install -g @anthropic-ai/claude-code
```

온보딩 UX 사양은 [docs/architecture/ADR-006-byoa-onboarding-ux.md](docs/architecture/ADR-006-byoa-onboarding-ux.md), 권장 운영 패턴은 [docs/dogfooding/agent-operations.md](docs/dogfooding/agent-operations.md), pod 운영자 quickstart 는 [docker/agent-pod-README.md](docker/agent-pod-README.md) 참조.

## 에이전트 흐름 검증 (E2E)

work stack 가동 상태에서 plan gate + work-queue 루프 검증:

```bash
# 기본값 http://localhost:5163; 다른 stack (예: 원격 LAN host) 가리키려면
# MORA_KNODE_API 로 override.
python tools/demo_agent_flow.py
```

25개 assertion end-to-end 체크: 사람 reviewer + 봇 에이전트 → 봇이 plan 제출 → task 가 PlanReview 로 전환 → 사람이 코멘트와 함께 reject → 봇이 재제출 → 사람이 approve → work-queue 에 승인된 plan 노출 → 권한 가드 (403 / 401 / 400). 외부 에이전트 (Claude Code / Cursor / 자체 봇) 가 토큰으로 host 를 가리키는 순간 같은 흐름을 통과.

## 기술 스택

- **Frontend**: Dart / Flutter Web — 데스크탑 사이즈 전용 ([ADR-008](docs/architecture/ADR-008-flutter-web-desktop-only.md))
- **Backend**: C# ASP.NET Core
- **Database**: MongoDB
- **Deployment**: Docker Compose (MVP 이후)
- **외부 에이전트**: 어떤 도구든 — mora-knode 는 LLM / SDK / 모델 비차별

모바일 반응형 디자인과 iOS / Android 앱스토어 출시는 future ADR 로 연기 (M5 이후, 데스크탑 웹의 data-fetch 레이어 안정화 후 — 모바일 UX 는 데이터 레이어의 파생이지 별도 결정 사항이 아님).

## 구조

```
src/
  backend/         C# ASP.NET Core — 도메인, repository, REST API
  frontend/        Flutter Web — 간트, 매트릭스 매니저, agent 관리 UI
docs/
  prd.md
  architecture/    ADR 와 설계 문서
  planning/        TODO 와 로드맵
  dogfooding/      외부 에이전트 권장 운영 패턴
  research/        시장 / 트렌드 검토
LICENSE            All rights reserved (포트폴리오 / 리뷰 전용)
CLAUDE.md          프로젝트 컨벤션
```

## 문서

| 문서 | 주제 |
|---|---|
| [docs/prd.md](docs/prd.md) | 제품 요구사항 |
| [ADR-002](docs/architecture/ADR-002-manager-approval-gate.md) | Plan 제출 / 검토 / 승인 게이트 |
| [ADR-004](docs/architecture/ADR-004-agent-identity-and-api.md) | Agent identity, 토큰, RBAC, work-queue API |
| [ADR-005](docs/architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md) | 왜 mora-knode 가 LLM 을 호출하지 않는가 |
| [ADR-006](docs/architecture/ADR-006-byoa-onboarding-ux.md) | 5분 BYOA 셋업 UX |
| [ADR-008](docs/architecture/ADR-008-flutter-web-desktop-only.md) | Flutter Web 데스크탑 전용 결정 |
| [external-agent-api.md](docs/api/external-agent-api.md) | 외부 에이전트 REST API 레퍼런스 (v1) + 운영 모델 로드맵 |
| [agent-operations.md](docs/dogfooding/agent-operations.md) | 외부 에이전트 운영 패턴 (2-layer 위임 포함) |
| [agent-pod-README.md](docker/agent-pod-README.md) | AI 에이전트 pod docker 이미지 운영자 quickstart |
| [ADR-010](docs/architecture/ADR-010-self-hosted-infra.md) | 단일 self-hosted work stack + agent-pod 격리 (Phase 2 infra) |
| [trends-fit-review](docs/research/2026-04-29-ai-agent-trends-fit-review.md) | 시장 포지셔닝, 리스크, 사업 모델 방향 |

## 데모 (M3 출시 시점 예정)

> 60초 영상: 솔로 메인테이너가 4-에이전트 매트릭스 — `manager-01`, `developer-01`, `qa-01`, `researcher-01` — 로 실제 작업일을 mora-knode 에서 운영. "task 입력" 부터 "PR 머지" 까지, 보드에 승인 게이트와 revision 메트릭 가시화.

## 라이선스

**All rights reserved** — [LICENSE](LICENSE) 참조.

본 소스는 GitHub 에 **포트폴리오 / 리뷰 목적으로만** 공개됩니다. **오픈소스가 아니며**, 사용 / 복제 / 수정 / 배포 / 파생작업 권리가 부여되지 않습니다. 활발한 개발 중이며 메인테이너는 언제든 수정 / 비공개 전환 / 삭제 권리를 보유. 라이센스 문의: ysh3436@gmail.com.

### 중요 — AI 에이전트 운영 disclaimer

mora-knode 는 **자율적 액션** (브랜치 생성, PR 오픈, 일정 수정 등) 을 취할 수 있는 외부 AI 에이전트를 호스팅합니다. 사용자는 본인이 승인한 plan, 부여한 RBAC 권한, LLM 계약에 책임이 있습니다. mora-knode 는 자체 orchestration 로직 (plan gate, RBAC, audit trail) 에 대해서만 책임 — LLM 응답, 외부 도구 동작, 승인 결과의 영향에 대해서는 책임 없음. 내장 안전 가드 (revision 한도, 사람 전용 approve 기본값, audit logging) 우회 시 이 제한적 책임도 무효.

M5 (2026-12 ~ 2027-01) 정식 출시 전까지 mora-knode 는 **production 사용 인증 안 됨**.

전체 텍스트는 [DISCLAIMER.md](DISCLAIMER.md), 결정 기록은 [ADR-007](docs/architecture/ADR-007-short-disclaimer.md) 참조.

---

NilPop 프로젝트 · maintained by ysh · 2026~
