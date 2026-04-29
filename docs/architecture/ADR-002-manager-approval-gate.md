# ADR-002: Plan 제출 / 검토 / 승인 게이트

- 상태: Accepted (2026-04-29 일반화 재작성 — 옛 "Manager 승인 게이트" 를 외부 에이전트 host 모델로 재해석)
- 날짜: 2026-04-23 (최초), 2026-04-29 (재작성)
- 연관: [ADR-004 (Agent Identity & API)](ADR-004-agent-identity-and-api.md), [ADR-005 (LLM 비차별 원칙)](ADR-005-mora-knode-does-not-orchestrate-llms.md), [schema-integration-for-agents.md](schema-integration-for-agents.md)

## Context

mora-knode 는 외부 AI 에이전트의 협업 host 다 ([ADR-004](ADR-004-agent-identity-and-api.md)). 외부 에이전트 (혹은 사람) 가 task 에 대한 plan (분해, acceptance criteria, 리스크) 을 mora-knode 에 제출하면, plan 의 품질이 다운스트림 에이전트의 실행 품질 상한을 결정한다.

Plan 제출 → 자동 실행 으로 가는 설계는 잘못된 plan 의 비용 (Developer 가 잘못된 코드를 작성하고 되돌리는 시간 + 토큰) 이 plan 단계의 수정 비용보다 훨씬 크다. 따라서 plan 의 review/approval 단계가 mora-knode 의 1급 사양으로 존재해야 한다.

옛 ADR-002 는 "Manager 에이전트 → Developer 에이전트" 라는 mora-knode 내장 실행 모델을 가정했다. 본 재작성은 외부 에이전트 host 모델에 맞게 일반화한다.

## Decision

**mora-knode 는 plan 제출 / 검토 / 승인 게이트를 자체 사양으로 제공한다.** 외부 에이전트 (혹은 사람) 가 plan 을 제출하면, mora-knode 가 review queue 에 넣고, 리뷰어 (사람 또는 다른 에이전트) 의 approve / revise / reject 결정을 통과해야만 다운스트림 에이전트가 실행 단계로 진입한다.

### 1. 상태 분리
태스크 상태에 `PlanDrafting → PlanReview → PlanApproved` 3개 단계를 도입해 "기획 단계" 를 실행 단계와 명시적으로 분리.

### 2. 버전 히스토리 보존
plan 의 모든 revision 을 `AgentPlanHistory` 컬렉션에 저장. 이전 버전과의 diff 를 리뷰어가 볼 수 있어야 함. `CreatedBy` 는 임의 agent identifier 또는 사람 user id (외부 에이전트가 *어떤* LLM 인지는 mora-knode 의 관심사 아님).

### 3. 세 가지 응답
approve / revise (피드백 포함) / reject. revise 는 반복 가능.

### 4. 경계의 코드화
다운스트림 에이전트 (Developer / QA 등) 가 work-queue 에서 task 를 pull 할 때 mora-knode 는 `task.Status == PlanApproved` 어설션. 이 조건이 위반되면 시스템 에러 (silent fall-through 금지). 외부 에이전트가 직접 status 를 우회 변경하는 것은 RBAC 로 차단 ([ADR-004](ADR-004-agent-identity-and-api.md)).

### 5. revision 상한
한 task 당 revision 5회 초과 시 mora-knode 가 "기획 난항" 경고 발생. 사용자가 직접 plan 을 작성하거나 task 를 쪼개도록 안내. 무한 루프 방지.

### 6. 권한 모델
- **Plan 제출** (`POST /api/agents/plans/{taskId}/versions`) — `submit plan` 권한 필요 (Manager / QA 프리셋)
- **Plan approve** (`POST /api/agents/plans/{taskId}/approve`) — **기본적으로 사람만**. 다른 에이전트에게 부여는 운영자 명시 결정 (ADR-004 의 RBAC)
- **Plan revise / reject** — Plan approve 와 같은 권한 풀

### 7. 간트 반영
`PlanReview` 상태 task 는 mora-knode 간트 뷰에 별도 색/아이콘으로 "검토 대기" 가시화 (Flutter 반영은 Phase 2 이후).

