# mora-knode 스키마 통합 계획 (외부 AI 에이전트 host 지원)

- 상태: planned (2026-04-29 외부 에이전트 host 모델로 일반화 재작성)
- 날짜: 2026-04-23 (최초), 2026-04-29 (재작성)
- 대상: mora-knode 의 C# 도메인 모델, Repository, Endpoint
- 연관: [ADR-002 (Plan 게이트)](ADR-002-manager-approval-gate.md), [ADR-004 (Agent Identity & API)](ADR-004-agent-identity-and-api.md), [ADR-005 (LLM 비차별 원칙)](ADR-005-mora-knode-does-not-orchestrate-llms.md)

## 목적

mora-knode 가 외부 AI 에이전트의 협업 host 가 되기 위해 필요한 **mora-knode 측 스키마/API 변경안**을 정의한다. mora-knode 는 LLM 을 호출하지 않으며 (ADR-005), 외부 에이전트는 mora-knode REST API 만 호출한다 (MongoDB 직접 접근 금지).

## 전제
- 작업 순서: M1 (2026-05-07) 완성 → **M1과 M2 (2026-06-15) 사이** PR 1~5 반영 → M2 외부 에이전트 dogfooding 시작 → Phase 2 확장 시 PR 6 (Flutter)
- 모든 변경은 MongoDB 데이터에 대해 forward-compatible (신규 필드 null 허용, enum 뒤로만 추가)
- agent identity 명명: 옛 `Manager_Agent`, `Developer_Agent` 등 고유 명사 → 임의 agent identifier (사용자 운영) 로 일반화

## 기존 도메인 재활용 매핑

| 외부 에이전트 협업 개념 | mora-knode 모델 | 비고 |
|---|---|---|
| 에이전트 식별자 | `Resource` | `Kind=Agent` 필드 추가 |
| 사용자/에이전트 요청 task | `TaskItem` | 필드 추가 |
| Manager 하위 분해 | `TaskItem.ParentTaskId` | 스키마 변경 불필요 |
| 초기 추정 타임라인 | `TaskItem.OriginTimeline` | 재활용 |
| 진행 중 조정 | `TaskItem.CurrentTimeline` | 재활용 |
| 실제 완료 | `TaskItem.RealTimeline` | 재활용 |
| 에이전트 간 배정 | `Assignment` | 재활용 |
| 일정 변경 이력 | `ScheduleChangeLog` | `ChangedBy=<agent-id 또는 user-id>` |

## PR 1 — Enum 확장

파일: [src/backend/Domain/Enums.cs](../../src/backend/Domain/Enums.cs)

### `TaskStatus` 확장
```csharp
public enum TaskStatus
{
    NotStarted,      // 0 (기존)
    InProgress,      // 1 (기존)
    Blocked,         // 2 (기존)
    Done,            // 3 (기존)
    // 이하 추가. 기존 값 뒤로만 추가해 정수 매핑 하위 호환 유지
    PlanDrafting,    // 4
    PlanReview,      // 5
    PlanApproved,    // 6
    Failed,          // 7
    Cancelled        // 8
}
```

### `ResourceKind` 신설
```csharp
public enum ResourceKind
{
    Human,
    Agent
}
```

### 테스트
- 기존 `TaskStatus` 정수 값 매핑 회귀 테스트 (0=NotStarted, 1=InProgress 확인)
- 기존 Repository 메서드 동작에 영향 없음 확인

## PR 2 — TaskItem / Resource 필드 추가

### [src/backend/Domain/TaskItem.cs](../../src/backend/Domain/TaskItem.cs)
```csharp
public List<string>? AcceptanceCriteria { get; set; }  // plan 제출 시 외부 에이전트가 기록
public GitInfo? Git { get; set; }                       // 실행 시 외부 에이전트가 기록
public int RetryCount { get; set; } = 0;
public string? LastError { get; set; }
public string? AssignedRoleHint { get; set; }           // work-queue 필터링용 hint (자유 텍스트)
```

### 신규 value type: `src/backend/Domain/GitInfo.cs`
```csharp
using MongoDB.Bson.Serialization.Attributes;

namespace MoraKnode.Domain;

public class GitInfo
{
    public string? Branch { get; set; }
    public string? BaseBranch { get; set; }
    public string? CommitHash { get; set; }
    public string? PrUrl { get; set; }
}
```

### [src/backend/Domain/Resource.cs](../../src/backend/Domain/Resource.cs)
```csharp
public ResourceKind Kind { get; set; } = ResourceKind.Human;
public string? AgentDescription { get; set; }  // 자유 텍스트 — 운영자가 식별 용도
// 옛 AgentModel 필드는 ADR-005 비차별 원칙에 따라 도입하지 않음
```

### 마이그레이션
- MongoDB 는 누락 필드를 null/default 로 읽음. 기존 레코드 마이그레이션 불필요
- 단, `Resource.Kind` 의 기본값 `Human` 이 기존 레코드에서도 적용되도록 확인

## PR 3 — 신규 도메인 + Repository

