# mora-knode UI 와이어프레임 (데스크톱)

- 작성일: 2026-04-30
- 상태: 후보 A 확정 (2026-04-30) — §0.1 결정 사항 반영
- 연관: [PRD](../prd.md), [ADR-008 Flutter Web 데스크톱 only](../architecture/ADR-008-flutter-web-desktop-only.md), [planning/TODO.md](../planning/TODO.md)

## 0.1 결정 사항 (2026-04-30)
| 항목 | 결정 |
| --- | --- |
| 레이아웃 | **후보 A** (3-pane: sidebar + main + inspector) |
| Sidebar | 기본 **열림**, 토글 가능 (`[`) |
| Inspector | 기본 **닫힘**, 토글 가능 (`]`) |
| My work 진입 뷰 | 채택 (기본 진입) |
| 메인 탭 | **List · Board · Gantt · Calendar** (모두 4탭) |
| 간트 시간 단위 | **Day / Week / Month** 토글 |
| Timeline 데이터 단위 | **timestamp (시:분 정밀도)** + **종일 토글 (timeline 단위)** — [ADR-009](../architecture/ADR-009-timeline-timestamps-allday-workcalendar.md) |
| WorkCalendar | 글로벌 1개 (org-level) MVP, 기본 Mon~Fri 09:00~18:00, 미설정 시 24/7 fallback — [ADR-009](../architecture/ADR-009-timeline-timestamps-allday-workcalendar.md) |
| 캘린더 Week 뷰 | **(b) 시간 슬롯 grid** (Outlook/Google Cal 식). 종일 task 는 상단 all-day 영역에 별도 막대 |
| 다크 모드 | M3 까지 미룸 (Material 3 기본 라이트 팔레트) |
| 컬러 토큰 | Material 3 기본 (브랜드 팔레트는 M3 공개 즈음 재검토) |

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
[Header] All work   [List | Board | Gantt | Calendar]            [zoom: Day · Week · Month]
[Filter row]                                                     [< prev] [today] [next >]
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

#### 4.3.1 줌 단위 정의
| 단위 | 한 칸 | 헤더 2단 표기 | 권장 표시 범위 |
| --- | --- | --- | --- |
| **Day** | 1일 (현재 dayWidth) | 월 + 일 (`Apr / 24 25 26…`) | ~6주 |
| **Week** | 1주 (월요일 기준) | 월 + 주차 (`Apr / W18 W19…`) | ~6개월 |
| **Month** | 1개월 | 분기 + 월 (`Q2 / Apr May Jun…`) | ~2년 |

- 단위 변경 시 막대는 동일 일자 기준으로 픽셀 폭만 재계산
- Week / Month 에서는 sub-단위 막대도 최소 4px 폭 보장 (사라지지 않도록)
- 헤더 1단 (분기 / 월) 이 두께 24px, 2단 (주 / 일) 이 두께 16px

### 4.4 All work — calendar mode
> Month grid 와 Week grid 를 토글. 태스크 = `IsAllDay` 여부에 따라 다르게 그려짐 ([ADR-009](../architecture/ADR-009-timeline-timestamps-allday-workcalendar.md)).

#### 4.4.1 Month 뷰 (기본)
```
[Header] All work   [List | Board | Gantt | Calendar]   [Month · Week]   [< prev] [today] [next >]
[Filter row]
+--------+--------+--------+--------+--------+--------+--------+
| Mon 27 | Tue 28 | Wed 29 | Thu 30 | Fri  1 | Sat  2 | Sun  3 |
+--------+--------+--------+--------+--------+--------+--------+
|        | ◆ MVP  |        |        | ◆ Demo |        |        |
| ▓▓▓ Resource model rewrite ▓▓▓▓▓▓▓ |        |        |        |
|        |   ▒▒ Migration script ▒▒  |        |        |        |
|        |        | ▒▒▒ Plan gate API ▒▒▒▒▒▒▒ |        |        |
|        |        |        | ◷ Sync 14:00     |        |        |
+--------+--------+--------+--------+--------+--------+--------+
```
- ◆ = 마일스톤. ◷ = 시간 task (시각 라벨 함께)
- 종일 task 는 가로 막대로 셀에 걸침. 시간 task 는 ◷ 아이콘 + 시각 + 제목 (한 줄)
- 행 부족 시 `+N more` 칩 → 클릭 시 인스펙터에 그날 목록

