# ADR-009: Timeline 은 timestamp · 종일 모드 토글 · WorkCalendar 도입

- 상태: Accepted
- 날짜: 2026-04-30
- 연관: [PRD](../prd.md) §4 In-scope (3단계 타임라인), [ADR-008 Flutter Web 데스크톱 only](ADR-008-flutter-web-desktop-only.md), [docs/design/wireframes.md](../design/wireframes.md)

## Context

현재 `Timeline { Start: DateTime?, End: DateTime? }` 는 *날짜* 의미로만 쓰이고 있음 (UI 가 `yMMMd` 포맷, 입력은 `showDateRangePicker`). 하지만:

1. **소요 시간이 곧 업무 성과 신호** — L3 Real 의 actual hours 를 알아야 revision 메트릭 옆에 "예상 vs 실제 시간" 비교가 됨. 일자만으로는 "Apr 25 하루" 가 1시간 작업인지 8시간 작업인지 구분 불가
2. **매트릭스 로드 정확도** — 현재 로드 % 는 단순 일자 overlap. 업무 시간 (9~18시) 기준으로 부분 시간 task 를 정확히 환산하려면 timestamp 데이터가 필요
3. **캘린더 Week 뷰 (b)** — Outlook/Google Cal 식 시간 슬롯 grid 는 timestamp 없이 작동 불가
4. **외부 에이전트 관점** — agent 가 "오늘 9:30~14:00 작업" 같은 정밀 보고를 하기 시작하면 일자 단위로 깎으면 정보 손실

다만 *모든 task 가 시간을 입력해야 하는 강제* 는 마찰. 대다수의 plan 단계 (L1/L2) 는 "그날 하루" 로 충분.

## Decision

### 1. Timeline = timestamp + IsAllDay 플래그 (timeline 단위)

`Timeline` 클래스를 다음으로 확장:
```csharp
public class Timeline
{
    public DateTime? Start { get; set; }   // 항상 UTC timestamp
    public DateTime? End   { get; set; }   // 항상 UTC timestamp
    public bool IsAllDay { get; set; } = true;  // default: 종일
}
```

- `IsAllDay = true`: Start/End 는 그 날의 00:00:00.000 / 23:59:59.999 UTC 로 **저장 시 자동 정규화**. UI 는 *날짜만* 표시
- `IsAllDay = false`: Start/End 는 명시적 timestamp. UI 는 *날짜 + 시:분*
- 플래그는 **timeline 단위** (L1/L2/L3 각각 독립). 예: L1 베이스라인 = "Apr 25 종일", L2 plan = "Apr 25 종일", L3 real = "Apr 25 9:30~14:00 timed". 자연스러움

### 2. 기본값 / 자동 정규화 규칙

- 사용자가 `IsAllDay=true` 로 날짜만 줬을 때 (시간 미입력):
  - Start → `Date.AddTicks(0)` (00:00:00.000 UTC)
  - End → `Date.AddDays(1).AddTicks(-1)` (23:59:59.999 UTC)
- 사용자가 `IsAllDay=false` 로 시간을 명시적으로 줬는데 시간 부분이 마침 00:00:00 이거나 23:59:59 이어도 그대로 보존 (사용자가 의도해서 그 시각으로 입력한 것이므로)
- 정규화는 **backend 에서 단방향** (POST/PUT 받을 때). 프런트는 UI 입력만 정규화 안 함

### 3. WorkCalendar — 글로벌 1개 (org-level), MVP

신규 엔터티 `WorkCalendar` 를 신설. 컬렉션 `work_calendar` 에 **단일 document** (id 고정 또는 always-first):
```csharp
public class WorkCalendar
{
    public string Id { get; set; } = "default";   // singleton convention
    public WorkDayMask WorkDays { get; set; } = WorkDayMask.MonToFri;
    public TimeOnly DailyStart { get; set; } = new(9, 0);
    public TimeOnly DailyEnd   { get; set; } = new(18, 0);
    public string Timezone { get; set; } = "Asia/Seoul";
}

[Flags]
public enum WorkDayMask {
    Mon = 1, Tue = 2, Wed = 4, Thu = 8, Fri = 16, Sat = 32, Sun = 64,
    MonToFri = Mon | Tue | Wed | Thu | Fri,
    All = MonToFri | Sat | Sun
}
```

- Per-resource override 는 **M2 이후**. 초기엔 단일 글로벌
- Document 가 없으면 fallback = **24/7** (모든 요일, 00:00~23:59:59). 즉 user 가 "매트릭스 합산 안 함" 의 의미로 비워둘 수 있음

### 4. 매트릭스 로드 계산 변경

기존: `min(end, dayEnd) - max(start, dayStart)` 의 일 단위 overlap → allocationPercent

신규:
1. 그 날이 WorkDays 에 포함 안 되면 load = 0
2. WorkCalendar 의 work hours window 와 task timeline 의 overlap 시간 (분 단위) 계산
3. `loadPercent = (overlapMinutes / dailyWorkMinutes) * allocationPercent`
4. 종일 task on 업무일 → `dailyWorkMinutes / dailyWorkMinutes * allocation` = `allocation%` (현재 동작과 동일)
5. WorkCalendar 미설정 (24/7 fallback) → daily window = 24h, allocationPercent 그대로

