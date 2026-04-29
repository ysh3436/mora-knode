# Mora Knode — 외부 에이전트 host 카테고리 시장성 & 적합도 검토

- 작성일: 2026-04-29 (전면 재작성)
- 작성 맥락: 카테고리 재정의 ([ADR-005](../architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md)) 후 시장성 / 사업 모델 / 일정 / 리스크를 깨끗한 가정 위에서 처음부터 분석
- 워크스페이스 차원 요약: [../../../../planning/research/2026-04-29-ai-agent-trends-summary.md](../../../../planning/research/2026-04-29-ai-agent-trends-summary.md)
- 후속 액션: [../planning/TODO.md](../planning/TODO.md) Phase 2 확장

> 본 검토는 mora-knode 가 **"외부 AI 에이전트의 협업 host 인 매트릭스 PM 플랫폼"** 이라는 카테고리 정의 위에서 출발한다. mora-knode 는 LLM 을 호출하지 않으며 어떤 모델 / SDK / 키도 모른다 ([ADR-005](../architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md)). 외부 에이전트는 mora-knode 가 발급한 ID / 토큰 / RBAC 으로 1급 시민으로 일한다 ([ADR-004](../architecture/ADR-004-agent-identity-and-api.md)).
>
> **운영 가정 (2026-04-29 결정)**: ysh 1인 솔로 개발, **design partner 모집 안 함**, 가격 / 비용 모델은 **M5 정식 출시 시점에 재검토**. 타겟만 회사 규모 (5~50명 매트릭스 SW 회사) 로 설계 / 검증.

---

## 0. TL;DR

1. **카테고리**: 제3 카테고리 — Plane / Taskade (AI 내장) 와 Factory / IBM Bob (자체 SDLC 자동화) 사이의 *외부 에이전트 host*. GitHub ↔ Cursor 관계와 동형
2. **트렌드 정합성**: MCP / A2A 표준화 / multi-agent specialist / human-in-the-loop 게이트는 강한 tailwind. "Agent SDK 채택 가속" 트렌드는 *의도적 비채택* — mora-knode 카테고리에 정확
3. **시장 niche**: 직접 비교 도구 사실상 부재. 5-feature 교집합 first-mover, 시간 창 6~12 개월 — 단 평가는 자기 위주 편향 가능 (§4 비판 검토)
4. **타겟**: 5~50명 매트릭스 SW 회사. ysh 솔로 dogfooding → M3 오픈소스 공개 → M5 정식 출시 까지 **외부 협업 / partner 없이 단독 진행**
5. **사업 모델 방향 (참고)**: AGPL v3 + open-core + BYOA. **가격 / Tier 결정은 M5 (2026-12 ~ 2027-01) 정식 출시 시점에 재검토** — 지금은 미룸
6. **일정**: M1 = 2026-05-07, M2 = 2026-06-15, M3 (오픈소스 공개) = 2026-08, M4 (cloud alpha) = 2026-10, M5 (정식 출시) = 2026-12 ~ 2027-01. PRD 일정 (M1 = 04-30) 은 5~10% 성공률
7. **최우선 단기 액션**: P0-1 MCP 서버 스캐폴딩 + P0-4 LICENSE 사전 commit + P1-8 BYOA 온보딩 UX
8. **3대 리스크**: ① 카테고리 인식 실패 (사용자가 "AI 자동화 도구" 로 오해) ② Anthropic / OpenAI 의 자체 PM 출시 ③ Plane 의 외부 에이전트 지원 추가. 헤지는 §9

---

## 1. 카테고리 정의

### 1.1 외부 AI 에이전트 host 매트릭스 PM 플랫폼이란

mora-knode 의 시장 정의:

| 차원 | 정의 |
|---|---|
| 무엇을 하는가 | 사람과 외부 AI 에이전트가 같은 매트릭스에서 협업하는 PM 플랫폼 |
| 누구의 host 인가 | 임의 외부 AI 에이전트 — Claude Code / Cursor / Cline / 자체 봇 / Factory / IBM Bob 의 클라이언트 / 미래의 도구 |
| LLM 호출은 누가 | mora-knode 가 *아니라* 외부 에이전트. mora-knode 는 LLM 을 모름 |
| Plan 은 누가 만드나 | 외부 에이전트 (또는 사람). mora-knode 는 받아서 게이트만 |
| 차별 지점 | Agent Identity (ID/토큰/RBAC) + Plan 게이트 + 매트릭스 슬롯 + revision 메트릭 |

### 1.2 GitHub ↔ Cursor 비유

GitHub 은 git/issue/PR 호스팅만 하고 코드는 직접 작성하지 않는다. Cursor / Claude Code 가 외부에서 들어와서 GitHub 의 PR 을 만든다. GitHub 은 Cursor 가 어떤 모델을 쓰는지 모른다.

mora-knode 는 PM 영역에서 같은 관계 — task / plan / approval / 매트릭스 호스팅만, 외부 에이전트가 들어와서 일함.

### 1.3 다른 카테고리와의 분리