### [src/backend/Domain/AgentPlanHistory.cs]
```csharp
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace MoraKnode.Domain;

public class AgentPlanHistory
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = null!;

    [BsonRepresentation(BsonType.ObjectId)]
    public string TaskId { get; set; } = null!;

    public int Version { get; set; }

    public string PlanContent { get; set; } = string.Empty;  // JSON 문자열 or Markdown — 형식 자유

    public string? UserFeedback { get; set; }

    public PlanStatus Status { get; set; } = PlanStatus.Draft;

    public string CreatedBy { get; set; } = string.Empty;  // <agent-id> or <user-id>

    public DateTime CreatedAt { get; set; }
    public DateTime? ApprovedAt { get; set; }
    public string? ApprovedBy { get; set; }   // 누가 approve 했는지 (사람 user-id 권장)
}

public enum PlanStatus
{
    Draft,
    Rejected,
    Approved,
    Superseded
}
```

### [src/backend/Domain/AgentRun.cs]
```csharp
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace MoraKnode.Domain;

public class AgentRun
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = null!;

    [BsonRepresentation(BsonType.ObjectId)]
    public string TaskId { get; set; } = null!;

    public string AgentId { get; set; } = string.Empty;  // ADR-004 의 Resource id

    // 이하 모두 optional — 외부 에이전트가 *선택적으로* 제출 (ADR-005)
    // mora-knode 는 보존만, 검증/측정/과금 안 함
    public string? Model { get; set; }       // 예: "claude-opus-4-7" — 외부 도구가 자기 기록용 제출
    public int? InputTokens { get; set; }
    public int? OutputTokens { get; set; }
    public decimal? CostUsd { get; set; }

    public DateTime StartedAt { get; set; }
    public DateTime? CompletedAt { get; set; }

    public AgentRunStatus Status { get; set; } = AgentRunStatus.Running;
    public string? Error { get; set; }
}

public enum AgentRunStatus
{
    Running,
    Success,
    Failed,
    Aborted
}
```

### [src/backend/Infrastructure/MongoContext.cs] 컬렉션 핸들 추가
```csharp
public IMongoCollection<AgentPlanHistory> AgentPlans =>
    Database.GetCollection<AgentPlanHistory>("agentPlans");

public IMongoCollection<AgentRun> AgentRuns =>
    Database.GetCollection<AgentRun>("agentRuns");
```

### 신규 Repository
- `src/backend/Infrastructure/AgentPlanRepository.cs`
- `src/backend/Infrastructure/AgentRunRepository.cs`

기존 `ProjectRepository`, `TaskRepository` 패턴 그대로.

필수 메서드 (`AgentPlanRepository`):
- `GetLatestAsync(taskId)` — 최신 version
- `GetAllVersionsAsync(taskId)` — 히스토리
- `GetPendingReviewsAsync()` — `TaskItem.Status=PlanReview` 인 것들의 최신 plan
- `AppendAsync(taskId, content, createdBy)` — 새 version (이전 Approved 는 Superseded 로)
- `ApproveAsync(planId, approvedBy)` — Status=Approved + TaskItem Status=PlanApproved
- `RejectAsync(planId, feedback)` — 이 버전 Rejected 마킹

필수 메서드 (`AgentRunRepository`):
- `StartAsync(...)` / `CompleteAsync(...)` / `FailAsync(...)`
- ~~`GetDailyCostAsync(date)`~~ — **삭제** (ADR-005: mora-knode 는 비용 측정 안 함). 외부 도구가 자기 메트릭 제출 시 보존만

### 인덱스
```
agentPlans: { taskId: 1, version: -1 }
agentRuns:  { taskId: 1, startedAt: -1 }
agentRuns:  { agentId: 1, startedAt: -1 }   // 에이전트별 실행 이력 조회용
```

## PR 4 — Agent Endpoints

### [src/backend/Endpoints/AgentEndpoints.cs] 신설
인증: 모든 endpoint 는 `Authorization: Bearer <agent-token>` + `X-Agent-Id` 헤더 검증 (ADR-004).

```
# Agent identity / 토큰 (운영자 / 사람만)
POST   /api/agents                               # 신규 agent identity 등록
GET    /api/agents                               # 목록
POST   /api/agents/{agentId}/tokens              # 토큰 발급 (이전 무효화)
DELETE /api/agents/{agentId}/tokens              # 즉시 회수
PUT    /api/agents/{agentId}/permissions         # RBAC 갱신

# Plan 게이트 (외부 에이전트 + 사람 사용)
GET    /api/agents/plans/pending                 # 검토 대기 목록
GET    /api/agents/plans/{taskId}                # 모든 버전 + 최신
POST   /api/agents/plans/{taskId}/versions       # 새 버전 제출 (submit plan 권한)
POST   /api/agents/plans/{taskId}/approve        # approve plan 권한 — 기본 사람만
POST   /api/agents/plans/{taskId}/revise         # body: { "feedback": "..." }
POST   /api/agents/plans/{taskId}/reject

# Work-queue (외부 에이전트가 자기 task pull)
GET    /api/agents/work-queue                    # 자기 token 의 agent 에게 pending
GET    /api/agents/work-queue?status=PlanApproved&role=Developer
POST   /api/agents/work-queue/{taskId}/claim     # lock 획득, Status=InProgress
POST   /api/agents/work-queue/{taskId}/release   # lock 반환

# 실행 메트릭 (외부 에이전트가 자기 실행 기록 — 모두 optional)
POST   /api/agents/runs                          # 실행 시작 보고
PUT    /api/agents/runs/{runId}/complete         # 토큰/비용은 optional body
PUT    /api/agents/runs/{runId}/fail
```

