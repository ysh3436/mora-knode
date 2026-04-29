# NilPop Gantt Project CLAUDE

- slug: mora-knode
- owner: ysh
- status: draft

## 목표
매트릭스 조직 기반의 PM 플랫폼 MVP 개발. 사람과 외부 AI 에이전트가 1급 시민으로 협업하는 host 역할.

## 카테고리 (중요)
mora-knode 는 **AI 에이전트 친화적 매트릭스 PM 플랫폼** 이지 AI 자동화 도구가 아니다. GitHub 이 Cursor / Claude Code 의 host 인 것처럼, mora-knode 는 임의 외부 AI 에이전트의 협업 host. mora-knode 자체는 LLM 을 호출하지 않으며 모델/SDK/키도 모른다 ([docs/architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md](docs/architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md)).

## 기술 스택
- FE: Dart / Flutter Web — 데스크톱 사이즈 only (`src/frontend/`, [ADR-008](docs/architecture/ADR-008-flutter-web-desktop-only.md)). Windows native 제거. 모바일 / 앱스토어 / 반응형은 미래 별도 ADR
- BE: C# ASP.NET Core (`src/backend/`)
- DB: MongoDB
- 배포: Docker Compose (`docker/`, MVP 이후) — backend + Flutter Web 정적 자산 서빙
- 인증/라이선스: self-hosted + license-client (MVP 후 추가)

> Python orchestrator / Claude Agent SDK 는 mora-knode 의 일부가 **아니다**. 외부 AI 에이전트가 어떤 도구로 만들어지는지는 [docs/dogfooding/agent-operations.md](docs/dogfooding/agent-operations.md) 의 권장 패턴 참고 (강제 사양 아님).

## 프로젝트 특성
- 로컬 마크다운 우선
- PRD 기반 개발
- 외부 AI 에이전트가 mora-knode API 를 통해 1급 시민으로 협업하는 시뮬레이션으로 매트릭스 리소스 관리 검증
- ysh 본인이 외부 도구 (Claude Code / Cursor 등) 로 자기 에이전트 운영하며 dogfooding

## 소스 레이아웃
```
src/
  backend/       C# ASP.NET Core — 도메인 모델, Repository, REST API (Agent Identity / Plan Gate / Work-queue 포함)
  frontend/      Flutter — 간트 뷰, 매트릭스 리소스 매니저 UI, Agent 관리 화면
docker/          배포 조립 (Phase 2 이후)
docs/
  prd.md
  architecture/  ADR, 시스템 설계 문서
  planning/      TODO, 로드맵
  dogfooding/    외부 에이전트 운영 권장 가이드 (mora-knode 사양 아님)
  research/      시장 / 트렌드 검토
```

## 외부 AI 에이전트 통합 원칙
- 외부 에이전트는 mora-knode REST API 만 호출 (MongoDB 직접 접근 금지) — 스키마 진실 원천 단일화
- 모든 외부 에이전트는 mora-knode 가 발급한 **agent identity + 토큰 + RBAC** 로 인증 ([ADR-004](docs/architecture/ADR-004-agent-identity-and-api.md))
- 외부 에이전트가 제출한 plan 은 **사용자 (또는 권한 있는 다른 에이전트) 의 검토/승인 게이트** 통과 후에만 다운스트림 실행 ([ADR-002](docs/architecture/ADR-002-manager-approval-gate.md))
- mora-knode 는 어떤 LLM·모델·SDK 인지 모르며 호출하지 않음 ([ADR-005](docs/architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md))