| 카테고리 | 대표 도구 | mora-knode 와의 관계 |
|---|---|---|
| 일반 PM (사람만) | Linear, Jira, Asana, monday.com | 정면 경쟁 가능하지만 *AI 친화* 차별점 모호 (그들도 점차 AI 추가) |
| AI-native PM (AI 내장) | Plane, Taskade, ClickUp Brain | **다른 카테고리** — 그들은 AI 를 자기 안에 넣고, mora-knode 는 외부에서 받음 |
| SDLC Agent (자체 SDLC 자동화) | Factory, IBM Bob, GitLab Duo | **그들의 host 가 될 수 있음** — Factory 의 에이전트가 mora-knode 에 plan 제출 가능 |
| 매트릭스 리소스 | Float, Runn, Resource Guru | mora-knode 가 PM/간트와 통합 |

mora-knode 는 위 4 카테고리 어디에도 직접 속하지 않는 *제3 카테고리*. 단 사용자 / 시장이 이 분리를 *인식하는가* 가 가장 큰 리스크 (§9.1).

---

## 2. 2026 트렌드와의 정합성

### 2.1 강한 tailwind (mora-knode 카테고리에 유리)

| 트렌드 | mora-knode 적용 | 강도 |
|---|---|---|
| MCP (Anthropic) 표준화 | mora-knode REST API → MCP 서버로 래핑 시 모든 MCP 클라이언트가 mora-knode 를 host 로 인식 | **강** |
| A2A (Google) 표준화 | 외부 에이전트 간 직접 통신 표준화 시 mora-knode 가 *blackboard 호스팅* 의 자연스러운 위치 | **중** (표준 미정착) |
| Multi-agent specialist 팀 (Gartner +1,445%) | mora-knode 의 Manager / Developer / Reviewer / QA 권장 패턴과 정합 | **강** |
| Human-in/on/out-of-the-loop 스펙트럼 | ADR-002 의 plan 게이트 + RBAC approve 권한 사람 기본 → 자율성 점진 확대 가능 | **강** |
| 결정론적 가드레일 (정책 + 사람 판단) | RBAC + Plan 게이트 + audit | **강** |
| AI workforce 매트릭스 통합 (Deloitte 2026) | Resource.Kind = Agent 의 매트릭스 가동률 합산 | **강** |

### 2.2 의도적 비채택 (트렌드 ≠ 항상 채택)

| 트렌드 | mora-knode 의 결정 | 근거 |
|---|---|---|
| Agent SDK 채택 가속 (Claude Agent SDK / OpenAI Agents SDK) | mora-knode 자체는 채택 안 함 | ADR-005 — mora-knode 는 LLM 을 호출하지 않음. 외부 에이전트 자유 |
| AI 도구로서의 PM 통합 (Plane / Taskade 패턴) | 비채택 | 카테고리 차별 — AI 는 외부에서 들어옴 |

이 두 결정은 트렌드의 *주류 흐름과 반대* 지만 mora-knode 카테고리에 정확. 채택하면 카테고리가 흐려짐.

### 2.3 의도적 보류

- **A2A 분산 에이전트 통신**: 표준 미정착 + Stage 0~1 에서 polling 충분 → Phase 2 이후
- **분산 병렬 에이전트 실행**: 1인 운영 단계에서 오버엔지니어링

### 2.4 갭 (보강 필요)

- **MCP 서버 스캐폴딩** — 강한 tailwind 를 활용하려면 즉시 (P0-1)
- **OpenTelemetry / 표준 audit 포맷** — enterprise 진입 시 SIEM 통합 요구. 단 M3 이후

---

## 3. 시장 분석

### 3.1 5-feature 교집합 매트릭스

| 도구 | 매트릭스 리소스 | PM / 간트 | AI 에이전트 1급 시민 (외부 에이전트 host) | self-hosted | revision 메트릭 |
|---|:---:|:---:|:---:|:---:|:---:|
| Float / Runn / Resource Guru | ✓ | △ | ✗ | ✗ | ✗ |
| Linear | ✗ | △ | △ (AI as feature, 내장) | ✗ | ✗ |
| Jira / Asana / monday.com | ✗ | ✓ | △ (AI as feature, 내장) | △ | ✗ |
| Plane | △ | ✓ | △ (AI 내장, AGPL) | ✓ | ✗ |
| Factory / IBM Bob / GitLab Duo | ✗ | ✗ | ✓ (자체 SDLC 자동화) | △ | ✗ |
| Moveworks / Sana / Relevance | ✗ | ✗ | ✓ (AI workforce 자체 실행) | ✗ | ✗ |
| **mora-knode** | **✓** | **✓** | **✓ (외부 에이전트 host)** | **✓** | **✓** |

**해석 시 주의**: "AI 에이전트 1급 시민" 컬럼의 ✓ 가 같은 의미가 아니다.
- Linear / Plane 의 △/✓ = AI 가 *기능* (자기가 분석/요약/제안)
- Factory / Moveworks 의 ✓ = AI 가 *제품* (자체 자동화 실행)
- mora-knode 의 ✓ = AI 가 *1급 사용자* (외부 도구가 들어와서 일함)

