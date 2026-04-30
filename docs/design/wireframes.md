# mora-knode UI 와이어프레임 (데스크톱)

- 작성일: 2026-04-30
- 상태: draft (레이아웃 후보 비교 → ysh 결정 대기)
- 연관: [PRD](../prd.md), [ADR-008 Flutter Web 데스크톱 only](../architecture/ADR-008-flutter-web-desktop-only.md), [planning/TODO.md](../planning/TODO.md)

## 0. 목적
M1~M2 의 데스크톱 전용 화면 구성을 결정한다. 현재 Flutter 코드 (`feat/desktop-redesign` 브랜치 베이스라인) 의 단일 컬럼 / 모달 위주 UX 를 데스크톱 multi-pane 구조로 전환한다.

## 1. 제약 / 원칙
- **타겟**: 폭 ≥ 1280px (반응형 안 함, ADR-008)
- **외부 AI 에이전트가 1급 시민** — 사람과 동일한 매트릭스 슬롯, plan 게이트, work-queue. 화면 어디서든 "Agent vs Human" 시각 구분이 자연스러워야 함
- **3단계 타임라인** (L1 Origin / L2 Current / L3 Real) 은 간트 / 태스크 디테일 어디서나 동시 가시
- **고밀도** (data-dense) 가 기본. 빈 공간 채우기 위한 요소 추가는 금지
- **로컬 마크다운 우선** 원칙대로 plan / change log / 코멘트 등은 markdown text 처리
- **PM 도구 카테고리 컨벤션** — Linear / Notion / Jira 스타일 키보드 단축, 클릭 깊이 ≤ 2

## 2. 레이아웃 후보 비교

### 후보 A — 좌측 nav + 중앙 메인 + 우측 인스펙터 (3-pane)
Linear / Notion / GitHub Issues 의 표준 패턴. 매트릭스 PM 의 "선택 → 상세 즉시 확인" 흐름에 가장 잘 맞음.

```
+------------+----------------------------------------------+----------------+
| Sidebar    | Main content                                 | Inspector      |
| ~220px     | flex                                         | ~380px (toggle)|
|            |                                              |                |
| Mora Knode | [Header bar: title + view tabs + actions]    |  Selected item |
|            | +------------------------------------------+ |  detail        |
| ▸ My work  | |                                          | |                |
| ▸ All work | |  [list / board / gantt rendering]        | |  - Title       |
| ▸ Projects | |                                          | |  - Status      |
|   ├ A      | |                                          | |  - Timelines   |
|   ├ B      | |                                          | |    L1/L2/L3    |
|   └ C      | |                                          | |  - Assignees   |
| ▸ Resources| |                                          | |    (chips)     |
| ▸ Matrix   | |                                          | |  - Change log  |
| ▸ Plans    | |                                          | |    (collapsed) |
| ▸ Audit    | |                                          | |  - Edit / Del  |
| ▸ Agents   | |                                          | |                |
|            | +------------------------------------------+ |                |
| [+ New]    | [Footer status: count, sync time, errors]    |                |
+------------+----------------------------------------------+----------------+
```

장점:
- 선택 한 번으로 우측에 상세 즉시 (모달 없음 = 데스크톱답다)
- 좌측 nav 에 Plans / Agents / Audit 같은 M2 화면을 자연스럽게 추가 가능
- 키보드: ↑↓ 이동, Enter = 인스펙터 포커스, j/k = 다음/이전 (Linear 스타일)

단점:
- 인스펙터 항상 열려 있으면 메인이 좁아짐 → 토글 / 자동 숨김 정책 필요
- 모바일 전환 시 거의 처음부터 다시 (그러나 ADR-008 로 OK)

### 후보 B — 좌측 nav + 메인만 (2-pane), 상세는 모달/풀스크린
Jira 와 Plane 의 일부 뷰가 이 패턴. 메인 뷰가 항상 풀폭이라 간트 / 매트릭스 같은 wide 표가 잘 보임.

