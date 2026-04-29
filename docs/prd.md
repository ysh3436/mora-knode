# Mora Knode PRD

- slug: mora-knode
- 오너: ysh
- 상태: draft
- 최종 수정: 2026-04-29 (외부 에이전트 host 모델로 일반화 재작성)

## 1. 배경 / 문제
Notion / Linear / monday.com 같은 외부 SaaS 의존 없이 NilPop 자체에서 프로젝트 / 이슈 / TODO / 간트차트를 관리하고 싶다. 단 일반 PM 도구가 아니라 **외부 AI 에이전트가 사람과 동등한 1급 시민으로 협업하는 매트릭스 PM 플랫폼** 이 목표.

Mora Knode 기획서에서 영감을 받아 매트릭스 조직 구조를 수용하고 계획과 실행 사이의 '리듬' 을 분석해 조직의 예측력을 높인다. "Don't Check, Just Sync" 철학 — 감시가 아닌 동기화.

핵심 컨셉: 외부 AI 에이전트가 mora-knode 에 ID / API 토큰 / RBAC 권한 / 매트릭스 슬롯을 받고, plan 을 제출하고, 사람 (또는 권한 있는 다른 에이전트) 이 검토 / 승인하면, 일을 가져가서 자율적으로 진행한다. **mora-knode 는 LLM 을 호출하지 않으며 어떤 모델·SDK·키도 모른다** ([ADR-005](architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md)). 외부 에이전트가 어떤 도구로 만들어졌든 자유.

## 2. 대상 사용자
- **1차 타겟**: NilPop 오너 (ysh) + 외부 AI 에이전트들. ysh 가 자기 외부 도구 (Claude Code / Cursor / 자체 봇) 로 4~5개 agent identity 를 운영하며 mora-knode 를 dogfooding.
- **2차 타겟**: 5~50명 규모 매트릭스 SW 회사 (개발사 / 에이전시 / 스튜디오 / 컨설팅). 사람과 외부 AI 에이전트의 가동률을 같은 매트릭스에서 합산해 운영하는 조직.

## 3. 목표 / 성공 지표
- **MVP (M1)**: 프로젝트 / 태스크 / 마일스톤 CRUD + 간트 뷰 + 일정 변경 로깅 작동
- **외부 에이전트 협업 (M2)**: 외부 AI 에이전트 2~4 identity 가 mora-knode API 로 plan 제출 → 사람 승인 → 실행 → audit 까지 end-to-end 작동. 2주 이상 시뮬레이션 운용. 5개 프로젝트 / 50개 태스크 관리.
- **매트릭스 통합 (M2)**: 매트릭스 리소스 매니저에서 사람 + 에이전트 가동률 합산, 100% 초과 경보
- **성공 지표**: 매트릭스 시뮬레이션의 리소스 충돌 감소 (주관적). revision 횟수가 협업 품질 지표로 정량화 가능. 본인 사용 + AI 협업 실측

## 4. 범위

### In-scope (MVP ~ Phase 2)
- 프로젝트 / 태스크 / 마일스톤 CRUD
- 3단계 타임라인 시스템 (L1 Origin / L2 Current / L3 Real)
- 전방위 일정 로깅 (`ScheduleChangeLog`, ChangedBy = 사람 user-id 또는 agent identifier)
- 간트차트 뷰 (기본 바 렌더링)
- 매트릭스 리소스 매니저 — 통합 로드 뷰 (여러 프로젝트 가동률 합산), 100% 초과 에너지 경보
- **Agent Identity & API** ([ADR-004](architecture/ADR-004-agent-identity-and-api.md)) — `Resource.Kind=Agent`, 토큰 발급, RBAC, 매트릭스 슬롯
- **Plan 제출 / 검토 / 승인 게이트** ([ADR-002](architecture/ADR-002-manager-approval-gate.md)) — `AgentPlanHistory`, revision 메트릭
- **Work-queue API** ([ADR-004](architecture/ADR-004-agent-identity-and-api.md)) — 외부 에이전트가 자기 task pull
- Audit trail (모든 변경의 `ChangedBy`)

### Out-of-scope (이번엔 안 함)
- self-hosted + 라이선스 인증 (MVP 후 배포 단계)
- 성과 분석 / 점수 산출 (MVP 후 추가)
- SaaS 멀티 테넌시 (온프레미스 우선)
- **AI 에이전트 자체 실행 / LLM 호출 / Python orchestrator 내장** — mora-knode 는 외부 에이전트의 host 일 뿐 ([ADR-005](architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md))
- LLM 모델 선택 / SDK 채택 / 토큰 비용 측정 / 프롬프트 관리 — 외부 에이전트 자기 책임
- 외부 에이전트 자체 구현 — ysh 의 dogfooding 셋업은 [docs/dogfooding/agent-operations.md](dogfooding/agent-operations.md) 의 권장 패턴 (mora-knode 사양 아님)

## 5. 핵심 기능 (P0 → P2)

