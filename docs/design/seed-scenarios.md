# mora-knode Seed 데이터 시나리오

- 작성일: 2026-04-30
- 상태: draft
- 연관: [wireframes.md](wireframes.md), [ADR-009 timeline timestamps + WorkCalendar](../architecture/ADR-009-timeline-timestamps-allday-workcalendar.md), [ADR-004 Agent Identity & RBAC](../architecture/ADR-004-agent-identity-and-api.md), [ADR-006 BYOA UX](../architecture/ADR-006-byoa-onboarding-ux.md)

## 0. 목적
재설계된 데스크톱 UI ([wireframes.md](wireframes.md)) 의 모든 뷰 / 토글 / 권한 분기를 한번에 검증할 수 있는 dev fixture 를 정의한다. 빈 DB 에 한 번 적재 → 4탭 메인 + 매트릭스 + 캘린더 (Month/Week) + 인스펙터 + 권한 분기를 전부 즐길 수 있어야 함.

## 1. 원칙
- **밀도 우선** — 빈 셀 / 빈 컬럼이 거의 없도록. 가장자리 케이스 (overdue / overload / blocked / paused) 가 골고루
- **결정성** — 시드 적재 결과가 매번 동일 (날짜는 "오늘" 기준 상대 offset). `today = 2026-04-30 (UTC)` 라는 가정으로 본 문서에 절대일자 기록. 적재 시점에는 `now.UtcNow` 기준으로 자동 환산
- **종일 + 시간 mix** — ADR-009 의 `IsAllDay` 분기를 양쪽 다 시각 검증. 대부분 종일이지만 L3 Real 일부는 timed
- **권한 시연** — Human user 두 명이 서로 다른 RBAC preset 으로 등록되어, "Approve" / "Reject" / "Edit" 같은 UI 어포던스 표시 차이를 즐길 수 있음
- **단일 명령 적재** — `dotnet run --seed` 또는 `POST /api/dev/seed` 한 번으로 끝. 멱등 (이미 데이터 있으면 wipe-and-reseed)

## 2. 스키마 보강 (seed loader 구현 시 함께 반영)

### 2.1 `Resource` 추가 필드
ADR-004 의 [Phase 1.5 PR2](../architecture/schema-integration-for-agents.md) 를 일부 선당김:
```csharp
public class Resource {
    // existing: Id, Name, Role(string), CapacityPercent, CreatedAt, UpdatedAt
    public ResourceKind Kind { get; set; } = ResourceKind.Human;
    public RbacPreset Rbac { get; set; } = RbacPreset.Human;   // for Human users
    public string? AgentDescription { get; set; }              // free text for Agents
}

public enum ResourceKind { Human, Agent }
public enum RbacPreset { Manager, Reviewer, Developer, QA, Human }
```
- `Rbac` 는 사람 / 에이전트 양쪽 다 적용. agent 의 경우 plan 제출 / approve 권한 분리 핵심
- Human user 의 경우도 "Owner" 와 "Contributor" 등 권한 구분이 필요해 ADR-004 의 Human/Manager/Developer 등 매핑 사용

### 2.2 `WorkCalendar` 신규
ADR-009 정의 그대로:
```csharp
public class WorkCalendar {
    public string Id { get; set; } = "default";
    public WorkDayMask WorkDays { get; set; } = WorkDayMask.MonToFri;
    public TimeOnly DailyStart { get; set; } = new(9, 0);
    public TimeOnly DailyEnd   { get; set; } = new(18, 0);
    public string Timezone { get; set; } = "Asia/Seoul";
}
```

### 2.3 `Timeline` 확장
ADR-009 그대로:
```csharp
public class Timeline {
    public DateTime? Start { get; set; }
    public DateTime? End { get; set; }
    public bool IsAllDay { get; set; } = true;
}
```

## 3. Seed 데이터 명세

### 3.1 WorkCalendar (1 doc)
```
id: default
workDays: Mon..Fri
dailyStart: 09:00
dailyEnd: 18:00
timezone: Asia/Seoul
```

### 3.2 Resources (4 humans + 3 agents = 7)

