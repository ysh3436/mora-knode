# ADR-004: Agent Identity & API — 외부 AI 에이전트의 1급 시민화

- 상태: Accepted
- 날짜: 2026-04-29
- 연관: [ADR-002 (Plan 게이트)](ADR-002-manager-approval-gate.md), [ADR-005 (LLM 비차별 원칙)](ADR-005-mora-knode-does-not-orchestrate-llms.md), [schema-integration-for-agents.md](schema-integration-for-agents.md)

## Context

mora-knode 는 매트릭스 PM 플랫폼이며, 외부 AI 에이전트가 사람과 동등한 1급 시민으로 일한다. 다음 질문에 답해야 한다:

- 외부 에이전트가 mora-knode 를 어떻게 식별·인증하는가?
- 사람과 에이전트가 매트릭스 가동률에서 어떻게 합산되는가?
- 어떤 권한 모델로 task / plan / 변경을 통제하는가?
- 어떤 API 표면으로 외부 에이전트가 협업하는가?

기존 가정 (Superseded 된 옛 ADR-001/003 + agent-system-v2.md) 은 mora-knode 가 Python orchestrator + Claude Agent SDK 로 에이전트를 *내장 실행* 한다는 것이었으나, **mora-knode 는 외부 에이전트의 host 일 뿐 LLM 을 호출하지 않는다** (ADR-005). 따라서 본 ADR 은 외부 에이전트가 들어와서 일하기 위한 사양을 정의한다.

## Decision

mora-knode 는 다음 5개를 **자체 사양** 으로 제공한다. 외부 에이전트가 어떤 LLM·도구·SDK로 만들어졌는지는 mora-knode 의 관심사가 아니다.

### 1. Agent Identity (식별자)

`Resource` 도메인을 재활용. `Resource.Kind ∈ {Human, Agent}` enum 으로 사람과 에이전트를 동등 1급 시민으로.

```csharp
// src/backend/Domain/Resource.cs
public ResourceKind Kind { get; set; } = ResourceKind.Human;
public string? AgentDescription { get; set; }  // 자유 텍스트, 운영자가 식별 용도
```

> 옛 `AgentModel` 필드 (예: "claude-opus-4-7") 는 ADR-005 의 비차별 원칙에 따라 *제거 또는 선택적 메타데이터로 격하*. mora-knode 의 식별자는 LLM 모델이 아니라 agent identifier 자체.

### 2. API 토큰 발급

mora-knode 가 발급, 외부 도구에 입력. 한 agent identity 당 1개 토큰. 회전 가능.

API:
```
POST   /api/agents/{agentId}/tokens         # 신규 토큰 발급 (이전 토큰 무효화)
DELETE /api/agents/{agentId}/tokens         # 즉시 회수
```

요청 헤더 (외부 에이전트 → mora-knode):
```
Authorization: Bearer <agent-token>
X-Agent-Id: <agent-resource-id>             # 검증 redundancy (token 와 매칭 필수)
```

mora-knode 는 모든 변경의 `ChangedBy` 에 검증된 agent id 를 자동 기록.

### 3. RBAC (권한 모델)

각 agent identity 가 가진 권한:
- **project scope**: 어떤 프로젝트에 접근 가능한가 (project id list)
- **action scope**: pull task / submit plan / update status / approve plan / merge PR — 행동 단위 토글
- **role hint**: `Manager` / `Developer` / `Reviewer` / `QA` — 자유 텍스트, work-queue 필터링용 hint (강제 권한 아님)

기본 권한 프리셋 (운영자 편의):
| Preset | pull task | submit plan | update status | approve plan | merge PR |
|---|:---:|:---:|:---:|:---:|:---:|
| Manager | ✓ | ✓ | △ (PlanDrafting↔PlanReview) | ✗ | ✗ |
| Reviewer | ✓ | ✗ | ✗ | ✓ | ✗ |
| Developer | ✓ | ✗ | ✓ (InProgress↔Done) | ✗ | ✗ |
| QA | ✓ | ✓ (수정 task 신규 제출) | ✓ | ✗ | ✗ |
| Human (사용자) | ✓ | ✓ | ✓ | ✓ | ✓ |

`approve plan` 권한은 기본적으로 사람만 갖는다. 다른 agent 에게 부여는 운영자 명시 결정 — ADR-002 의 안전 원칙 위반 가능성 있음.

### 4. 매트릭스 슬롯

`Resource.Kind=Agent` 도 `Assignment` 의 대상이 되며, 가동률 합산에 참여.