### 8. 권장 CLI (외부 도구 측)
mora-knode 는 REST API 만 제공. 외부 도구 (Claude Code skill / 자체 CLI / Flutter UI) 가 다음 패턴으로 호출 권장:
```
mora plans pending                 # 검토 대기 목록
mora plans show <task_id>          # plan 내용 + diff
mora plans approve <task_id>
mora plans revise <task_id> -m "피드백"
mora plans reject <task_id>
```
([agent-operations.md](../dogfooding/agent-operations.md) 의 권장 셋업)

## Rationale

### 왜 자동 진행이 아닌 승인 게이트인가
- **실패 확산 차단**: 잘못 분해된 task 는 다운스트림 전체를 오염. 게이트가 가장 저비용의 차단 지점.
- **외부 에이전트 학습 곡선**: 초기엔 외부 에이전트의 plan 프롬프트가 수렴되지 않은 상태. 사용자 피드백이 외부 도구의 프롬프트 튜닝의 직접 데이터. mora-knode 의 `AgentPlanHistory.UserFeedback` 가 이 데이터를 보존.
- **dogfooding 품질**: PRD 의 "계획과 실행 사이의 리듬" 분석 목표와 정합. 기획 단계 revision 횟수 자체가 조직 예측력 지표.
- **비용 절감 (외부 에이전트 측)**: 잘못된 plan → Developer 가 코드 작성 → 되돌림 의 비용은 plan 단계 수정 비용보다 훨씬 큼.

### 왜 한 번 승인이 아닌 반복 루프인가
- 한 번의 OK/NO 는 "덜 나쁜 plan" 통과 또는 "사소한 이슈로 reject" 강제
- revise + 피드백 루프 = 사용자와 외부 에이전트가 *공동으로* plan 을 완성하는 과정
- 무한 반복 방지를 위해 상한 (5회) 과 "기획 난항" 이탈 경로

### 왜 PlanApproved 가 별도 상태인가
- 기존 InProgress 로 통합하면 work-queue pull 시점이 불명확
- 매트릭스 리소스 매니저 관점에서 "승인됐으나 착수 전" task 식별이 병목 분석에 필수

### 왜 approve 권한이 기본적으로 사람만인가
- 다중 에이전트가 서로의 plan 을 자동 approve 하는 echo chamber 방지
- audit / 책임 소재의 마지막 사람 결정 지점 보장
- 운영자가 명시적으로 다른 에이전트에게 부여 가능 (예: 신뢰 검증된 Reviewer 에이전트) — 단 그 결정은 운영자 책임

## Consequences

### 긍정적
- 사람이 외부 에이전트 시스템의 상위 제어권을 확실히 쥠. 자율성은 제한되지만 **신뢰 가능한 자동화**
- `AgentPlanHistory` 가 누적되며 외부 에이전트의 프롬프트 튜닝 데이터로 활용 가능
- mora-knode 의 핵심 차별점 ("revision 메트릭 = 협업 품질 지표") 의 데이터 소스
- enterprise 도입 시 audit / 책임 분담 / SLA 의 기반

### 부정적
- 완전 자율 실행보다 느림. 사람 승인이 병목. → 해결 후보:
  - Phase 2+ 에서 위험도 낮은 task 유형에 "auto-approve after N seconds" 옵션 (사전 정의 규칙 만족 시만)
  - Slack/이메일 알림 (Phase 2)
- 외부 에이전트가 일을 했는데 사람이 자리를 비우면 대기 → 알림 시스템 필수
- CLI 기반 승인은 Flutter UI 까지 가야 매니저가 모바일에서 처리 가능

## 재검토 조건
- 외부 에이전트의 plan 승인률이 3회 연속 98% 이상인 *task 유형* 이 발견되면 해당 유형에 한해 auto-approve 규칙 도입 검토
- revision 횟수 상한 (5회) 은 실측 데이터로 조정
- approve 권한을 다른 에이전트에게 부여한 운영자의 사고 사례 발생 시 권한 모델 재검토

## 관련 문서
- [ADR-004 (Agent Identity & API)](ADR-004-agent-identity-and-api.md) — 권한 / 토큰 / RBAC
- [ADR-005 (LLM 비차별 원칙)](ADR-005-mora-knode-does-not-orchestrate-llms.md) — mora-knode 가 plan 을 *만들지* 않는 이유
- [schema-integration-for-agents.md](schema-integration-for-agents.md) — `AgentPlanHistory` 스키마 / API
- [../dogfooding/agent-operations.md](../dogfooding/agent-operations.md) — 외부 에이전트 운영 권장 패턴
