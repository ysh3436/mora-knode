# ADR-006: BYOA 온보딩 UX — UI 기반 Agent 관리 + 환경변수 자동 generator

- 상태: Accepted
- 날짜: 2026-04-29
- 연관: [ADR-004 (Agent Identity & API)](ADR-004-agent-identity-and-api.md), [ADR-005 (LLM 비차별 원칙)](ADR-005-mora-knode-does-not-orchestrate-llms.md), [ADR-008 (Flutter Web 데스크톱 only)](ADR-008-flutter-web-desktop-only.md), [schema-integration-for-agents.md](schema-integration-for-agents.md)

## Context

[ADR-004](ADR-004-agent-identity-and-api.md) 가 Agent Identity & API 사양 (식별자 / 토큰 / RBAC / work-queue) 을 정의했으나, *사용자 (운영자) 가 어떻게 셋업하는가* 의 UX 정책은 미정. [적합도 검토 §9.4](../research/2026-04-29-ai-agent-trends-fit-review.md) 의 **"BYOA 셋업 마찰 → 사용자 잃음"** 리스크의 직접 헤지.

목표: agent identity 등록부터 외부 도구 첫 polling 까지 **5분 안에**.

## Decision

### 1. Agent identity 등록 — UI 만

- mora-knode Flutter Web UI 의 *Agent 관리 화면* 에서 form 입력으로 등록
- CLI 또는 직접 API 호출 *공식 지원 안 함* (M5 까지)
- API endpoint 자체는 [Phase 1.5 PR 4](schema-integration-for-agents.md) 에 존재. 단 *문서 / 테스트 / 안정성 보증* 은 UI 만 책임

### 2. RBAC 프리셋 — 현행 유지

[ADR-004 §3](ADR-004-agent-identity-and-api.md) 의 5 프리셋 그대로:
- **Manager** / **Reviewer** / **Developer** / **QA** / **Human**
- custom RBAC = M4 이후 (enterprise 고객 fine-grained 요청 시)
- M5 까지는 5 프리셋 + 일부 toggle (action scope 의 개별 권한 on/off) 만

### 3. 환경변수 generator — UI 자동 생성

agent identity 등록 + 토큰 발급 후 UI 가 사용자에게 *복사 가능한* 셋업 자료를 자동 생성:

#### 3.1 환경변수 블록
UI 의 "셋업 가이드" 패널이 자동 생성:
```
MORA_KNODE_API_URL=http://localhost:5000
MORA_KNODE_AGENT_ID=<agent-resource-id>
MORA_KNODE_AGENT_TOKEN=<api-token>
```
실제 ID / 토큰이 채워진 상태로 한 클릭 복사 버튼.

#### 3.2 외부 도구별 셋업 가이드 (M2 출시 시 4 도구)

UI 의 도구 선택 dropdown:

| 도구 | 자동 생성 자료 |
|---|---|
| **Claude Code** | `.claude/agents/<role>.md` 템플릿 + 환경변수 입력 위치 |
| **Cursor** | `.cursorrules` 또는 settings.json 안내 |
| **자체 Python 봇** | `mora_client.py` 스니펫 + while loop 예시 |
| **curl** | work-queue / plan 제출 / 토큰 검증 curl 명령 예시 |

각 가이드는 *해당 agent identity 의 실제 토큰 / RBAC role* 이 자동 채워진 상태로 복사 가능.

#### 3.3 Layer 1 / Layer 2 분기 안내 (선택)

[agent-operations.md §8.2](../dogfooding/agent-operations.md) 의 2 layer 위임 패턴 사용자를 위해 UI 의 *고급* 토글:
- Layer 1 = 이 agent identity (mora-knode 와 통신)
- Layer 2 = 사용자가 자기 환경에 BYOA 도구 (Claude Code / Cursor) 별도 셋업

기본 비활성. 토글 ON 시 Layer 1 ↔ Layer 2 인계 코드 (subprocess / API / sub-agent) 예시 추가 표시.

### 4. UX 흐름 (5분 목표)

```
1. Agent 관리 화면 → "+ Agent 추가" 버튼 클릭
2. Form 입력:
   - 이름 (예: "manager-01")
   - 설명 (자유 텍스트)
   - RBAC 프리셋 선택 (Manager / Reviewer / Developer / QA)
   - 매트릭스 슬롯 (선택)
3. 등록 → 토큰 자동 발급 → "셋업 가이드" 패널 자동 표시
4. 셋업 가이드:
   - 환경변수 블록 (한 클릭 복사)
   - 외부 도구 선택 dropdown (Claude Code / Cursor / Python / curl)
   - 선택 시 해당 도구의 셋업 코드 자동 생성 (실제 token 채워짐)
5. 사용자가 자기 외부 도구에 붙여넣기 → 첫 polling 시작
6. mora-knode UI 가 "처음 work-queue polling 감지됨" 알림 → 검증 완료
```

### 5. 토큰 회전 / 회수

