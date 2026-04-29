# ADR-007: Short disclaimer for M3 public release — AI agent operation responsibility

- 상태: Accepted
- 날짜: 2026-04-29
- 연관: [LICENSE (AGPL v3)](../../LICENSE), [DISCLAIMER.md](../../DISCLAIMER.md), [ADR-002](ADR-002-manager-approval-gate.md), [ADR-004](ADR-004-agent-identity-and-api.md), [ADR-005](ADR-005-mora-knode-does-not-orchestrate-llms.md)

## Context

mora-knode 는 M3 (2026-08) 외부 공개 시점부터 외부 사용자가 self-host 하고 자기 회사 환경에 사용. AGPL v3 §15–17 의 기본 면책이 [LICENSE](../../LICENSE) 에 commit 됐으나 (commit 247ef51) 다음을 다루지 않음:

- **AI 에이전트의 자율 행동** (PR 생성 / commit / 일정 변경 / 리소스 재할당 등) — AGPL 작성 (2007) 시점에 없던 시나리오
- 사용자 / mora-knode / 외부 도구 / LLM provider 간 **책임 영역 경계**
- 한국 법원 / EU GDPR 등 일부 관할에서 §15–16 의 *enforceable 한계*

정식 EULA / SLA 는 M5 (2026-12~) 정식 출시 시점에 변호사 검토 후 작성. 그 사이 짧은 보강 면책이 필요.

## Decision

### 1. 위치 — README 간략 + 별도 파일 원문

- [README.md](../../README.md) License 섹션에 핵심 사항 (3~5줄)
- 전문은 별도 [DISCLAIMER.md](../../DISCLAIMER.md) 에 분리
- LICENSE 자체는 AGPL v3 표준 텍스트 (변경 안 함)

### 2. 톤 — GPT (AutoGPT / OpenHands) 스타일 중간 톤

"agents can take destructive actions, you are responsible for monitoring" 패턴. mora-knode 의 카테고리 (외부 AI 에이전트 host) 와 가장 가까운 도구들의 표준.

거부 옵션:
- *너무 강한 톤* (LangChain "EXPERIMENTAL — DO NOT USE") → 진지한 사용 자체 차단, open source 채택 저해
- *너무 부드러운 톤* (Plane 의 별도 면책 없음 / AGPL 만) → AI 자율 행동 시나리오 미커버

### 3. Scope — 6 항목

DISCLAIMER.md 의 6 섹션:

1. **Autonomous AI agent actions** — 위험 시나리오 명시 (commit / PR / 일정 변경)
2. **Your responsibilities** — 사용자 책임 영역 (plans / RBAC / LLM / data / 외부 도구 ToS)
3. **mora-knode's responsibility (limited)** — 책임 영역 (orchestration logic 정확성) + 비책임 영역
4. **Safeguards — do not bypass** — destructive 가드 위반 사례 한 줄 포함 (5-revision 한도 / human-only approve default / audit trail)
5. **Production usage warning** — M5 까지 production 비인증
6. **No warranty for dogfooding metrics** — README 의 dogfooding 데이터 illustrative only

## Rationale

### 왜 짧은 버전 / 정식 버전 분리
- 변호사 검토 비용 (수백만~수천만 원) 을 지금 들이는 건 1인 회사 부담
- M5 정식 출시 직전 (2026-11) 에 한 번에 EULA + SLA 검토 받는 게 효율
- 그 사이 (M3~M4) 에는 open source 표준 패턴으로 충분

### 왜 GPT 스타일 중간 톤
- AutoGPT / OpenHands 가 *자율 AI 에이전트* 카테고리의 표준 톤. 사용자 인지 정합
- "agents can take destructive actions" + "you are responsible for monitoring" 의 두 핵심 메시지

### 왜 README 간략 + 별도 파일
- README 첫 화면 너무 길어지지 않게 (사용자 부담)
- 의지 있는 사용자만 DISCLAIMER 자세히 봄 (open source 표준)
- 별도 파일은 git diff 로 변경 추적 (정식 버전 갱신 시 history 보존)

### 왜 destructive 가드 위반 사례를 명시
- 사용자가 5-revision 한도 / human-only approve default 를 *외부 에이전트 패치* 로 우회하면 mora-knode 의 안전 가드가 의미 없음
- "안전 가드 우회 시 책임 영역 벗어남" 명시 → 안전 가드의 *실효성* 보장

## Consequences

### 긍정적
- M3 외부 공개 시 최소 책임 분담 명시
- AGPL 기본 면책 + AI 시나리오 보강 = open source 표준 시그널
- M5 정식 EULA 작성 시 출발점 (6 영역 이미 정의됨)
- 자기 dogfooding 메트릭 공개의 부메랑 위험 차단 (illustrative only 명시)

### 부정적
- *법적 enforceable* 보장 안 됨 (변호사 미검토)
- 한국 법원 등 일부 관할에서 일부 면책 무효 가능 — M5 정식 EULA 까지 감수
- enterprise 고객은 정식 EULA 까지 도입 보류 가능

## Out of Scope (이 ADR 에서 다루지 않음)

- **변호사 검토된 정식 EULA** — M5 이전 별도 ADR 또는 ADR-007 갱신
- **SLA** (cloud 가용성 / 응답 시간) — M5 cloud 정식 출시와 함께
- **한국 / 미국 / EU 법별 enforceable 보장** — 변호사 검토 필요
- **Cookie / Privacy Policy** — cloud 호스팅 시 별도
- **Export Control / 제재** — 정식 출시 시점에 별도 검토

## 재검토 조건

- M5 정식 출시 이전 (2026-11) 에 정식 EULA + SLA 작성 (변호사 검토)
- 외부 사용자가 mora-knode 를 production 에서 사용하는 사례 발견 시 즉시 경고 강화
- 한국 법원 / EU GDPR 의 AGPL §15–17 enforceability 변경 시
- AI 에이전트의 자율 행동 관련 새 법 / 규정 (예: EU AI Act 의 mora-knode 카테고리 적용) 발효 시

## 관련 문서

- [LICENSE](../../LICENSE) — AGPL v3 §15–17 기본 면책
- [DISCLAIMER.md](../../DISCLAIMER.md) — 전문
- [README.md](../../README.md) — 간략 면책 (License 섹션)
- [ADR-002](ADR-002-manager-approval-gate.md) — Plan 게이트 (책임 영역의 근거)
- [ADR-004](ADR-004-agent-identity-and-api.md) — RBAC (사용자 권한 부여 책임의 근거)
- [ADR-005](ADR-005-mora-knode-does-not-orchestrate-llms.md) — LLM 비차별 (LLM 호출 책임 분리의 근거)