| # | Name | Kind | RBAC | Capacity | Role hint | 비고 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | **ysh** | Human | **Manager** | 100% | Owner | 1차 테스트 사용자, 전체 권한 ≈ Manager |
| 2 | **alice** | Human | **Developer** | 100% | Contributor | 2차 테스트 사용자, 권한 제한 (plan approve 불가) |
| 3 | **bob** | Human | **Reviewer** | 80% | QA Lead | 3번째 사람, plan 검토 전용 (편집 못함) |
| 4 | **carol** | Human | **QA** | 60% | Tester | 검증 task 접근 |
| 5 | dev-01 | Agent | Developer | 100% | implementer | "Claude Code 기반 코드 작성 에이전트" |
| 6 | researcher-01 | Agent | Manager | 100% | planner | "외부 자료 조사 + plan 제출" |
| 7 | qa-01 | Agent | QA | 80% | tester | "회귀 시나리오 자동 실행" |

→ 권한 시연 핵심: **ysh (Manager)** vs **alice (Developer)** 두 명을 dev-mode 사용자 스위처로 갈아끼우면서 동일 화면의 어포던스 차이 확인.

### 3.3 권한 표 (ADR-004 §3 발췌, UI 가시성에 그대로 반영)
| 권한 / 가시성 | Manager | Reviewer | Developer | QA | Human(전체) |
| --- | --- | --- | --- | --- | --- |
| Plan 제출 / 수정 | ✓ | ✗ | ✓ | ✗ (수정 task 만) | ✓ |
| Plan approve / reject / revise | ✓ (PlanDraft↔Review 한정) | ✓ | ✗ | ✗ | ✓ |
| Task status: InProgress↔Done | ✓ | ✗ | ✓ | ✓ | ✓ |
| Resource 관리 | △ | ✗ | ✗ | ✗ | ✓ |
| WorkCalendar 편집 | ✗ | ✗ | ✗ | ✗ | ✓ |
| **프로젝트 가시 범위** | **전체** | **전체** | **할당된 것만** | **할당된 것만** | **전체** |
| **태스크 가시 범위** | **전체** | **전체** | **할당된 것 + 그 조상** | **할당된 것 + 그 조상** | **전체** |
| **매트릭스 행 가시 범위** | **전체** | **전체** | **본인 행만** | **본인 행만** | **전체** |

→ **alice (Developer)** 로 로그인하면 plan approve 버튼 disabled / 숨김. WorkCalendar 설정 진입 막힘. 그리고 **할당이 없는 프로젝트는 좌측 sidebar 와 전체 뷰에 안 보임** — 단, 부모 task 는 자식이 할당되면 함께 보여서 컨텍스트 유지. **ysh (Manager)** 로 갈아타면 전부 보임.

### 3.4 가시 범위 규칙 (View scoping)

**규칙 (Manager / Reviewer / Human 은 본 규칙에서 제외 — 항상 전체 가시):**

1. **프로젝트 가시 범위** = `{ p | ∃ task t ∈ p, ∃ assignment a, a.taskId = t.id ∧ a.resourceId = currentUser.id }`
   - 즉, 본인이 할당된 task 가 1개라도 있는 프로젝트만 좌측 sidebar / 프로젝트 필터 / All work 에 표시
2. **태스크 가시 범위** = `{ t | t.assignedToCurrentUser ∨ t ∈ ancestors(any-assigned-task) }`
   - 본인 task + 그 조상. 형제 / 자식 / 다른 갈래는 안 보임
   - 부모 task 의 timeline / status 는 자식 rollup 으로 자연스레 일부 노출되지만, 부모 자체를 *편집* 권한은 없음 (read-only 표시)
3. **매트릭스 행 가시 범위** = 본인 1행 + 같은 task 에 같이 배정된 다른 사람들의 *로드 합산만* (개인 row 는 안 보임)
   - 또는 단순화: 본인 행만 표시 (MVP 는 이쪽 채택. M2 이후 "팀 매트릭스" 토글 추가 검토)
4. **Inspector 의 Children / Assignees 표시**: 본인이 못 보는 자식 / 다른 assignee 는 익명 칩 (`👤 ✱ 40%`) 으로 숨김 처리. count 만 노출
5. **Change log**: 본인이 볼 수 있는 entity 의 로그만. 다른 entity 의 로그는 hide