승인 / revise / reject 처리 시 `TaskItem.Status` 자동 전이:
- `POST .../approve` → `Status=PlanApproved`, `ApprovedBy` 기록
- `POST .../revise` → `Status=PlanDrafting` (제출자가 다시 받음) → 새 버전 제출 시 `Status=PlanReview`
- `POST .../reject` → `Status=Cancelled`

### Program.cs 라우팅 등록
기존 `ProjectEndpoints`, `TaskEndpoints` 등록 패턴 따라 `AgentEndpoints.Map(app)` 추가.

### 인증
- M1 단계: 로컬 전용 → 토큰 검증은 placeholder (스텁)
- M2 단계: 토큰 검증 + RBAC 적용 (ADR-004)
- 외부 출시 (M3 이후): SSO 통합 (SAML/OIDC) 시 사용자 토큰과 통합

## PR 5 — Flutter 프론트엔드 (Phase 2 이후)

### 간트 뷰
- `Status=PlanReview` task 를 별도 색/아이콘으로 표시 ("검토 대기" 배지)
- 클릭 시 plan 리뷰 패널 열림

### 태스크 상세 패널
- "Plan History" 탭: `AgentPlanHistory` 버전 목록 + diff + approve/revise/reject 버튼
- "Runs" 탭: `AgentRun` 로그 (시간 / agent id / 선택적 토큰 / 선택적 비용)

### 매트릭스 리소스 매니저
- `Resource.Kind=Agent` Resource 에 로봇 아이콘 표시
- AgentDescription 으로 검색 / 필터

### Agent 관리 화면 ([ADR-006](ADR-006-byoa-onboarding-ux.md))
- agent identity 등록 (UI form, CLI 안 함) / 토큰 발급 / RBAC 5 프리셋
- 환경변수 자동 generator + 외부 도구별 셋업 가이드 (Claude Code / Cursor / Python / curl) — 실제 토큰 채워진 상태로 복사
- 토큰 회전 / 회수 버튼
- 5분 셋업 UX 목표 (등록 → 외부 도구 첫 polling)

### 우선순위
M2 외부 에이전트 dogfooding 은 CLI / curl / 외부 도구 자체 UI 로 가능. Flutter 통합은 Phase 2 확장 (Stage 1) 진입 후.

## PR 6 (선택, M3 이후) — Push 모드

Stage 0/1 의 polling 기반 work-queue 가 외부 에이전트의 latency / quota 부담이 될 경우:
- MongoDB Change Streams 기반 SSE/WebSocket endpoint 추가
- `GET /api/agents/work-queue/stream` (Server-Sent Events)
- 외부 에이전트가 polling 대신 stream subscribe 가능

## 롤백 전략
- 각 PR 독립 롤백 가능 (앞 PR 의 필드/enum 값은 뒤 PR 에서만 사용)
- 롤백 시 MongoDB 신규 필드는 null 처리 → 기존 기능 영향 없음
- PR 1 의 `TaskStatus` 확장값을 사용한 레코드가 있으면 롤백 후 읽기 오류 → 해당 레코드 존재 여부 확인 필요

## 위험과 완화

| 위험 | 완화 |
|---|---|
| Enum 순서 변경으로 기존 매핑 깨짐 | 기존 4개 값 선언 순서/정수 유지. 신규는 뒤로만. 회귀 테스트 필수 |
| 외부 에이전트가 MongoDB 직접 접근 시도 | 금지. REST 만 호출. mora-knode 측 토큰 미검증 시 거부 |
| `PlanContent` 비대화 | MongoDB 16MB 제한은 여유. 목록 조회 시 Projection 으로 제외 |
| Work-queue lock race | claim 시 atomic update + version 필드. release 미호출 시 timeout (Phase 2) |
| M1 개발 중 스키마 변경 충돌 | **M1 완료 전까지 이 변경 금지**. M1과 M2 사이 1주에 반영 |
| 외부 에이전트가 기능을 잘못 사용 | docs / agent-operations.md 가이드 + 명확한 에러 메시지 |

## 검증 (각 PR 공통)
- `dotnet build` 성공
- 기존 CRUD API 회귀 테스트 (Project / Task / Milestone / Resource / Assignment)
- 신규 endpoint 는 curl / httpie 수동 테스트 체크리스트
- 외부 에이전트 시뮬레이션: agent identity 등록 → 토큰 발급 → curl 로 plan 제출 → 사람 approve → work-queue claim → status 갱신 end-to-end