```
+------------+-------------------------------------------------------+
| Sidebar    | Main content (full width)                             |
| ~220px     |                                                       |
|            | [Header bar]                                          |
| ▸ My work  | +---------------------------------------------------+ |
| ▸ All work | |                                                   | |
| ▸ Projects | |   [list / gantt / matrix]                         | |
|   ...      | |                                                   | |
| ▸ Matrix   | |                                                   | |
| ▸ Plans    | |   click row → modal (or dedicated subpage)        | |
|            | |                                                   | |
+------------+-------------------------------------------------------+
```

장점:
- 간트 / 매트릭스가 가로폭 넉넉 → 더 많은 일자 표시
- 구현 단순

단점:
- 상세 보려면 모달/네비게이션 → 클릭 깊이 ↑
- 빠른 트리아지 (50개 태스크 훑기) 와 불일치
- M2 의 plan 검토 (내용 보고 빠른 승인) 시나리오에 약함

### 후보 C — 상단 탭 + 좌측 미니 사이드바 + 메인
현재 베이스라인 코드의 진화형. 큰 변화 작음.

```
+--+--------------------------------------------------------------+
|  | [Top tabs: All Tasks | All Gantt | Matrix | Plans | Agents]  |
|m |                                                              |
|i +--------------------------------------------------------------+
|n | [Filter chips bar]                                           |
|i +--------------------------------------------------------------+
|  |                                                              |
|n |  [active tab content]                                        |
|a |                                                              |
|v |                                                              |
+--+--------------------------------------------------------------+
```

장점:
- 현재 코드와의 거리 짧음
- 상단 탭은 PM 카테고리에서 흔함 (monday.com 스타일)

단점:
- 인스펙터가 없어서 트리아지 흐름이 모달 의존
- 좌측 mini sidebar 가 nav 역할로는 약함 (아이콘 only ≠ 항목 검색)
- 후보 A 만큼 확장성 없음

## 3. 추천: **후보 A**

이유:
- mora-knode 의 성격 = "수십 개 태스크 빠르게 훑고 plan 승인 / revision" — 이건 *Linear pattern* 그대로
- 외부 에이전트 1급 시민 → Plans 큐, Agents 관리, Audit 트레일이 좌측 nav 에 동급으로 들어가야 함 (탭 안에 묻히면 안됨)
- 우측 인스펙터에 Plan diff / Change log / Assignment 슬롯이 동시 노출 = M2 의 핵심 흐름

## 4. 후보 A 상세 — 주요 뷰별 와이어

### 4.1 My work (기본 진입 뷰)
> "오늘 누가 무엇을 한다" 의 단일 화면. ysh + 4 에이전트 셋업에 최적.

```
[Header] My work  ·  this week (Apr 27 — May 3)             [filters] [⤢ inspector]
+------------------------------------------------------------+----------------+
| Section: Due this week                                     | (selection)    |
|  ┌─ ysh ─────────────────────────────────────────┐         |  Task          |
|  │ [▣] Design MVP schema      L2 Apr 25 → 30 60% │ ...     |  detail        |
|  │ [□] Resource model rewrite L2 Apr 28 → May 3  │ ...     |                |
|  └────────────────────────────────────────────────┘         |  ...           |
|  ┌─ developer-01 (agent) ────────────────────────┐         |                |
|  │ [▣] Endpoints batch 2     PlanReview          │ ...     |                |
|  └────────────────────────────────────────────────┘         |                |
|                                                            |                |
| Section: Pending plan review (3)                           |                |
|  • developer-01 → "Refactor matrix calc"  v2 (revised)     |                |
|  • researcher-01 → "MCP scaffolding"      v1               |                |
|                                                            |                |
| Section: Overdue (2)                                       |                |
|  ...                                                       |                |
+------------------------------------------------------------+----------------+
```

