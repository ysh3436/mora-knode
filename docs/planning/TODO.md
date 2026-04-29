# mora-knode TODO

- slug: mora-knode
- 오너: ysh
- 최종 수정: 2026-04-29 (외부 에이전트 host 모델로 재구성)
- 관련: [../prd.md](../prd.md), [../architecture/ADR-002-manager-approval-gate.md](../architecture/ADR-002-manager-approval-gate.md), [../architecture/ADR-004-agent-identity-and-api.md](../architecture/ADR-004-agent-identity-and-api.md), [../architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md](../architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md)

## Phase별 큰 그림

### Phase 0: 준비 (완료됨)
- [x] PRD 검토 및 체크리스트
- [x] `projects/mora-knode/` 생성 및 git init
- [x] 프로젝트 CLAUDE.md 작성
- [x] 기본 도메인 모델 초기 구현 (Project, TaskItem, Timeline L1/L2/L3, Resource, Assignment, Milestone, ScheduleChangeLog)

> **Flutter 결정 (2026-04-29, [ADR-008](../architecture/ADR-008-flutter-web-desktop-only.md))**: 모든 Flutter 작업은 Flutter Web 데스크톱 사이즈 only. Windows native 제거됨. 모바일 / 앱스토어 / 반응형 / Task 코멘트는 미래 별도 ADR.

### Phase 1: MVP — M1 (2026-04-23 ~ 2026-05-07, 옵션 C 채택)
- [ ] 프로젝트 CRUD API 완성 (ASP.NET Core + MongoDB)
- [ ] 태스크 CRUD API (3단계 타임라인, ParentTaskId)
- [ ] 일정 변경 로깅 (`ScheduleChangeLog` 자동 기록)
- [ ] 간트차트 뷰 UI (Flutter 기본 바 렌더링)
- [ ] 마일스톤 관리 (P1, 시간 되면)
- [x] **LICENSE 파일 commit** — AGPL v3 적용 완료 (2026-04-29, commit 247ef51)
- ~~매트릭스 리소스 매니저~~ → **M2 로 이동** (옵션 C: 외부 에이전트 합산을 처음부터 통합 설계)

### Phase 1.5: 외부 에이전트 host 사양 구현 (M1→M2 사이, 2026-05-08 ~ 2026-05-21)
M1 완성 직후. 상세: [../architecture/schema-integration-for-agents.md](../architecture/schema-integration-for-agents.md)

- [ ] **PR 1**: Enum 확장
  - `TaskStatus`: `PlanDrafting, PlanReview, PlanApproved, Failed, Cancelled` 5개 추가
  - `ResourceKind { Human, Agent }` 신설
  - 파일: `src/backend/Domain/Enums.cs`
  - 기존 4개 enum 값 순서/정수 매핑 유지 회귀 테스트
- [ ] **PR 2**: TaskItem / Resource 필드 추가
  - `TaskItem`: `AcceptanceCriteria`, `Git`, `RetryCount`, `LastError`, `AssignedRoleHint`
  - 신규 value type `GitInfo`
  - `Resource`: `Kind`, `AgentDescription` (옛 `AgentModel` 도입 안 함 — ADR-005)
  - MongoDB 누락 필드 null 직렬화 확인
- [ ] **PR 3**: 신규 도메인 + Repository
  - `AgentPlanHistory` (+ `PlanStatus` enum, `ApprovedBy` 포함)
  - `AgentRun` (Token/Cost 모두 optional — ADR-005)
  - `MongoContext` 컬렉션 핸들 추가
  - `AgentPlanRepository`, `AgentRunRepository` 구현
  - 인덱스: `agentPlans {taskId:1, version:-1}`, `agentRuns {taskId:1, startedAt:-1}`, `agentRuns {agentId:1, startedAt:-1}`
- [ ] **PR 4**: `AgentEndpoints` 신설 + Program.cs 등록
  - Agent identity / 토큰 / RBAC: `/api/agents`, `/api/agents/{id}/tokens`, `/api/agents/{id}/permissions`
  - Plan 게이트: `/api/agents/plans/pending|{taskId}|approve|revise|reject|versions`
  - Work-queue: `/api/agents/work-queue`, `/api/agents/work-queue/{id}/claim|release`
  - 실행 메트릭 (optional): `/api/agents/runs`
  - Bearer 토큰 + X-Agent-Id 헤더 검증 (M1 단계는 placeholder, M2 에서 실제 검증)
  - 수동 curl 테스트 체크리스트
- [ ] **(검토 항목) MCP 서버 스캐폴딩** (적합도 검토 P0-1) — `tools/mora-knode-mcp/` 또는 `src/mcp-server/` 위치 결정. PR 4 의 API 표면 안정 후

### Phase 2: 외부 에이전트 dogfooding 시뮬레이션 — M2 (2026-05-22 ~ 2026-06-15)
**mora-knode 안에 외부 에이전트 코드를 만들지 않는다** ([ADR-005](../architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md)). ysh 가 자기 외부 도구 (Claude Code / Cursor / 자체 봇) 로 에이전트를 운영하며 mora-knode API 를 사용. 권장 셋업은 [../dogfooding/agent-operations.md](../dogfooding/agent-operations.md).

