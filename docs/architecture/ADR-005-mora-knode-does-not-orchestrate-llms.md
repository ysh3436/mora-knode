# ADR-005: mora-knode 는 LLM 을 오케스트레이션하지 않는다

- 상태: Accepted (LLM 비오케스트레이션 결정 자체는 유효). 단 본문의 "AGPL + open-core 정합" 언급은 작성 시점 (2026-04-29) 의 사업 모델 가설이며, **2026-05-06 라이센스 모델이 All Rights Reserved 로 변경되면서 이 부분의 전제는 더 이상 유효하지 않음**. 본 ADR 의 핵심 결정 (LLM 호출 / 모델 / SDK / 키 비차별) 은 라이센스와 무관하므로 그대로 유효
- 날짜: 2026-04-29
- 연관: [ADR-004 (Agent Identity & API)](ADR-004-agent-identity-and-api.md), [ADR-002 (Plan 게이트)](ADR-002-manager-approval-gate.md)

## Context

mora-knode 는 매트릭스 PM 플랫폼이다. 외부 AI 에이전트가 1급 시민으로 일하는 host 이지 ([ADR-004](ADR-004-agent-identity-and-api.md)), AI 에이전트 자체를 만들거나 실행하는 도구가 아니다.

기존 검토 일부는 mora-knode 가 Claude Agent SDK 로 Manager/Developer 를 직접 실행하는 방향 (옛 agent-system-v2.md, 옛 ADR-001/003 — 모두 Superseded), 또는 BYOK 방식으로 mora-knode 가 사용자 LLM 키를 받아 호출 대행하는 방향 (적합도 검토 1차안) 을 가정했다. 본 ADR 은 이 가정들을 명시적으로 거부한다.

## Decision

**mora-knode 는 다음을 자기 책임으로 갖지 않는다:**

1. LLM API 호출 (Anthropic / OpenAI / Google / 어느 provider 든)
2. LLM API 키의 보관 / 중계 / 사용
3. 모델 선택 (Opus / Sonnet / Haiku / GPT / Gemini 등)
4. SDK 채택 (Claude Agent SDK / OpenAI Agents SDK / LangGraph / 등)
5. 토큰 비용의 측정 / 과금 / 한도 정책 / 자동 중단
6. 프롬프트 / 시스템 메시지 / context window 관리

이 모든 책임은 **외부 에이전트 측** (사용자가 운영하는 Claude Code / Cursor / 자체 봇 / 임의 도구) 에 있다.

mora-knode 가 하는 일:
- 외부 에이전트의 식별자 / 토큰 / 권한 발급 (ADR-004)
- task / plan / approval / audit / 매트릭스 / 간트 / 마일스톤 데이터 보존 및 API
- 외부 에이전트가 *선택적으로 제출하는* 실행 메트릭 (`AgentRun` 의 `InputTokens, OutputTokens, CostUsd`) 의 *수동적 보존* — 측정도 검증도 정책 결정도 하지 않음

## Rationale

### 카테고리 명확성
mora-knode 의 시장 카테고리는 "AI 에이전트 친화적 매트릭스 PM 플랫폼" 이지 "AI 자동화 도구" 가 아니다. GitHub 이 Cursor / Claude Code 의 host 이지만 GitHub 자체는 LLM 을 호출하지 않는 것과 같다. 카테고리가 흐려지면:
- Plane / Taskade / ClickUp Brain (AI-native PM, AI 내장형) 과 같은 카테고리로 분류돼 정면 경쟁
- Factory / IBM Bob / GitLab Duo (SDLC Agent) 의 enterprise 자본 게임에 끌려감
- 마케팅 메시지 혼란 — "AI 기능" 을 추가하라는 압력

### 외부 에이전트 다양성 보장
운영자가 자기에 맞는 도구를 자유롭게 선택할 수 있어야 mora-knode 가 다양한 에이전트의 host 가 된다. mora-knode 가 특정 LLM 에 묶이면:
- Claude 만 지원 → OpenAI / Gemini / 자체 모델 사용자 배제
- 모든 LLM 지원 시도 → 유지보수 폭발 (1인 회사가 감당 불가)