이 셋은 카테고리가 다르다. 매트릭스의 ✓ 는 "외부 에이전트 host" 의 ✓ 만 같은 종류로 본다. 그 기준에서 시장에 같은 카테고리 도구가 사실상 부재.

### 3.2 직접 / 간접 경쟁 평가

| 카테고리 | 진입성 | 근거 |
|---|---|---|
| 일반 AI PM (정면) | **NO-GO** | Tier 1 (ClickUp / Linear / Jira / Notion) 자본 게임 |
| AI-native PM (AI 내장) | **NO-GO** | Plane / Taskade 와 동일 카테고리 진입 = 후발주자 |
| SDLC Agent 플랫폼 | **NO-GO** | Factory / IBM Bob / GitLab Duo 거대 자본 |
| 매트릭스 리소스 (분리) | 단독 의미 없음 | Float / Runn 과 PM/간트 분리는 가치 미약 |
| AI Workforce (자체 실행) | **NO-GO** | Moveworks / Sana 엔터프라이즈 자본 |
| **외부 에이전트 host 매트릭스 PM** | **GO (first-mover)** | 직접 비교 도구 부재. 시간 창 6~12 개월 |

### 3.3 시간 창 6~12 개월 근거

- **Plane (AGPL, AI-native, MCP 내장)**: 다음 분기에 "외부 에이전트도 받음" 으로 카테고리 침투 가능. 단 핵심 가치 (자체 AI) 우선순위가 높아 BYOA 모델은 분기 내 도입 가능성 낮음
- **Anthropic / OpenAI**: 자체 PM 도구 출시 가능 (그들의 LLM 에 묶임 → BYOA 와 정면 충돌)
- **Linear / Jira**: enterprise 시장 자기 영역에서 AI 추가 — *내장* 모델 우선. 외부 에이전트 host 는 enterprise 가 *요청* 해야 우선순위 올라감 (12개월+)
- **GitHub**: agent identity 가 git 영역에서 점차 진화 중. PM 영역 확장 가능성 있으나 GitHub Projects 의 PM 깊이가 약함. 24개월+ 추정

→ **6 개월 동안 brand 선점 (M3 공개) + 12 개월 동안 dogfooding 데이터 축적** 이 골든 타임. partner 없이 ysh 단독 dogfooding 메트릭이 narrative 의 단일 축.

---

## 4. 차별점 비판 검토 (자기 평가 ≠ 절대 평가)

§3 의 5-feature 매트릭스는 mora-knode 를 *너무 좋게* 평가할 가능성. 차별점 4가지를 비판적으로 점검.

### 4.1 "외부 에이전트 host" 의 진짜 가치

- **강점**: LLM 중립 → 사용자가 자기 도구 자유 선택 / 다중 도구 혼용 (Manager Claude, Developer Cursor) / LLM 가격 변동 영향 0
- **약점**: 셋업 마찰 = 진입장벽. 일반 사용자는 "복잡한 셋업 없이 바로 AI 가 일해주는 Plane" 을 선호 가능. **BYOA 의 자유도 vs 셋업 마찰** 트레이드오프
- **모방 가능성**: Plane 이 next 분기에 "외부 에이전트도 받음" 모드 추가 = 가능. 단 핵심 가치 (자체 AI) 우선이라 BYOA 가 first-class 시민이 되긴 어려움

### 4.2 "매트릭스 + AI 식별자 합산"

- **강점**: 회사 운영의 진짜 KPI — "이 매트릭스의 사람 + AI 가동률은?" 에 직접 답변. Float / Runn 은 사람만, Plane 은 매트릭스 약함
- **약점**: 회사가 *매트릭스 조직* 자체에 인지가 없으면 가치 0. 5명 이하 평면 조직에서는 무의미. 진입장벽
- **검증 한계**: partner 없이 ysh 단독 dogfooding 만으로는 회사 규모 매트릭스의 진짜 가치 검증 불가. M5 정식 출시 후 첫 사용자 패턴이 검증 시점

### 4.3 "revision 메트릭 = 협업 품질 지표"

- **강점**: 단순 자동화 도구가 아닌 *측정* 도구. 1년치 dogfooding 데이터 = case study 의 narrative
- **약점**: 측정만 하고 강제력 없음. Plane / Linear 가 한 분기 내에 같은 메트릭 추가 가능. **방어선이 약함**
- **헤지**: revision 메트릭 자체보다 *meta 학습 루프* (revision 패턴이 외부 에이전트 프롬프트 튜닝 데이터 가 됨) 가 진짜 차별점

### 4.4 "dogfooding narrative" (partner 없는 단독 narrative)

- **강점**: 1인 회사가 자기 도구로 자기 도구를 만든다는 진정성
- **약점**: 1인 dogfooding = 회사 규모 검증 부재. 5명 회사 use case 와 1인 use case 는 다름. 외부 출시 시 "당신네 1인 사례 = 우리 5명 회사 ≠ 같음" 의문
- **유일한 narrative 축이 ysh 본인**: M5 시점까지 ysh 가 자기 외부 에이전트 4 identity 로 1년치 사용 → revision 메트릭 / 매트릭스 가동률 / plan accuracy 데이터를 솔직하게 공개. partner case study 가 없으므로 *1인 사례의 깊이* 가 narrative 의 전부