이렇게 하면 종일 task 만 쓰는 사용자는 *현재 매트릭스 동작과 동일한 결과* 를 보고, 시간 task 를 도입한 사용자만 정밀해짐.

### 5. UI 정책

- **TaskEditor**: 각 timeline (Origin/Current/Real) 옆에 *종일 토글*. 토글 ON = date range picker, OFF = date+time picker. 신규 task 의 default 는 ON
- **GanttChart**: Day 줌에서 시간 task 는 일자 셀 안의 부분 폭으로 표현. Week / Month 줌에서는 일자 단위로 합산해 표시 (Day 줌이 아니면 정밀 시간 보이지 않음). 종일 task 는 항상 셀 가득 채움
- **Calendar Week 뷰**: 시간 grid (8AM~8PM 기본, WorkCalendar 의 DailyStart-1h ~ DailyEnd+1h 로 자동 조정). 종일 task 는 상단 "all-day" 영역에 가로 막대로 별도 표시 (Outlook 패턴)
- **WorkCalendar 설정 UI**: 좌측 nav 의 Settings 진입 (M1.5+). 미설정 상태 표시 = "24/7 — load metrics treat all hours as working hours"

### 6. 마이그레이션

기존 데이터 (현재 5개 정도의 task / assignment) 는:
- `Timeline` document 들에 `isAllDay` 가 누락되어 있을 것 → MongoDB BSON 직렬화는 missing 필드를 default 로 처리 (`true`). 그러므로 **기존 데이터는 자동으로 종일 모드로 해석**. 별도 마이그레이션 스크립트 불필요
- Start/End 가 이미 timestamp 형식이라 추가 변환 없음
- WorkCalendar document 도 없음 → fallback 으로 24/7 동작. 사용자가 UI 에서 세팅하는 시점에 문서 생성

## Rationale

### 왜 timeline 단위 IsAllDay (task 단위 아님)

- L1 (베이스라인) 은 견적 / 계획 단계 → 종일 단위가 자연스러움
- L3 (실제) 는 측정 데이터 → 시간 task 가 자연스러움
- 사람이 plan 할 때와 agent 가 실제 시간 보고할 때의 표현 단위가 달라야 함
- 통합하면 "L1 도 시간 강제" 가 되거나 (마찰), "L3 도 종일" 이 되어 (정보 손실), 양쪽 다 손해

### 왜 WorkCalendar 가 글로벌 1개부터

- 1인 dogfooding (ysh) 단계에서는 timezone / 업무시간이 단일
- per-resource 캘린더는 매트릭스 계산 / UI / 충돌 검증 코드를 모두 N 배로 만듦. M2 이후 dogfooding 데이터 보고 결정
- 단일 글로벌 + 미설정 fallback 으로 "캘린더 신경 안 쓰면 현재와 동일 동작" 보존

### 왜 마이그레이션이 자동인가

- BSON deserializer 는 누락 필드를 C# default 로 채움 (`bool default = false`)
- ⚠️ 그러므로 코드에서 `IsAllDay` 의 *모델 default 를 명시적으로 `= true`* 로 박아야 함 (POCO 초기화 default). C# 객체 초기화 시 그 값이 쓰이고, BSON deserialization 시에도 missing 필드는 그 default 로 채워짐 (BSON 옵션 따라 다를 수 있어 검증 필요)
- 만약 BSON 이 누락 시 `false` 로 채우면 → 마이그레이션 스크립트가 필요 (한 번 돌려서 모든 timeline 의 `isAllDay=true` 채움). 단순 작업

### 왜 23:59:59.999 (마지막 ms) 를 End 로

- 매트릭스 overlap 계산이 "End 가 다음 날 00:00:00" 와 "End 가 23:59:59.999" 의 양쪽 모두 잘 처리되도록 일관성 유지
- 사용자가 직접 시각을 보면 "Apr 25 23:59" 라는 문자열이 "그 날 끝까지" 의미로 명확함 (반면 "Apr 26 00:00" 는 다음 날로 보일 수 있음)

## Consequences

### 긍정적
- 소요 시간 메트릭 가능 → revision 정확도 + 시간 정확도 두 신호로 평가
- 매트릭스 정밀도 ↑
- 종일 모드 default 로 입력 마찰 0
- WorkCalendar 미설정 시 현재와 동일 → 점진 도입

### 부정적
- 매트릭스 로드 계산 코드 한번 다시 작성 (복잡도 ↑)
- TaskEditor UI 가 토글 + 조건부 picker 로 살짝 복잡해짐
- 시간 슬롯 grid (Calendar Week b 옵션) 구현 비용
- BSON serialization 의 missing field default 검증 (C# bool default 와 BSON default 의 불일치 잠재)

### 추가 검증 필요
- [ ] MongoDB C# driver 가 누락 `isAllDay` 필드를 어떻게 처리하는지 통합 테스트로 확인 (default = true 로 채워지는지). false 로 채워지면 명시적 마이그레이션
- [ ] 기존 test 데이터 (현재 DB 의 5개 task) 가 새 코드에서 정상 표시되는지 확인

## 관련 문서
- [PRD](../prd.md) §4 In-scope, §5 P0 (3단계 타임라인 + 매트릭스 리소스 매니저)
- [docs/design/wireframes.md](../design/wireframes.md) §0.1, §4.4 캘린더 모드, §4.7 인스펙터 task
- [planning/TODO.md](../planning/TODO.md)