### 운영 단순화 (1인 회사 적합성)
- LLM 가격 변동 리스크 0 (Anthropic 이 가격 인상해도 mora-knode 마진 영향 없음)
- LLM 컴플라이언스 (region-pinned, GDPR, SOC2) 책임 0 — 외부 에이전트의 LLM 계약으로 위임
- LLM 호출 SLA / latency / quota 관리 0
- 토큰 비용 측정 / 과금 / 환불 시스템 구축 0

### 책임 경계 명확
- LLM 이 잘못된 답변을 한 책임은 LLM provider — 사용자가 자기 LLM 계약을 가짐
- mora-knode 의 책임은 mora-knode 가 직접 만든 것에만 — 매트릭스 / 게이트 / audit 로직의 정확성

### AGPL + open-core 와 정합
Cloud tier 의 마진이 LLM 토큰 마진에 의존하지 않으므로:
- self-hosted (Free) vs cloud (paid) 가치 격차가 *LLM 비용* 이 아니라 *호스팅·SSO·audit 자체* 로 명확
- AGPL 카피레프트 압력 하에서도 cloud 차별 유지 가능

## Out of Scope (이 ADR 의 결정 대상 아님)
- 외부 에이전트가 어떤 LLM / SDK 를 쓸지 — 운영자 자유 ([agent-operations.md](../dogfooding/agent-operations.md) 권장 패턴)
- 외부 에이전트가 자기 토큰 사용량을 mora-knode 에 *선택* 제출하는 것 — 허용 (수동적 보존). 단 mora-knode 는 그 데이터로 정책 결정 안 함

## Consequences

### 긍정적
- 시장 카테고리가 깨끗 ("협업 플랫폼") — 정면 경쟁 회피
- 운영 단순 — 1인 회사가 짊어질 책임 영역 최소화
- 외부 에이전트 다양성 — 어떤 도구든 받아들임
- AGPL + open-core 의 가격 차별화가 명확
- 책임 / 면책 조항이 단순해짐 (LLM 호출 책임 없음)

### 부정적
- "왜 키만 입력하면 자동으로 안 돌아가나?" 형태의 사용자 기대를 매번 명확히 거부해야 함 (마케팅 / docs / onboarding 메시지에 명시적 진술 필요)
- 외부 에이전트 셋업 마찰 → onboarding UX 가 생명선 (RBAC 발급 / 토큰 발급 / 외부 도구 설정 가이드 필요)
- 통합 비용 가시성을 mora-knode 가 *주도적으로* 제공 못함 — 외부 에이전트가 자기 메트릭을 제출해야만 가시화 가능

## 재검토 조건
**본 결정은 의도적으로 강하게 반대 압력을 견디도록 설계됨.** 재검토는 다음 모두 동시 만족 시에만 고려:
- 외부 에이전트 셋업 마찰이 50% 이상의 잠재 사용자를 잃는 원인으로 입증
- mora-knode 가 LLM 을 호출하는 옵션이 카테고리 혼란 / 1인 운영 부담 / 마진 압박을 *모두* 해결한다는 증거
- AGPL + open-core 의 cloud 차별점을 LLM 호출 외 다른 방식으로는 강화 불가능하다는 결론

위 조건이 모두 충족되지 않으면 "AI 자동화 추가" 유혹은 거부.

## 관련 문서
- [ADR-002 (Plan 제출/검토/승인 게이트)](ADR-002-manager-approval-gate.md)
- [ADR-004 (Agent Identity & API)](ADR-004-agent-identity-and-api.md)
- [agent-operations.md (외부 에이전트 운영 권장 패턴)](../dogfooding/agent-operations.md)
- [../research/2026-04-29-ai-agent-trends-fit-review.md](../research/2026-04-29-ai-agent-trends-fit-review.md) — 시장 포지셔닝 / 카테고리 분석