### 4.5 종합 비판

mora-knode 의 진짜 방어선은 *5-feature 매트릭스의 ✓ 합* 이 아니라 **카테고리를 처음 정의한 도구라는 인지 우위 (mindshare)**. 기능은 모방 가능하지만 카테고리 인지는 first-mover 가 강함. 단 partner 없이 1인 dogfooding 만으로 카테고리 인지를 만들기는 더 어려움 → §9.1 카테고리 인식 리스크가 가장 중요.

---

## 5. BYOA 모델의 unit economics (방향성)

### 5.1 가격 / Tier 결정 = M5 시점 재검토

**2026-04-29 결정**: 가격 / 비용 / Tier 구조는 **M5 (2026-12 ~ 2027-01) 정식 출시 시점에 재검토**. 현재는 결정 미룸.

이유:
- partner 없이 1인 dogfooding 단계 → 시장 가격 신호 부재
- M3 오픈소스 공개 (2026-08) ~ M5 정식 출시 사이 4~5개월 간 GitHub 별 / 이슈 / 첫 사용자 피드백 / 외부 도구 시장 변화 (Cursor / Claude Code 가격 동향) 를 수집 후 결정
- 지금 결정해도 M5 까지 외부 변수 (Anthropic 가격 정책 / Plane 의 분기 우선순위 / Linear enterprise 가격 / 한국 SW 회사 SaaS 지불 의향 데이터) 가 다 바뀜

### 5.2 방향성 (M5 재검토 시 시작점)

| 차원 | 방향 (M5 재검토 시 출발 가설) |
|---|---|
| 라이선스 모델 | AGPL v3 + open-core (§6.1) |
| 과금 차원 | 사람 seat + AI agent identity seat (두 차원) |
| 사람 : agent 비율 | 사람 100 : agent 30~40% (자연 매트릭스 비율 1:1~3 와 정합) |
| Free tier | self-hosted 무료 (Community) — AGPL 기본 |
| Cloud 차별 | 호스팅 + SSO + audit + RBAC fine-grained |
| Enterprise 차별 | NilPop license-client 통합 + on-prem + 우선 지원 |

이 방향성은 *시작점 가설* 일 뿐 — M5 시점 시장 데이터로 재검토.

### 5.3 BYOA 가 *해결하는* 것 (운영자 관점)

| 영역 | 해결 |
|---|---|
| AI 가격 변동 리스크 | 외부 LLM 계약 → mora-knode 마진 안정 |
| 데이터 주권 | 외부 에이전트가 자기 region 선택 |
| LLM 호출 책임 / SLA | 외부 에이전트 ↔ LLM provider |
| AGPL + open-core 정합 | Cloud tier 마진이 LLM 토큰에 의존하지 않음 |
| 1인 운영 단순화 | LLM SDK / 모델 / 토큰 시스템 / 컴플라이언스 = 0 |

### 5.4 BYOA 가 *만들어내는* 것 (사용자 관점 부담)

| 영역 | 부담 |
|---|---|
| 셋업 마찰 | agent identity 등록 → 토큰 → RBAC → 외부 도구 환경변수 |
| 비용 가시성 분산 | LLM 비용은 외부 도구 / Anthropic 콘솔에서 관찰 (mora-knode 가 측정 안 함) |
| 외부 도구 의존성 | Claude Code 가 망가지면 mora-knode 의 그 에이전트도 멈춤 |
| 운영 노하우 학습 | Manager / Developer 분리, plan 구조, Git 가드 등 |

→ §6 의 BYOA 온보딩 UX 가 진입 성공의 핵심.

### 5.5 외부 에이전트 도구 변화의 영향 (헤지)

mora-knode 의 운명은 외부 에이전트 도구 시장에 부분 결합:

| 시나리오 | 영향 |
|---|---|
| Cursor / Claude Code / Cline 이 계속 성장 | mora-knode 사용자 풀 확장 (tailwind) |
| 새 도구 등장 (예: 2026-Q4 의 신규 에이전트 빌더) | mora-knode 즉시 host — REST API 만 호출하면 됨 |
| Anthropic 이 자체 PM 출시 + Claude only | 일부 시장 잠식. 단 OpenAI / 자체 봇 사용자는 mora-knode |
| Cursor 가 자기 PM 추가 + Cursor only | 동일. 단 다중 도구 혼용 회사는 mora-knode |
| MCP / A2A 표준이 굳음 | mora-knode 의 host 위치 강화 |

→ **LLM 중립 / 도구 중립 = mora-knode 의 진짜 헤지**. 단일 도구에 묶이는 PM (Plane 도 자체 AI 우선) 은 그 도구의 운명에 종속.

---

## 6. 시장 진입 경로 (1인 솔로 단독)

### 6.1 오픈소스 라이선스 — AGPL v3 (M3 이전 결정)