**검증 시나리오:**
- ysh (Manager) → 5 프로젝트 모두 보임, 30+ task 모두 보임, 매트릭스 7 행 모두 보임
- alice (Developer) → ysh 가 alice 에게 client-acme #17 만 배정했다면, alice 에겐 client-acme 프로젝트와 task #17 + 그 부모만 보이고 다른 4개 프로젝트는 sidebar 에 없음
- bob (Reviewer) → 전체 보임 (검토 권한)
- carol (QA) → 본인 할당된 #19 만 + 부모

→ seed 데이터에서 alice 에겐 일부러 client-acme 와 internal-tools 의 일부 task 만 배정해서, 1차 시각 차이가 가장 크게 보이도록 한다.

### 3.5 Projects (5)
| ID 슬러그 | Name | Status | Description |
| --- | --- | --- | --- |
| mora-knode | mora-knode itself | Active | dogfooding meta project. M1 redesign 작업 |
| internal-tools | NilPop internal tools | Active | 작은 사내 도구. 짧은 task 위주 |
| client-acme | ACME consulting | Active | 외부 고객. milestones 위주 |
| spike-mcp | Spike: MCP scaffolding | Planning | P0-1 결정 대기. 거의 빈 프로젝트 |
| archived-legacy | Archived: legacy gantt prototype | Archived | 오래된 데이터. archived 필터 검증용 |

### 3.6 Milestones (8 across projects)
- mora-knode: "M1 MVP ready" (오늘+7), "M2 Agent host" (오늘+45)
- internal-tools: "Slack hook live" (오늘+3 — 임박)
- internal-tools: "Quarterly cleanup" (오늘-2 — 지난, 미완)
- client-acme: "Phase 1 delivery" (오늘+14)
- client-acme: "Phase 2 kickoff" (오늘+30)
- archived-legacy: "Sunset" (오늘-90 — 종료, Done)

### 3.7 Tasks — 시나리오 카탈로그

> 각 task 는 `(L1 Origin, L2 Current, L3 Real, IsAllDay 패턴)` 4튜플로 표현. 날짜는 today = 0 기준 상대.

**A. mora-knode (15 tasks)** — 현실적인 매트릭스 PM 도구 개발 흐름
1. ▸ Domain model design *(L1 -7..0 종일, L2 -7..-2 종일, L3 -7..-3 timed 9:00–17:30, Done)*
2. ▸ Backend CRUD endpoints *(L1 -5..+2, L2 -5..+1, L3 -5..0 timed days, Done)*
3. ▸ Frontend foundation *(L1 -5..+5, L2 -3..+5, L3 -3..0 partial, InProgress)*
   - ▸ ▸ Riverpod state setup *(InProgress, 부모 rollup 검증용 자식)*
   - ▸ ▸ Gantt widget v0 *(Done)*
   - ▸ ▸ Calendar week grid *(NotStarted, L2 +2..+5)*
4. ▸ Resource dedupe migration *(L1 0..+1, L2 0..+1, IsAllDay true, Done — 시간 안 측정한 케이스)*
5. ▸ Agent identity + RBAC API *(L1 +5..+15 종일, NotStarted)*
6. ▸ Plan gate API *(L1 +10..+20, PlanDrafting [Phase 1.5 enum 미리])*
7. ▸ Work-queue API *(L1 +10..+25, NotStarted)*
8. ▸ MCP scaffolding spike *(Blocked, "P0-1 결정 대기")*

**B. internal-tools (8 tasks)** — 짧은 timed task 가 많음
9. ▸ Slack hook design *(L2 -1..+2 timed 09:30–11:00 매일, InProgress)*
10. ▸ CSV import script *(L2 -3..-1 timed 14:00–17:00, Done)*
11. ▸ Cron job migration *(L2 -10..-5 종일, Done — 정상 완료)*
12. ▸ Cron job rollback *(L2 -2..0 종일, Done — 사고 케이스. change log 5건 누적)*
13. ▸ Quarterly cleanup *(L2 -7..-2 종일, **InProgress 인데 마감 지남 = overdue**)*
14. ▸ Cleanup checklist 1 *(자식, Done)*
15. ▸ Cleanup checklist 2 *(자식, **NotStarted 인데 부모는 진행중 = overdue 자식**)*