### 4.2 All work — list mode
```
[Header] All work   [List | Board | Gantt | Calendar]   [+ New task]
[Filter row]  Project: ▾ all   Assignee: ▾ all   Status: ▾ active   ⌕ search
+----+--------------------------------+----------+--------+-------+--------+--+
| ▸  | Title                          | Project  | Status | Asgn  | L2     |  |
|----+--------------------------------+----------+--------+-------+--------|--|
| ▸  | Design MVP schema              | mora     | Done   | ysh   | 4/25   |  |
| ▾  | Resource model rewrite         | mora     | InProg | ysh   | 4/28   |  |
|    |  ▸ Add Kind=Agent              |          | InProg |       | 4/28   |  |
|    |  ▸ Migration script            |          | NotStr | dev01 | 4/30   |  |
| ▸  | Plan gate API                  | mora     | Plan…  | dev01 | 5/02   |  |
+----+--------------------------------+----------+--------+-------+--------+--+
```
- 들여쓰기 트리 (계층) + 행 클릭 → 우측 인스펙터 갱신
- 컬럼 정렬 / 토글 / 폭 조절

### 4.3 All work — gantt mode
```
[Header] All work   [List | Board | Gantt | Calendar]
[Filter row]
+----------------------------+-----------------------------------------------+
| 📁 mora-knode              | Apr 24  25  26  27  28  29  30  May 1  2  3  |
|  ├─ Design MVP schema      | ▓▓▓▓▓▓▓▓▓▓▓░                                  |
|  ├─ Resource model rewrite |       ▓▓▓▓▓▓▓▓▓▓▓▓▓                          |
|  │   ├─ Add Kind=Agent     |       ░▒▒▒▒▒▒                                |
|  │   └─ Migration script   |              ░▒▒▒▒                           |
|  └─ Plan gate API          |                    ▒▒▒▒▒▒▒▒                  |
|                            |                                               |
| 📁 sample-project          |                                               |
|  └─ Kickoff                | ░░░░                                          |
+----------------------------+-----------------------------------------------+
```
- 좌측 라벨 트리 (depth 들여쓰기 + 폴더 아이콘 = 그룹)
- 우측 = 가로 스크롤 가능한 일자 grid
- 막대 = L2 Current, 얇은 라인 = L1 Origin, 점선 = L3 Real (현재 색 체계 유지)

### 4.4 Resource matrix
```
[Header] Matrix load   week of Apr 27 — May 3   [< prev] [next >]
+--------------+------+------+------+------+------+------+------+
| Resource     | Mon  | Tue  | Wed  | Thu  | Fri  | Sat  | Sun  |
+--------------+------+------+------+------+------+------+------+
| 👤 ysh       |  60% |  60% |  60% | 110% |  60% |   0% |   0% |
|              |      |      |      | ⚠    |      |      |      |
| 👤 dohyun    |   0% |  50% |  50% |  50% |  50% |   0% |   0% |
| 🤖 dev-01    |  80% | 100% | 100% |  80% |  60% |  60% |  60% |
|    (agent)   |      |      |      |      |      |      |      |
| 🤖 res-01    |   0% |   0% |  40% |  40% |  40% |   0% |   0% |
+--------------+------+------+------+------+------+------+------+

Heatmap: 0–60% green · 60–100% yellow · >100% red ⚠
Click cell → 우측 인스펙터: 그날 그 사람에게 할당된 task 목록
```

### 4.5 Project detail (단일 프로젝트 진입)
좌측 nav 에서 프로젝트 클릭 시:
```
[Header] mora-knode                            [Tasks | Gantt | Milestones | Plans]
+------------------------------------------------------------+----------------+
| 활성 탭 콘텐츠                                              | 인스펙터       |
+------------------------------------------------------------+----------------+
```
- 메인 헤더가 `mora-knode` 로 바뀌고 sub-tabs 만 프로젝트 스코프
- 좌측 sidebar / 우측 inspector 는 동일 패턴 유지

### 4.6 Inspector — task selected
```
+------------------------------------+
| Resource model rewrite       [✕]  |
| ───                                |
| Project    mora-knode              |
| Status     ● InProgress            |
|                                    |
| L1 Origin   Apr 28 — May 3         |
| L2 Current  Apr 28 — May 3   ⏵    |
| L3 Real     Apr 29 — …             |
|                                    |
| Assignees                          |
| 👤 ysh 60% · 🤖 dev-01 40%          |
|                                    |
| Children (2)                       |
| ▸ Add Kind=Agent      InProgress   |
| ▸ Migration script    NotStarted   |
|                                    |
| Recent changes (5) ▾               |
| · L2.End Apr 30→May 3  ysh 1d ago  |
| · Status NotStarted→InProgress     |
|                                    |
| [Edit]  [Delete]  [Open full →]    |
+------------------------------------+
```