| 라이선스 | 특징 | mora-knode 적합도 |
|---|---|---|
| MIT / Apache 2.0 | 최대 채택률. 거대 자본 무료 호스팅 가능 | **부적합** (NilPop 라이선싱과 충돌) |
| **AGPL v3** | 클라우드 호스팅 시 소스 공개 강제. **Plane / MongoDB / Elastic 채택** | **권장** |
| BSL | HashiCorp / MariaDB / Sentry. 4년 후 자동 오픈 | 대안 |
| SSPL 등 source-available | OSI 비공식 → 일부 커뮤니티 거부 | 비추천 |

**권장: AGPL v3.** Plane 과 같은 라이선스 = 직접 비교 + open-core 진화 경로 + NilPop self-hosted 라이선싱 결합.

> LICENSE 파일은 외부 노출 (M3 공개) 이전에 commit. M3 시점이 아니라 **Phase 1.5 중**.
> 라이선스 *비용 / 가격 모델* 은 §5.1 — M5 시점 재검토.

### 6.2 진입 단계 (partner 없는 4 phase)

| Phase | 시점 | 상태 | 검증 지표 |
|---|---|---|---|
| **A. dogfooding** | M2 (2026-06-15) | ysh 1명 + 외부 에이전트 4 identity | 2주 시뮬레이션 안정. 5 프로젝트 / 50 task |
| **B. 오픈소스 공개** | M3 (2026-08) | AGPL v3 public + ysh 3개월 dogfooding 메트릭 공개 | GitHub 별 100~500 (60일), 이슈 5~20, 코드 PR 0~5 |
| **C. cloud alpha** | M4 (2026-10) | SSO + cloud hosted alpha + 활성 컨트리뷰터 0~3 (없어도 정상) | ysh 6개월 dogfooding 메트릭 + GitHub 커뮤니티 활성도 |
| **D. 정식 출시** | M5 (2026-12 ~ 2027-01) | Team / Business tier. **이 시점에 가격 / 비용 / Tier 재검토** | 첫 paying customer (외부 출시 후 결정) |
| E. enterprise (선택) | 2027+ | NilPop license-client 통합 | 첫 enterprise PoC 제안 |

partner 없으므로 narrative 의 단일 축은 **ysh 본인 dogfooding 메트릭**. M3 공개 시 README + 3개월 메트릭 (revision 통계 / 매트릭스 가동률 / plan accuracy) 솔직하게 공개해야 GitHub 커뮤니티가 카테고리 인지.

### 6.3 외부 출시 GO 체크리스트 (M3, partner 없는 단독 공개)

다음 모두 충족 시 Public 전환:
1. M2 검증 완료 (외부 에이전트 dogfooding 작동)
2. AGPL v3 LICENSE 파일 commit (Phase 1.5 중 이미 완료)
3. README + 3개월 dogfooding 메트릭 (revision 통계, 시뮬레이션 로그) 솔직 공개
4. CONTRIBUTING.md + ROADMAP.md (non-goals 포함, ADR-005 강조)
5. 외부 에이전트 1차 issue triage 작동 (메인테이너 부담 통제)
6. BYOA 온보딩 UX 작동 (5분 내 셋업 가능)

### 6.4 유통 채널

partner 없는 단독 진입의 유통 채널:
- **GitHub Trending** — AGPL v3 + 카테고리 narrative + 1분 데모 영상
- **HN Show HN** — "외부 에이전트 host 매트릭스 PM" 카테고리 첫 도구로 포지셔닝
- **Indie Hackers** — 1인 회사 dogfooding narrative 의 자연 채널
- **r/selfhosted, r/programming** — self-hosted + AI agent 친화 키워드
- **X (개발자 커뮤니티)** — Cursor / Claude Code / Cline 사용자 풀에 직접 노출
- **README 영어 우선** — open source 는 글로벌 디폴트 (한국어 보조)

---

## 7. 일정 현실성 (간결)

### 7.1 1인 개발 일정 재추정

| 시나리오 | M1 | M2 | 가정 |
|---|---|---|---|
| PRD 낙관 | 04-30 | 05-14 | 풀타임 + 막힘 없음 + 모든 스택 익숙 |
| **현실 (95%)** | **05-07** | **06-15** | 통합 디버깅 + 간트 라이브러리 평가 + Agent API 셋업 |
| 보수적 | 05-15 | 07-15 | 학습 곡선 + dogfooding 피드백 반영 |

### 7.2 위험 신호

1. **3 스택** (Flutter + ASP.NET Core + MongoDB) — 옛 4 스택 대비 1 단계 완화 (ADR-005 효과)
2. **간트차트 라이브러리 미정** — 직접 구현 1~2주 / 라이브러리 평가 3~5일
3. **Phase 1.5 4 PR** — 회귀 테스트 포함 1주 빡빡
4. **외부 에이전트 셋업** — Claude Code sub-agent / 토큰 / RBAC 첫 구성 1주

### 7.3 M1 단순화 옵션

