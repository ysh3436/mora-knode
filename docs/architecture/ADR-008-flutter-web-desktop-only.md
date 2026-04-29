# ADR-008: Flutter Web 데스크톱 only — Windows native 제거, 모바일 / 앱스토어 / 반응형은 미래 별도 ADR

- 상태: Accepted
- 날짜: 2026-04-29
- 연관: [PRD](../prd.md), [CLAUDE.md](../../CLAUDE.md), [ADR-005 (LLM 비차별 원칙)](ADR-005-mora-knode-does-not-orchestrate-llms.md)

## Context

Flutter 의 멀티 플랫폼 빌드 옵션 (Web / Windows / macOS / Linux native / iOS / Android native) 중 어느 타겟을 우선할지 결정 필요. 1인 회사, M5 정식 출시 (2026-12 ~ 2027-01) 까지 데스크톱 사이즈 PM 도구 카테고리 검증이 우선이다.

이전 검토 ([적합도 검토 §11.4](../research/2026-04-29-ai-agent-trends-fit-review.md)) 는 "데스크톱 매니지먼트 + 모바일 plan 승인" 의 양립을 가정했으나, 사용자 결정 (2026-04-29) 으로 **모바일 UX 의 본질은 데이터 페치 / 렌더링 성능 결정에 종속** 이라는 통찰을 반영하여 모바일 영역을 미래 별도 ADR 로 분리한다.

## Decision

### 1. M1 ~ M5: Flutter Web 데스크톱 사이즈 only

- **빌드 타겟**: Flutter Web (브라우저 배포)
- **화면 폭**: 데스크톱 사이즈 (>= 1024px) 우선. 태블릿 (768~1024px) / 모바일 (< 768px) 반응형 작업 **안 함**
- **사용자 접근**: 브라우저로 mora-knode 접속 (self-hosted localhost 또는 cloud URL)

### 2. Windows native 제거

- [src/frontend/windows/](../../src/frontend/windows/) 폴더 삭제 (2026-04-29 commit)
- Windows native exe 빌드 안 함. 사용자는 브라우저 사용
- enterprise 고객이 Windows native 명시 요구 시 재검토 조건

### 3. 모바일 / iOS / Android / 앱스토어 / 반응형 — 미래 별도 ADR

본 ADR 의 out-of-scope:
- 모바일 responsive 디자인
- iOS / Android native 앱스토어 출시
- macOS / Linux native 빌드
- PWA / Web Push Notifications
- Task 코멘트 / 채팅 / 메시징 정책 (별도 product ADR)
- 모바일에서 어떤 데이터까지 fetch 할지 / lazy load 정책

이 영역들은 데스크톱 web 의 *데이터 페치 layer + 렌더링 성능 정책* 이 안정화된 후 별도 ADR 에서 한꺼번에 다룬다 (모바일 UX 는 데이터 페치 layer 의 derivative 이기 때문).

### 4. 시점

- M1~M5 = Flutter Web 데스크톱 only
- 모바일 / 앱스토어 ADR = M5 이후 또는 데스크톱 web 사용자 피드백 (M3 공개 후 60일) 데이터로 우선순위 결정

## Rationale

### 왜 Flutter Web 인가
- **PM 도구 카테고리 표준** — Linear / Jira / monday.com / Plane 모두 웹
- **Self-hosted 배포 단순** — Docker 한 컨테이너로 backend + Flutter web 정적 자산 서빙
- **B2B 진입 자연** — 기업 IT 정책에서 native 앱 설치는 마찰. URL 만 주면 됨
- **업데이트 즉시** — 서버 배포 = 모든 사용자 즉시 최신
- **현재 코드 정합** — [src/frontend/web/](../../src/frontend/web/) 가 이미 scaffold 됨

### 왜 Windows native 를 제거하는가
- M1~M5 단계에서 의미 약함 (브라우저 사용으로 충분)
- 1인 회사 부담 줄임 (Windows 빌드 / 코드 사이닝 / 인스톨러 / 점진 업데이트 정책)
- enterprise 고객 명시 요구 시 재검토 조건. 그 시점에 추가하면 됨

### 왜 모바일 / 앱스토어 / 반응형을 분리하는가 (사용자 통찰)
- **모바일 UX 의 본질 = 데이터 페치 layer + 렌더링 성능** — 간트 / 매트릭스 dense data 를 모바일에서 어떻게 보여줄지의 결정은 *데이터 페치 / 페이지네이션 / lazy load / cursor 기반 fetch* 정책에 종속
- 데스크톱 web 의 데이터 layer 가 안정화되기 전에 모바일 UX (옵션 α/β/γ, 반응형 break-point, PWA, Task 코멘트 깊이 등) 만 결정하면 무의미
- M3 공개 후 60일 사용자 피드백 = 모바일 우선순위의 진짜 데이터
- 1인 회사가 데스크톱 web + 모바일 동시 진행 = 부담 폭증. 순차 진행이 안전

### 왜 데스크톱 사이즈 only 인가 (반응형 안 함)
- M1~M2 의 핵심 = 기능 구현 + 데이터 페치 / 렌더링 검증
- 반응형 디자인 = 추가 비용. 핵심 기능 검증 전 도입 시 분산
- 데스크톱에서 작동 / 성능 안정화 후 → 모바일 별도 ADR 에서 한 번에 (responsive + native 앱 + Task 코멘트 등 동시)

## Consequences

### 긍정적
- 빌드 / 배포 / 업데이트 단순
- 1인 회사 부담 최소화 (M5 까지 모바일 / native 부담 0)
- 카테고리 narrative 명확 (PM 웹 도구)
- 데이터 페치 / 렌더링 성능을 데스크톱 web 에서 안정화 후 모바일로 확장 = 자연스러운 진화 경로
- 가능한 사용자 피드백 = 모바일 옵션 결정의 근거 데이터

### 부정적
- 모바일에서 plan 승인 시나리오 = 데스크톱 web 의 모바일 브라우저 접속만 가능 (UX 떨어짐). M5 까지 감수
- Windows enterprise 고객의 native 앱 요구 시 즉시 대응 불가 (재검토 조건)
- 간트 / 매트릭스의 모바일 표시 전략 = 미정. 별도 ADR 까지 의문 잔존
- 모바일 매니저의 "외부에서 5분 내 plan 승인" UX 가 M5 이후로 미뤄짐

## 재검토 조건

다음 중 하나 이상 만족 시 본 ADR 또는 후속 모바일 ADR 우선순위 재검토:

- M3 공개 (2026-08) 후 60일 GitHub 이슈 / 사용자 피드백에서 모바일 요청 비율이 30% 이상
- enterprise 고객이 Windows native 앱 또는 iOS / Android 앱 명시 요구
- Flutter Web 의 데스크톱 성능 자체가 critical bottleneck (간트 / 매트릭스 렌더링이 사용 가능 수준 미달)
- 데이터 페치 layer (페이지네이션 / lazy load) 가 안정화되어 모바일 확장이 자연스러운 다음 단계

## 관련 문서

- [../prd.md](../prd.md) — PRD (§6 기술 스택)
- [../../CLAUDE.md](../../CLAUDE.md) — 프로젝트 규약
- [../research/2026-04-29-ai-agent-trends-fit-review.md](../research/2026-04-29-ai-agent-trends-fit-review.md) — §11.4 (옛 가정) → 본 ADR 로 대체