### 4.7 Inspector — plan review (M2)
```
+------------------------------------+
| Plan v2 · "Refactor matrix calc"   |
| Submitted by 🤖 dev-01    2h ago   |
| ───                                |
| Diff vs v1                         |
| - Endpoints: 3 → 5                 |
| - Estimate:  2d → 3.5d             |
| + New: idempotency key             |
|                                    |
| Plan body (md preview)             |
| ┌───────────────────────────────┐ |
| │ ## Approach                   │ |
| │ Reuse existing matrix...      │ |
| └───────────────────────────────┘ |
|                                    |
| [Approve] [Revise] [Reject]        |
+------------------------------------+
```

## 5. 컴포넌트 인벤토리 (재사용)
- `AppShell` — 좌 sidebar / 중앙 / 우 inspector 토글 컨테이너
- `EntityList` — 정렬 / 그룹 / depth 트리 표
- `GanttChart` (기존 살림) — 라벨 gutter 분리해 외부에서 라벨 트리 주입 가능하도록 리팩터
- `MatrixHeatmap` — 색 단계 셀, 클릭 가능
- `Inspector` — slot-based, 헤더 + body 영역
- `TaskCardCompact`, `AssigneeChip`, `StatusDot`, `TimelineRow (L1/L2/L3)`
- `FilterBar` — 칩 + 검색
- `KbdShortcutOverlay` (?: 단축키 도움말)

## 6. 키보드 / 단축키 (Linear 라이트)
- `↑/↓` 또는 `j/k` — 행 이동
- `Enter` — inspector 토글
- `e` — 편집 모달
- `n` — 신규 항목
- `/` — 검색 포커스
- `[` — sidebar 토글, `]` — inspector 토글
- `?` — 도움말

## 7. 결정 매트릭스

| 기준 | 후보 A | 후보 B | 후보 C |
| --- | --- | --- | --- |
| 데스크톱 표준 부합 | ★★★ | ★★ | ★★ |
| Plan 검토 흐름 (M2) | ★★★ | ★ | ★★ |
| 구현 비용 (현재 코드 대비) | ★★ | ★★★ | ★★★ |
| 외부 에이전트 1급 가시성 | ★★★ | ★★ | ★★ |
| 데이터 밀도 | ★★★ | ★★★ | ★★ |
| 모바일 확장성 (M5+) | ★ | ★★ | ★★ |

## 8. 미결 (ysh 결정 항목)
1. **레이아웃 후보 확정**: A / B / C
2. **인스펙터 기본 상태**: 기본 열림 vs 기본 닫힘 (단축키로 토글)
3. **My work 진입 뷰 채택**: yes/no (no 면 All work 가 진입 화면)
4. **다크 모드**: M1 에 포함? 아니면 M3 까지 미룸?
5. **컬러 토큰**: Material 3 기본 vs 커스텀 팔레트 (mora-knode 브랜드 컬러)
6. **간트 시간 단위**: day grid 만 (현재) vs day/week/month 토글

## 9. 다음 단계
1. ysh 가 §8 결정
2. 결정된 레이아웃 기준으로 [seed-scenarios.md](seed-scenarios.md) 작성 — 이 와이어를 채울 데이터 정의
3. seed loader 구현 (Phase 1.5 의 일부 X — 단순 dev fixture)
4. UI 구현 시작 (`AppShell` → `Inspector` → 핵심 뷰 순서)

## 10. 관련 문서
- [PRD](../prd.md)
- [ADR-008 Flutter Web 데스크톱 only](../architecture/ADR-008-flutter-web-desktop-only.md)
- [ADR-006 BYOA 온보딩 UX](../architecture/ADR-006-byoa-onboarding-ux.md) — Agent 관리 화면 디테일
- [planning/TODO.md](../planning/TODO.md)