**C. client-acme (10 tasks)** — milestone driven
16. Phase 1: Discovery *(Done, L3 timed)*
17. Phase 1: Design review *(InProgress, ysh 와 alice 둘 다 배정)*
18. Phase 1: Implementation *(NotStarted, L2 +5..+13)*
19. Phase 1: QA pass *(NotStarted, L2 +13..+14, carol QA 배정)*
20. ... (총 10건 유사 분포)

**D. spike-mcp (1 task)** — 거의 빈 프로젝트
26. Initial RFC *(NotStarted)*

**E. archived-legacy (4 tasks)** — 모두 Done. archived 필터 검증
27..30. 모두 Done, 과거 일자

**총: 30 tasks 내외, 부모-자식 관계 포함**

### 3.8 Assignments (50+)

오버로드 시나리오 의도적 삽입:
- **ysh** : (오늘+0~+3) 누적 110% 초과 — 매트릭스 빨강 ⚠ 표시 검증
- **dev-01** : (오늘-1~+1) 100% 정확 — 노랑 경계
- **alice** : (오늘+5~+10) 50% 정도 — 초록 안전
- **carol** : (오늘+13~+14) 60% — QA pass 단기 집중
- **bob**, **researcher-01**, **qa-01** : 분산 배정

업무일 외 (Sat/Sun) 에는 의도적으로 배정 안 함 (WorkCalendar 검증).

### 3.9 ChangeLog (자동 누적)
seed 가 아니라 task 들이 위 시나리오대로 만들어지는 과정에서 자연 누적:
- task #2 ("Backend CRUD") 가 L2 시작일 1회 변경 → 1건
- task #3 ("Frontend foundation") 가 L2 종료일 +3일 미룸 (3회 revision) → 3건
- task #12 ("Cron rollback") 가 사고 시나리오로 5건 누적
- 총 25~30 건의 change log 가 깔려서 "Recent changes" 섹션이 비어 보이지 않음

### 3.10 Agent plan history (Phase 1.5 prelude, optional)
seed 가 schema-integration-for-agents.md PR3 전이라면 생략. 이미 들어간 상태라면:
- task #5 ("Agent identity") 에 v1 plan (researcher-01 제출, PlanReview), v2 (revised, ysh 가 1회 reject), v3 (PlanApproved by ysh)

## 4. Dev-mode "현재 사용자" 스위처

**문제**: M1 시점에는 token 기반 auth 가 미구현 (M2). 권한 시연 위해 임시 메커니즘 필요.

**해법**:
- Flutter `currentUserProvider: StateProvider<String?>` 가 현재 user resource id 보유
- 좌측 sidebar 하단에 user picker (드롭다운). 클릭 → 다른 사용자로 전환
- 모든 RBAC-게이트된 UI 어포던스 (`canApprovePlan`, `canEditWorkCalendar` 등) 가 이 provider 의 RBAC preset 을 참조해 표시 / 숨김 결정
- **데이터 가시 범위 (§3.4)** 도 이 provider 가 결정. provider 변경 시 모든 list/gantt/matrix 데이터가 재필터링되어 즉시 반영 (Riverpod 의존성으로 자동)
- backend 호출 시 헤더에 `X-Dev-User-Id: <resourceId>` 추가. backend 는 dev mode 일 때만 이 헤더로 신원 결정 (token 검증 우회). 가시 범위 필터링은 endpoint 응답 단계에서 적용 → 클라이언트는 *볼 수 있는 것만* 받음
- 본 메커니즘은 **개발 / dogfooding 전용**. M2 진입 시 token-based 와 swap-out

UI 표기:
```
+------------+
| Sidebar    |
| ...        |
| ▸ Settings |
+------------+
| 👤 ysh ▾   |   ← 현재 사용자 표시. 클릭 시 dropdown
|   Manager  |
+------------+
```
드롭다운 항목:
```
Switch user (dev only)
─────────────────────
● ysh        Manager
○ alice     Developer
○ bob       Reviewer
○ carol      QA
```

## 5. 적재 방법

### 5.1 추천: dev-only HTTP endpoint
```
POST /api/dev/seed
  body: { "wipe": true }   // optional, default false
```
- Development 환경에서만 등록 (`if (app.Environment.IsDevelopment())`)
- `wipe=true` 면 모든 컬렉션 비우고 재생성. `wipe=false` 면 빈 DB 일 때만 적재
- 응답 = 생성된 entity 카운트