| 옵션 | 내용 | 평가 |
|---|---|---|
| A | Flutter web 우선, 데스크톱 후순위 | 중간 |
| C | 매트릭스 리소스 매니저 P1 강등, M1 = CRUD + 간트 + 일정 로깅만 | **권장** |

---

## 8. 우선순위별 권고

### P0 — Phase 1.5 중 (즉시)

1. **MCP 서버 스캐폴딩** — REST API 를 MCP 도구로 래핑. 위치: `tools/mora-knode-mcp/` 또는 `src/mcp-server/`. 선행: PR 4 (`AgentEndpoints`) 완료
2. **워크스페이스 .claude 공통 skill** (`/idea-to-prd`, `/project-bootstrap`)
3. **Conventional Commit 검증 hook** — 외부 에이전트 커밋 규약 자동 강제
4. **LICENSE 파일 사전 commit** — AGPL v3, 외부 노출 전 필수

### P1 — M2 단계

5. **Plan 검토 게이트 UI** — Flutter "PlanReview 큐" (5분 내 처리, 모바일 우선)
6. **revision 메트릭 가시화** — 간트 위 plan accuracy 트렌드. 데이터: `AgentPlanHistory`
7. **Context Engine** — ADR/PRD/이전 plan revision 이력을 *외부 에이전트에게 제공* 하는 mora-knode 측 endpoint
8. **BYOA 온보딩 UX** — agent identity 등록 / 토큰 / RBAC / 외부 도구 환경변수 generator

### P2 — M3 이후

9. **MCP 서버 정식 manifest** — Phase D 외부 에이전트 마켓 진입점
10. **Audit trail 표준화** — `ScheduleChangeLog.ChangedBy` 시작점, OpenTelemetry 호환 옵션
11. **외부 에이전트 1차 issue triage** — 메인테이너 부담 통제 + dogfooding narrative
12. **외부 도구 비용 가시화 (선택)** — `AgentRun` 메트릭 제출 시에만 노출. mora-knode 가 측정 안 함

### P3 — 신중하게 보류

- 분산 병렬 에이전트 (오버엔지니어링)
- 자체 라이선스 서버 운영 (외부 고객 받기 시작 시)
- MCP / A2A 표준 자체 구현 (표준 굳을 때까지 사용만)
- 일반 AI PM / Enterprise SDLC 정면 승부 (영원히 보류)
- **mora-knode 안에 LLM 호출 / Agent SDK / orchestrator 추가** ([ADR-005](../architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md) 위반)

---

## 9. 리스크 + 헤지

### 9.1 카테고리 인식 실패 (최대 리스크, partner 부재로 더 중요)

**리스크**: 사용자 / 시장이 mora-knode 를 "AI 자동화 도구" 로 오해. "왜 키 입력하면 자동으로 안 돌아가나" 형태의 기대 / 실망. partner 없으므로 카테고리 narrative 를 검증해줄 외부 사례 부재.

**헤지**:
- 마케팅 메시지에 "mora-knode 는 AI 를 호출하지 않습니다 — AI 는 가져오세요" 명시
- README / docs / onboarding 첫 화면에 GitHub ↔ Cursor 비유
- BYOA 셋업 가이드를 docs 첫 페이지에 (Cursor / Claude Code / Cline 예시)
- 카테고리 차별을 *스크린샷 1장* 으로 (예: 매트릭스에 사람 + AI 식별자 합산 화면)
- ysh dogfooding 1년 데이터의 **"한 사람이 4 에이전트와 매트릭스 운영" 시연 영상** — 1인 사례로 카테고리 인지 검증

**위험도**: 매우 높음. 검증 시점 = M3 공개 후 60일 GitHub 별 / 이슈 / Discord 첫 반응. 60일 후 GitHub 별 50 이하면 카테고리 narrative 재정비 필요.

### 9.2 Anthropic / OpenAI 의 자체 PM 도구 출시

**리스크**: Anthropic 이 Claude Projects 의 PM 확장 / OpenAI 가 자체 PM 출시. 그들의 LLM 만 host 함 → BYOA 와 정면 충돌.

**헤지**:
- LLM 중립 / 다중 도구 혼용 가치 강조 (Manager Claude + Developer Cursor + QA 자체 봇 시나리오)
- Open source AGPL = 그들과 가격 / 락인 차별
- 매트릭스 / self-hosted 차원으로 enterprise 차별 — 그들은 cloud-only 가능성 높음

**위험도**: 중. Anthropic / OpenAI 가 PM 영역 진입 가능성은 12~24개월 추정.

### 9.3 Plane 의 외부 에이전트 지원 추가

**리스크**: Plane 이 다음 분기 "외부 에이전트도 1급 사용자로 받음" 모드 추가. AGPL + AI-native + MCP + 외부 에이전트 = 5-feature 다 가짐.

**헤지**:
- Plane 의 핵심 가치 = 자체 AI. BYOA 가 first-class 시민이 되긴 어려움 (제품 우선순위 충돌)
- 매트릭스 리소스 + revision 메트릭 = mora-knode 가 더 깊음 (Plane 매트릭스 약함)
- 시간 창 6 개월 동안 mora-knode 의 카테고리 인지 선점 → 그 후 Plane 추가 = "Plane 도 mora-knode 처럼" 으로 인식