| 우선순위 | 기능 | 비고 |
| --- | --- | --- |
| P0 | 프로젝트/태스크 CRUD + 3단계 타임라인 | Mora Knode 의 타임라인 시스템 적용 |
| P0 | 간트차트 뷰 | 기본 바 렌더링 |
| P0 | 일정 변경 로깅 | 변경 전/후, 사유, ChangedBy 기록 |
| P0 | 매트릭스 리소스 매니저 | 통합 로드 뷰 + 에너지 경보. 사람 + 에이전트 합산. **처리 시점 = M2 (옵션 C 채택)** |
| P0 | Agent Identity & API | ADR-004. 토큰 / RBAC / Work-queue |
| P0 | Plan 게이트 | ADR-002. AgentPlanHistory + 검토 / 승인 워크플로우 |
| P1 | 마일스톤 관리 | |
| P1 | Flutter Agent 관리 화면 | identity 등록 / 토큰 발급 / RBAC 설정 UI |
| P2 | 성과 분석 (난이도 보정) | MVP 후 추가 |
| P2 | revision 메트릭 가시화 | 간트 위에 plan accuracy 트렌드 |

## 6. 기술 스택
- FE: Dart / Flutter Web — 데스크톱 사이즈 only ([architecture/ADR-008-flutter-web-desktop-only.md](architecture/ADR-008-flutter-web-desktop-only.md)). Windows native 제거. 모바일 / 앱스토어 / 반응형은 미래 별도 ADR (M5 이후 또는 데이터 페치 layer 안정화 후)
- BE: C# ASP.NET Core
- DB: MongoDB (JSON 기반 유연성)
- 배포: Docker Compose (Phase 2 이후) — backend + Flutter Web 정적 자산 서빙
- 인증/라이선스: self-hosted + license-client (Phase 3 추가)
- **외부 에이전트 도구**: 자유 (mora-knode 의 일부가 아님). ysh dogfooding 권장 셋업은 [agent-operations.md](dogfooding/agent-operations.md) 참고

## 7. 리스크
- "도구를 먼저 만든다" 함정 — 다른 프로젝트 밀림. 최소 기능 제한
- 간트차트 라이브러리 선택 (상용 라이선스 이슈)
- 스키마 과도 일반화 방지
- **카테고리 혼란 유혹** — "AI 자동화 추가" 압력에 흔들리지 말 것 ([ADR-005](architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md))

## 8. 마일스톤
- **M1 (2026-05-07)**: MVP — CRUD + 3단계 타임라인 + 일정 로깅 + 간트 뷰 (옵션 C: 매트릭스 매니저는 M2 로 이동)
- **M2 (2026-06-15)**: Agent Identity & API + Plan 게이트 + **매트릭스 리소스 매니저 (사람+Agent 합산, 처음부터 통합 설계)** + 외부 에이전트 dogfooding 시뮬레이션 (ysh 가 자기 도구로 2~4 에이전트 운영, 2주 시뮬레이션)
- **M3 (2026-08)**: 오픈소스 공개 (AGPL v3). ysh 솔로 dogfooding 메트릭 공개. partner 모집 안 함
- **M4 (2026-10)**: SSO + cloud hosted alpha
- **M5 (2026-12 ~ 2027-01)**: 정식 출시. **이 시점에 가격 / 비용 / Tier 모델 재검토** (지금은 미룸)

> 일정 재추정 근거: [research/2026-04-29-ai-agent-trends-fit-review.md §7](research/2026-04-29-ai-agent-trends-fit-review.md)

## 9. 관련 문서
- [architecture/ADR-002-manager-approval-gate.md](architecture/ADR-002-manager-approval-gate.md) — Plan 제출 / 검토 / 승인 게이트
- [architecture/ADR-004-agent-identity-and-api.md](architecture/ADR-004-agent-identity-and-api.md) — Agent Identity & API
- [architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md](architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md) — LLM 비차별 원칙
- [architecture/ADR-006-byoa-onboarding-ux.md](architecture/ADR-006-byoa-onboarding-ux.md) — BYOA 온보딩 UX (UI + 환경변수 generator)
- [architecture/ADR-007-short-disclaimer.md](architecture/ADR-007-short-disclaimer.md) — M3 외부 공개용 짧은 면책 (DISCLAIMER.md 원문, 정식 EULA / SLA 는 M5 이전)
- [architecture/ADR-008-flutter-web-desktop-only.md](architecture/ADR-008-flutter-web-desktop-only.md) — Flutter Web 데스크톱 only (Windows native 제거, 모바일/앱스토어 미래)
- [architecture/schema-integration-for-agents.md](architecture/schema-integration-for-agents.md) — 스키마 변경 PR 1~6
- [planning/TODO.md](planning/TODO.md) — 마일스톤별 작업
- [dogfooding/agent-operations.md](dogfooding/agent-operations.md) — ysh 외부 에이전트 운영 권장 가이드
- [research/2026-04-29-ai-agent-trends-fit-review.md](research/2026-04-29-ai-agent-trends-fit-review.md) — 시장 / 트렌드 / 사업 모델