### 5.2 대안: dotnet flag
```
dotnet run -- --seed --wipe
```
- 적재 후 종료 (서버 시작 안 함). CI / 부팅 직전 사용

### 5.3 시점
- 본 문서의 다음 단계인 "seed loader 구현" task 에서 5.1 (HTTP endpoint) 만 우선 구현. 5.2 는 필요시 추가

## 6. 검증 체크리스트
seed 적재 후 UI 가 다음을 보여줘야 (모두 표시되면 와이어프레임 검증 완료):

### 6.1 데이터 / 표현
- [ ] 좌측 sidebar 에 7개 resource (사람 4 + agent 3), 5개 project (Manager 시점)
- [ ] My work 진입 화면이 비어 보이지 않음 (오늘 또는 이번 주에 진행중 task 다수)
- [ ] All work List: 30개 정도 task. 부모-자식 들여쓰기 보임
- [ ] All work Gantt: Day / Week / Month 줌 모두 막대 그려짐. Day 줌에서 timed task 의 부분 폭 확인
- [ ] All work Calendar Month: 종일 task 막대 + 시간 task ◷ 라벨 동시 보임
- [ ] All work Calendar Week (b): 상단 all-day band + 시간대 grid 박스 동시 보임. 비업무일 컬럼 옅은 회색
- [ ] Resource matrix (Manager): ysh ⚠ 빨강, dev-01 노랑, alice 초록, Sat/Sun 옅은 회색
- [ ] Inspector — task: L1 종일 / L3 timed 두 표현 다른 것 확인
- [ ] Inspector — change log: task #12 (Cron rollback) 에 5건 누적 보임
- [ ] Milestones 섹션: 임박 / 지난 / 미래 모두 표시
- [ ] Archived 프로젝트는 기본 필터에서 숨김 (토글로 표시)

### 6.2 권한 어포던스 (ysh ↔ alice 전환)
- [ ] **ysh (Manager)** 시점: "Approve plan" / "Reject" / "Revise" 버튼 활성, WorkCalendar 설정 진입 가능
- [ ] **alice (Developer)** 시점: 같은 버튼들 disabled / 숨김. WorkCalendar 설정 진입 불가 (sidebar Settings 항목 자체 숨김)

### 6.3 데이터 가시 범위 (ysh ↔ alice 전환)
- [ ] **ysh (Manager)** : 좌측 sidebar 에 5 프로젝트 모두, 리소스 7명 모두, 매트릭스 7행 모두
- [ ] **alice (Developer)** : 좌측 sidebar 에 본인 할당 있는 2~3 프로젝트만, 다른 프로젝트는 안 보임
- [ ] **alice** : All work 에서 본인 task + 부모만, 형제 / 다른 갈래 안 보임. 부모는 read-only 표시 (편집 불가)
- [ ] **alice** : Resource matrix 에 본인 1행만 표시
- [ ] **alice** : Inspector 에서 같은 task 의 다른 assignee 는 익명 칩 (`👤 ✱`) 표시
- [ ] **bob (Reviewer)** : 전체 가시 (검토 권한). 단 task 편집 / status 변경 어포던스는 비활성

## 7. 다음 단계
1. 본 문서 검토 → 시나리오 양 / 케이스 추가/제거
2. seed loader 구현:
   - 스키마 보강 (Resource.Kind/Rbac, Timeline.IsAllDay, WorkCalendar 신규)
   - `POST /api/dev/seed` 작성
   - 통합 테스트 (적재 후 모든 endpoint 응답 정상)
3. UI 재구현 (와이어프레임 §4 순서: AppShell → Inspector → 핵심 뷰)

## 8. 관련 문서
- [wireframes.md](wireframes.md) — 데스크톱 UI
- [ADR-004 Agent Identity & RBAC](../architecture/ADR-004-agent-identity-and-api.md) — 5 프리셋 권한 표
- [ADR-009 timeline timestamps + WorkCalendar](../architecture/ADR-009-timeline-timestamps-allday-workcalendar.md)
- [ADR-006 BYOA 온보딩 UX](../architecture/ADR-006-byoa-onboarding-ux.md) — agent 등록 UX
- [planning/TODO.md](../planning/TODO.md) Phase 1.5 PR2 / PR3