**위험도**: 중상. Plane 의 분기 우선순위에 따라 결정.

### 9.4 BYOA 셋업 마찰 → 사용자 잃음

**리스크**: agent identity 등록 / 토큰 / RBAC / 외부 도구 환경변수 = 5분 이상. 일반 사용자 이탈.

**헤지**:
- onboarding wizard (5단계 → 1 클릭): identity 등록 + 토큰 + RBAC 프리셋 + 환경변수 generator + 외부 도구 가이드
- 첫 경험 데모 영상 1분 (실제 셋업 처음부터 끝까지)
- "셋업 5분, 효과 평생" narrative

**위험도**: 중. M2 dogfooding 시 ysh 본인이 셋업 시간 측정 → P1-8 우선순위 결정.

### 9.5 1인 메인테이너 번아웃 (partner 부재로 모든 부담 ysh)

**리스크**: M3 공개 후 이슈 / PR / 사용자 지원 폭증 → ysh 시간 잠식 → mora-knode 본 기능 진척 멈춤. partner 없으므로 우선 지원 채널 분리도 의미 없음 (모두 같은 GitHub Issue).

**헤지**:
- 외부 에이전트 1차 issue triage (P2-11) = dogfooding narrative + 실제 부담 완화
- CONTRIBUTING.md 에 엄격한 PR 규칙 (non-goals 명시) — Plane 정도 엄격
- ROADMAP.md 의 non-goals 절에 "AI 자동화 추가 요청은 거부" 명시 (반복 이슈 차단)
- 응답 SLA 약속 안 함. "Best effort" 만 명시
- **이슈 폭증 시 즉시 Public 비공개 모드 전환 옵션** — GitHub repo 를 잠시 private 으로 (1인 회사의 퇴로)

**위험도**: 중상. M3 공개 후 30일이 위험 구간. 메인테이너 부담이 본 기능 진척을 위협하면 반드시 즉시 조치.

---

## 10. 결정 체크리스트

ysh 가 결정해야 할 것:

### 라이선스 (M3 이전 결정 필요)
- [x] **AGPL v3 채택** (2026-04-29 결정)
- [x] **LICENSE 파일 commit — 2026-04-29 즉시 적용 완료** (Phase 1.5 중 적용)
- [ ] M3 외부 공개 시점: 2026-08 vs 더 늦게
- [ ] README 영어 우선 vs 한국어 우선 — **영어 우선 권장** (open source = 글로벌 디폴트)

### 가격 / 비용 / Tier (**M5 시점 재검토 — 지금 결정 미룸**)
- [x] 결정 미룸 (M5 정식 출시 시점에 GitHub / 사용자 피드백 / 외부 변수 보고 재검토)
- 방향성 (참고): AGPL + open-core, 사람 + agent identity 두 차원, 사람 100 : agent 30~40%

### 일정
- [x] **M1 옵션 C 채택** (2026-04-29 결정) — 매트릭스 매니저 M2 이동, 외부 에이전트 합산 처음부터 통합 설계
- [ ] M1=2026-05-07, M2=2026-06-15, M3=2026-08, M4=2026-10, M5=2026-12 채택

### 후속 ADR 우선순위
- [x] **ADR-006 채택 완료** (2026-04-29) — BYOA 온보딩 UX: UI 만 + RBAC 5 프리셋 현행 유지 + 환경변수 자동 generator
- [ ] ADR-007: Plan 검토 권한 / 책임 / EULA / SLA (M5 정식 출시 이전)
- [x] **ADR-008 채택 완료** (2026-04-29) — Flutter Web 데스크톱 only, Windows native 제거. 모바일 / 앱스토어 / 반응형 / Task 코멘트는 미래 별도 ADR
- [ ] ADR-009: 데이터 마이그레이션 어댑터 (Jira / Notion / Linear import) — M4 이후
- [ ] ADR-010 (미래): 모바일 / 앱스토어 / 반응형 / Task 코멘트 — M5 이후 또는 데스크톱 web 데이터 페치 layer 안정화 후

### 카테고리 인식 (§9.1 헤지, partner 부재로 더 중요)
- [x] **마케팅 메시지** "AI 는 가져오세요" 채택 (2026-04-29) — README + ADR-005 narrative 에 반영
- [x] **README GitHub ↔ Cursor 비유** 채택 (2026-04-29) — 카테고리 비교 표 + ASCII 다이어그램으로 README 첫 화면에
- [x] **BYOA 셋업 가이드** Quick Start 섹션 placeholder 작성 (2026-04-29) — M3 시점 ADR-006 UX 작동 후 실제 스크린샷 / 영상 추가
- [x] **1인 사례 시연 영상 컨셉** 결정 (2026-04-29) — 60초, 솔로 메인테이너가 4 agent identity (manager / developer / qa / researcher) 매트릭스로 task 입력 → plan approval → PR 머지까지. 실제 제작은 M3 시점