- [ ] **매트릭스 리소스 매니저 (옵션 C 로 M1 에서 이동)** — 가동률 합산 (사람 + `Resource.Kind=Agent`), 100% 경보, Flutter UI. Phase 1.5 PR 2 (Resource.Kind 추가) 직후
- [ ] mora-knode 에 4개 agent identity 등록: 예 `manager-01`, `developer-01`, `researcher-01`, `qa-01`
- [ ] 각 identity 의 API 토큰 발급 + RBAC 설정 (Manager 프리셋 / Developer 프리셋 / 등)
- [ ] ysh 의 외부 도구 (예: Claude Code) 에 토큰 입력 + sub-agent 정의 (`.claude/agents/manager.md` 등)
- [ ] 검증 시나리오: task 1개 end-to-end
  - 외부 Manager 에이전트가 plan 제출 → mora-knode `Status=PlanReview`
  - ysh 가 plan 검토 → revise 1회 → approve → `Status=PlanApproved`
  - 외부 Developer 에이전트가 work-queue claim → 코드 작성 / PR → ysh 머지
  - 간트 / audit / revision 메트릭 확인
- [ ] 2주 시뮬레이션 운용 (5개 프로젝트 / 50개 태스크 목표)
- [ ] 시뮬레이션 안정화 (3회 연속 성공)

### Phase 2 확장 (Stage 1, M2 이후)
- [ ] 적합도 검토 P0~P1 채택 결정 — [../research/2026-04-29-ai-agent-trends-fit-review.md](../research/2026-04-29-ai-agent-trends-fit-review.md) §8
  - MCP 서버 스캐폴딩 (P0-1)
  - 워크스페이스 .claude 공통 skill (P0-2)
  - Conventional Commit 검증 hook (P0-3)
  - Manager 승인 게이트 UI 명시화 / PlanReview 큐 (P1-5)
  - revision 횟수 가시화 (P1-6)
  - Context Engine 최소 버전 (P1-7)
- [ ] **PR 5 (Flutter)**:
  - 간트 `PlanReview` 배지
  - 태스크 상세 "Plan History" 탭 + diff + approve/revise/reject 버튼
  - "Runs" 탭 (선택적 토큰/비용 표시)
  - 매트릭스 리소스 매니저 에이전트 아이콘
  - **Agent 관리 화면** ([ADR-006](../architecture/ADR-006-byoa-onboarding-ux.md)) — UI form 등록 / 토큰 발급 / RBAC 5 프리셋 / 환경변수 자동 generator (Claude Code / Cursor / Python / curl) / 5분 셋업 UX 목표
- [ ] Human-in-the-loop 알림 (Slack / 이메일)
- [ ] `docker/` 디렉터리 신설 (backend.Dockerfile, docker-compose.yml — orchestrator Dockerfile 없음, ADR-005)
- [ ] `docker compose up` 으로 mongo + backend end-to-end 환경 검증

### Phase 3: 오픈소스 공개 (M3, 2026-08 이후) — partner 없는 단독 공개
- [ ] AGPL v3 적용 + LICENSE / CONTRIBUTING.md / ROADMAP.md (non-goals 포함, ADR-005 강조)
- [ ] README (영어 우선) + 3개월 dogfooding 메트릭 공개
- [ ] 1인 사례 시연 영상 1분 (한 사람이 4 에이전트와 매트릭스 운영)
- [ ] Public 전환 + 유통 (HN Show HN, Indie Hackers, r/selfhosted, X)
- [ ] 외부 에이전트 1차 issue triage (메인테이너 부담 통제)
- [ ] M3 공개 후 60일 자동 점검 — 이슈 / PR 폭증 시 즉시 대응 (적합도 검토 §9.5)

### Phase 4: cloud alpha (M4, 2026-10 이후)
- [ ] SSO (SAML / OIDC) 통합
- [ ] cloud hosted alpha
- [ ] PR 6 (선택): Push 모드 (Change Streams 기반 work-queue stream)
- [ ] 데이터 마이그레이션 어댑터 (Jira / Notion / Linear import) — ADR-009 결정 시

### Phase 5: 정식 출시 (M5, 2026-12 ~ 2027-01)
- [ ] **가격 / 비용 / Tier 모델 재검토** (적합도 검토 §5.1) — GitHub 별 / 사용자 피드백 / 외부 변수 보고 결정
- [ ] license-client 통합 (Enterprise self-hosted Pro) — 가격 결정 후
- [ ] Team / Business tier cloud 출시 — 가격 결정 후

## 테스트 / 운영 공통 태스크
- [ ] 단위 테스트 (C# xUnit, Flutter widget test)
- [ ] 통합 테스트 (CRUD + 간트 + Agent API)
- [ ] 외부 에이전트 시뮬레이션 회귀 (Phase 2 이후, 일일 자동)

## 리스크 및 조정 원칙
- **도구 함정 방지**: mora-knode 본 기능이 밀리면 외부 에이전트 dogfooding 은 뒤로 미룸 (PRD §7)
- **카테고리 흐림 방지**: "AI 자동화 추가" 유혹 시 ADR-005 재확인
- **Lean 유지**: Phase 2 까지는 외부 에이전트 셋업도 단순. 복잡 인프라 (Docker / Redis / push 모드) 는 실제 병목 확인 후
- **M1 기간에는 스키마 통합 PR 손대지 않음**: 기본 CRUD 안정화가 선결 조건
- 매주 dogfooding 우선순위 점검

## 관련 문서
- [../prd.md](../prd.md) — PRD
- [../architecture/ADR-002-manager-approval-gate.md](../architecture/ADR-002-manager-approval-gate.md) — Plan 게이트
- [../architecture/ADR-004-agent-identity-and-api.md](../architecture/ADR-004-agent-identity-and-api.md) — Agent Identity & API
- [../architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md](../architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md) — LLM 비차별 원칙
- [../architecture/schema-integration-for-agents.md](../architecture/schema-integration-for-agents.md) — 스키마 PR 계획
- [../dogfooding/agent-operations.md](../dogfooding/agent-operations.md) — 외부 에이전트 운영 권장
- [../research/2026-04-29-ai-agent-trends-fit-review.md](../research/2026-04-29-ai-agent-trends-fit-review.md) — 시장 / 트렌드 / 사업 모델