같은 Agent 관리 화면에서:
- **토큰 회전** 버튼 → 새 토큰 발급 + 이전 토큰 무효화 + 새 셋업 가이드 표시
- **토큰 회수** 버튼 → 즉시 무효화 (agent identity 보존, 다시 발급 가능)

API 측은 [ADR-004 §2](ADR-004-agent-identity-and-api.md) 의 `POST/DELETE /api/agents/{id}/tokens` 그대로.

## Rationale

### 왜 UI 만 (CLI 안 함)
- **1인 회사 부담 최소화** — CLI 별도 작성 / docs / 테스트 부담 0
- **5분 셋업 narrative 와 정합** — UI 가 가이드 역할
- **PM 도구 카테고리 표준** — Linear / Jira / Plane / monday.com 모두 UI 우선
- API endpoint 자체는 존재 — 사용자가 자기 책임으로 직접 호출 가능 (단 mora-knode 가 *지원* 하진 않음)

### 왜 RBAC 프리셋 현행 유지
- 5 프리셋이 외부 에이전트 시나리오 대부분 커버 (Manager / Developer / Reviewer / QA / Human)
- custom RBAC = enterprise 의 fine-grained 요구 사항 (M4 이후)
- 1 인 회사 단계에서 custom 추가 시 구현 / 테스트 / docs 부담 폭증
- toggle (action scope 의 개별 on/off) 만으로 대부분 변형 커버 가능

### 왜 환경변수 자동 generator
- **BYOA 의 가장 큰 장벽 = 셋업 마찰** ([적합도 §9.4](../research/2026-04-29-ai-agent-trends-fit-review.md))
- 사용자가 환경변수 / 외부 도구 설정 *직접 작성* = 5 분 안에 못 끝남
- 자동 생성 = "복사 → 붙여넣기 → 끝"
- 외부 도구별 코드 자동 채움 = 사용자의 *환경 차이* 를 mora-knode 가 흡수

## Consequences

### 긍정적
- 셋업 5분 narrative 가능 → BYOA 진입장벽 1차 헤지 ([적합도 §9.4](../research/2026-04-29-ai-agent-trends-fit-review.md))
- 1인 회사 부담 최소 (CLI 안 만듦)
- M2 dogfooding 시작 시 ysh 본인이 즉시 검증 가능
- M3 공개 시 narrative 강화 — "5분 안에 자기 AI 에이전트와 mora-knode 연결"

### 부정적
- CLI 사용자 (DevOps / 자동화 지향) 가 약간 어색 — 1차 타겟 사용자 (5~50명 SW 회사) 는 UI 로 충분
- 환경변수 generator 의 외부 도구별 코드 = M2 까지 4 도구 (Claude Code / Cursor / Python / curl) 만. 다른 도구 사용자는 docs link out
- UI 가 변경 / 다운 시 신규 agent 등록 막힘 (단 기존 agent 의 polling 은 영향 없음)

## Out of Scope

- **CLI 도구** — M5 이후 enterprise 또는 power user 요청 시 검토
- **custom RBAC** — M4 이후
- **토큰 자동 만료 정책** (cron 회전 등) — Phase 2 확장 이후
- **SSO 통합 토큰** — M4 와 함께
- **Web Push / 알림** — 모바일 ADR-010 과 함께 (M5 이후)
- **Layer 2 도구 자동 셋업** — Layer 2 는 사용자 BYOA 영역 ([ADR-005](ADR-005-mora-knode-does-not-orchestrate-llms.md)). UI 는 *안내* 만, *자동 셋업* 안 함

## 재검토 조건

- M3 공개 후 60일에 "CLI 가 필요하다" 요구가 30%+ 누적 시 CLI 추가 검토
- enterprise 고객이 audit log SIEM 연동을 위해 token API 직접 호출 요구 시
- 외부 도구 환경 (Claude Code / Cursor 등) 의 변화로 환경변수 generator 의 효율이 낮아질 때
- 사용자 셋업 시간 측정 결과 평균 10분+ 이면 UI 흐름 재설계

## 관련 문서

- [ADR-004 (Agent Identity & API)](ADR-004-agent-identity-and-api.md) — 토큰 / RBAC / API 사양
- [ADR-005 (LLM 비차별 원칙)](ADR-005-mora-knode-does-not-orchestrate-llms.md) — Layer 2 가 mora-knode out-of-scope 인 이유
- [ADR-008 (Flutter Web 데스크톱 only)](ADR-008-flutter-web-desktop-only.md) — UI 가 데스크톱 사이즈 only
- [schema-integration-for-agents.md](schema-integration-for-agents.md) — PR 4 (`AgentEndpoints`) / PR 5 (Flutter Agent 관리 화면) 의 본 ADR 적용
- [../dogfooding/agent-operations.md §8](../dogfooding/agent-operations.md) — 8.1 단순 / 8.2 2 layer 셋업 패턴
- [../research/2026-04-29-ai-agent-trends-fit-review.md §9.4](../research/2026-04-29-ai-agent-trends-fit-review.md) — BYOA 셋업 마찰 리스크