#### 4.4.2 Week 뷰 — 시간 슬롯 grid (b)
```
[Header] All work · Week of Apr 27   [Month · Week]   [< prev] [today] [next >]
+-------+--------+--------+--------+--------+--------+--------+--------+
| time  | Mon 27 | Tue 28 | Wed 29 | Thu 30 | Fri  1 | Sat  2 | Sun  3 |
+-------+--------+--------+--------+--------+--------+--------+--------+
| All-  | ▓▓▓ Resource model rewrite ▓▓▓▓▓▓▓ |        |        |        |
| day   |        |        | ▒▒▒ Plan gate API ▒▒▒▒▒▒▒ |        |        |
+-------+--------+--------+--------+--------+--------+--------+--------+
|  8AM  |        |        |        |        |        |        |        |
|  9AM  | ░ work hours start (WorkCalendar) ──────────────────────────  |
| 10AM  |        | █ 9:30 │        |        |        |        |        |
| 11AM  |        | █ Sync │        |        |        |        |        |
| 12PM  |        | (1.5h) │        |        |        |        |        |
|  1PM  |        |        |        |        |        |        |        |
|  2PM  |        |        | █ 14:00│        |        |        |        |
|  3PM  |        |        | █ Plan │        |        |        |        |
|  4PM  |        |        | review │        |        |        |        |
|  5PM  |        |        | (3h)   |        |        |        |        |
|  6PM  | ░ work hours end ────────────────────────────────────────────  |
|  7PM  |        |        |        |        |        |        |        |
+-------+--------+--------+--------+--------+--------+--------+--------+
```
- 상단 **All-day 행**: 종일 task 가로 막대 (Outlook 패턴)
- 시간 grid: WorkCalendar 의 `DailyStart-1h ~ DailyEnd+1h` 자동 (기본 8AM~7PM). 미설정 시 6AM~10PM
- 시간 task = 시각 슬롯 안 박스. 박스 안에 시작 시각 + 제목 + 길이
- ░ = work hours 시작/끝 라인 (수평 가이드)
- 비업무일 (토/일) 컬럼은 옅은 회색 배경 (WorkDays 비포함)

### 4.5 Resource matrix
```
[Header] Matrix load   week of Apr 27 — May 3   WorkCalendar: Mon–Fri 09–18
                                                [< prev] [next >] [⚙ calendar]
+--------------+------+------+------+------+------+------+------+
| Resource     | Mon  | Tue  | Wed  | Thu  | Fri  | Sat  | Sun  |
+--------------+------+------+------+------+------+------+------+
| 👤 ysh       |  60% |  60% |  60% | 110% |  60% |   —  |   —  |
|              |      |      |      | ⚠    |      |      |      |
| 👤 dohyun    |   —  |  50% |  50% |  50% |  50% |   —  |   —  |
| 🤖 dev-01    |  80% | 100% | 100% |  80% |  60% |   —  |   —  |
|    (agent)   |      |      |      |      |      |      |      |
+--------------+------+------+------+------+------+------+------+

- Heatmap: 0–60% green · 60–100% yellow · >100% red ⚠
- 비업무일 (Sat/Sun) = `—` (계산 제외, 옅은 회색)
- WorkCalendar 미설정 시 모든 칸이 24h 기준으로 계산되고 헤더 표기 = "24/7"
- 셀 클릭 → 우측 인스펙터: 그날 그 사람의 task 목록 (시작-끝 시각, 시간 task 는 hh:mm 표시)
- [⚙ calendar] → WorkCalendar 설정 모달 (요일 토글, DailyStart/End 시각 picker, Timezone)
```

### 4.6 Project detail (단일 프로젝트 진입)
좌측 nav 에서 프로젝트 클릭 시:
```
[Header] mora-knode                            [Tasks | Gantt | Milestones | Plans]
+------------------------------------------------------------+----------------+
| 활성 탭 콘텐츠                                              | 인스펙터       |
+------------------------------------------------------------+----------------+
```
- 메인 헤더가 `mora-knode` 로 바뀌고 sub-tabs 만 프로젝트 스코프
- 좌측 sidebar / 우측 inspector 는 동일 패턴 유지

### 4.7 Inspector — task selected
```
+------------------------------------+
| Resource model rewrite       [✕]  |
| ───                                |
| Project    mora-knode              |
| Status     ● InProgress            |
|                                    |
| L1 Origin   ☐ all-day              |
|             Apr 28 — May 3         |
| L2 Current  ☐ all-day              |
|             Apr 28 — May 3   ⏵    |
| L3 Real     ☑ timed                |
|             Apr 29 09:30 — 14:00   |
|             (4.5h, planned 1d)     |
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
- 각 timeline 옆 `☐ all-day` / `☑ timed` 토글
- timed 모드: 시각 함께 표기. L3 의 (실제시간, plan 견적) 비교 자동 계산

### 4.8 Inspector — plan review (M2)
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

## 8. 미결

(없음 — 모든 결정 항목이 §0.1 표 또는 [ADR-009](../architecture/ADR-009-timeline-timestamps-allday-workcalendar.md) 에 박힘)

> 다른 §0.1 항목들 (다크 모드, 컬러, my-work 진입 등) 은 추천 그대로 진행. dogfooding 결과 보고 M2 이후 재검토.

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