mora-knode 의 매트릭스 리소스 매니저는 사람 / 에이전트 구분 없이 합산:
- "이 매트릭스의 총 가동률은 사람 3명 + 에이전트 4 = 7 슬롯 기준 X%"
- 100% 초과 경보는 사람이든 에이전트든 동일 적용

### 5. Work-queue API

외부 에이전트가 자기에게 할당된 작업을 polling 으로 가져오는 표준 표면.

```
GET /api/agents/work-queue                  # 자기 (token 의 agent id) 의 pending work
GET /api/agents/work-queue?status=PlanApproved&role=Developer
                                            # role 필터는 task.AssignedRoleHint 와 매칭
POST /api/agents/work-queue/{taskId}/claim  # lock 획득 (다른 agent 가 동시에 잡지 못하도록)
                                            # 성공 시 Status → InProgress, ChangedBy=<agent-id>
POST /api/agents/work-queue/{taskId}/release # lock 반환 (실패 / 포기)
```

Stage 0: polling 주기 외부 에이전트 자유 (권장 2~5초).
Stage 1+: MongoDB Change Streams 기반 push 옵션 검토 (외부 에이전트 부담 완화).

## Rationale

### 왜 mora-knode 가 LLM 을 호출하지 않는가
[ADR-005](ADR-005-mora-knode-does-not-orchestrate-llms.md) 참고. 카테고리 명확성, 외부 에이전트 다양성, 운영자가 자기 도구 자유 선택 보장.

### 왜 Agent Identity 를 Resource 에 통합하는가
사람과 에이전트가 매트릭스 가동률에서 같은 차원으로 합산되어야 mora-knode 의 핵심 가치 ("사람 + AI 혼합 매트릭스") 가 성립. 별도 `AgentIdentity` 테이블을 만들면 매트릭스 매니저 로직이 두 source 를 union 해야 하는 복잡도 발생.

### 왜 RBAC 가 필요한가
- audit trail 신뢰성: 누가 무엇을 했는지의 *누가* 가 검증돼야 dogfooding revision 메트릭이 의미 있음
- 다중 에이전트 동시 운영 시 사고 방지: Developer 에이전트가 plan 을 임의로 approve 하는 등의 권한 침범 차단
- 외부 판매 시 enterprise 진입 조건: SOC2 / SAML 결합 가능

### 왜 work-queue 를 별도 API 로 두는가
기존 `GET /api/tasks?...` 로 충분할 수 있으나:
- agent-specific 필터 (자기 token 의 agent 에게 할당된 것만)
- claim / release 로 동시성 제어
- audit 와 결합 (work-queue 호출도 ChangedBy 로 기록)

→ 별도 표면이 명확하고, 향후 push 모드 전환 (Change Streams) 시에도 영향 범위 작음.

## Consequences

### 긍정적
- 외부 에이전트는 어떤 도구로 만들어졌든 mora-knode 와 협업 가능 (Claude Code / Cursor / 자체 봇 / 미래의 도구)
- 사람과 에이전트가 같은 매트릭스에서 합산 — mora-knode 의 5-feature 차별점 유지
- audit / RBAC 로 enterprise 진입 조건 (SSO 통합 시 즉시 작동) 충족
- mora-knode 가 LLM 가격·컴플라이언스 리스크에서 자유

### 부정적
- 외부 에이전트의 LLM 비용 / quota 는 mora-knode 가 가시화하지 못함 → 운영자가 외부 도구 콘솔에서 따로 봐야 함 (단, 외부 에이전트가 자기 메트릭을 `AgentRun` 으로 제출하면 통합 가시화 가능 — optional)
- onboarding 마찰: 사용자가 token 발급 / RBAC 설정 / 외부 도구에 입력하는 단계 필요 → Stage 1 의 UX 우선순위

## 재검토 조건
- 외부 에이전트가 mora-knode 안에 *존재* 하지 않고 *대신 호출되어야 한다* 는 강력한 사용자 피드백이 누적될 때 (= "왜 mora-knode 안에서 직접 plan 이 만들어지지 않나?" 가 빈번한 요청이 될 때)
- 다중 외부 에이전트가 같은 task 를 race 로 잡는 사고가 빈번할 때 (work-queue API 의 lock 전략 강화)
- enterprise 고객이 RBAC 의 더 fine-grained 모델 요구할 때

## Out of Scope (이 ADR 에서 다루지 않음)
- LLM 토큰 비용 측정 / 과금 — ADR-005 (mora-knode 는 모름)
- Plan 의 표준 JSON 구조 — [agent-operations.md](../dogfooding/agent-operations.md) (운영 가이드, 강제 아님)
- 모델 선택 / SDK 선택 — agent-operations.md (운영 가이드, 강제 아님)