### 메인테이너 부담 통제 (§9.5)
- [ ] CONTRIBUTING.md 엄격 규칙 — non-goals 명시
- [ ] ROADMAP.md 에 "AI 자동화 추가 요청 거부" 절 명시
- [ ] M3 공개 후 60일 자동 점검 트리거 — 이슈 / PR 폭증 시 즉시 대응

---

## 부록 A. 참고 자료

### 트렌드
- [7 Agentic AI Trends 2026 — MachineLearningMastery](https://machinelearningmastery.com/7-agentic-ai-trends-to-watch-in-2026/)
- [AI agent orchestration — Deloitte 2026](https://www.deloitte.com/us/en/insights/industry/technology/technology-media-and-telecom-predictions/2026/ai-agent-orchestration.html)
- [AI agent frameworks 2026 — monday.com](https://monday.com/blog/ai-agents/ai-agent-frameworks/)
- [Multi-Agent Systems 2026 — Codebridge](https://www.codebridge.tech/articles/mastering-multi-agent-orchestration-coordination-is-the-new-scale-frontier)
- [Deloitte 2026 — SaaS meets AI agents](https://www.deloitte.com/us/en/insights/industry/technology/technology-media-and-telecom-predictions/2026/saas-ai-agents.html)
- [Agentic AI Trends 2026: From Pilots To Production — Acecloud](https://acecloud.ai/blog/agentic-ai-trends/)

### PM / AI-native 도구 (벤치마크)
- [Plane (AGPL v3, AI-native, MCP)](https://plane.so/) — 직접 비교 대상
- [Best AI Project Management Tools 2026 — Epicflow](https://www.epicflow.com/blog/excellent-ai-project-management-software-tools-setting-new-standards/)
- [State of AI in PM 2026 — AI PM Tools Directory](https://aipmtools.org/articles/state-of-ai-pm-2026)

### 외부 에이전트 도구 (BYOA 사용자 풀)
- [Cursor — BYOK 코딩 IDE](https://cursor.com/) — UX 벤치마크
- [Continue.dev — open-source BYOK](https://continue.dev/)
- [Cline — autonomous BYOK coding agent](https://cline.bot/)
- [Claude Code (Anthropic)](https://www.anthropic.com/claude-code)

### SDLC Agent (간접 경쟁 / 잠재 호스팅 클라이언트)
- [Factory — Agent-Native Development](https://factory.ai/)
- [GitLab Duo Agent Platform](https://about.gitlab.com/gitlab-duo-agent-platform/)
- [How agentic AI will reshape engineering 2026 — CIO](https://www.cio.com/article/4134741/how-agentic-ai-will-reshape-engineering-workflows-in-2026.html)

### 매트릭스 리소스 (간접 경쟁)
- [Float](https://www.float.com/) / [Runn](https://www.runn.io/) / [Resource Guru](https://resourceguruapp.com/)
- [Asana — Matrix Organization Guide 2026](https://asana.com/resources/matrix-organization)
- [Saviom — Matrix Resourcing](https://www.saviom.com/blog/matrix-organization-and-resourcing-challenges/)

### AI Workforce (간접)
- [Top 10 AI Workforce Platforms 2026 — Nexus](https://agent.nexus/blog/top-10-ai-workforce-platforms)
- [Relevance AI](https://relevanceai.com/) / [Dify](https://dify.ai/)

### 솔로 / 인디 / 오픈소스 사업 모델
- [The One-Person Unicorn — NxCode](https://www.nxcode.io/resources/news/one-person-unicorn-context-engineering-solo-founder-guide-2026)
- [Solo Founder AI Stack 2026 — Abhishek Chaudhary](https://abhishekchaudhary.com/blog/solo-founder-ai-saas-stack)
- [I shipped SaaS in 30 days — Indie Hackers](https://www.indiehackers.com/post/i-shipped-a-productivity-saas-in-30-days-as-a-solo-dev-heres-what-ai-actually-changed-and-what-it-didn-t-15c8876106)
- [Open Source Business Models — Heather Meeker](https://www.heathermeeker.com/) — open-core / BSL / AGPL

---

## 부록 B. 관련 mora-knode 문서

- [../prd.md](../prd.md) — PRD
- [../architecture/ADR-002-manager-approval-gate.md](../architecture/ADR-002-manager-approval-gate.md) — Plan 게이트
- [../architecture/ADR-004-agent-identity-and-api.md](../architecture/ADR-004-agent-identity-and-api.md) — Agent Identity & API
- [../architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md](../architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md) — LLM 비차별 원칙
- [../architecture/schema-integration-for-agents.md](../architecture/schema-integration-for-agents.md) — 스키마 PR 1~6
- [../planning/TODO.md](../planning/TODO.md) — 마일스톤별 작업
- [../dogfooding/agent-operations.md](../dogfooding/agent-operations.md) — 외부 에이전트 운영 권장 (mora-knode 사양 아님)
- [../../../../ops/licensing/LICENSING_MODEL.md](../../../../ops/licensing/LICENSING_MODEL.md) — NilPop self-hosted 라이선싱
