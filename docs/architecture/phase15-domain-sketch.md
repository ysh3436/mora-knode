# Phase 1.5 Domain Sketch — agent host + 매트릭스 팀 레이어

- 상태: Frozen for Sat~Tue implementation
- 날짜: 2026-05-01
- 목적: 토~화 코딩 동안 churn 없도록 모든 필드/제약/계약을 사전에 고정.
- 연관 ADR: [002 Plan Gate](ADR-002-manager-approval-gate.md), [004 Agent Identity & API](ADR-004-agent-identity-and-api.md), [006 BYOA UX](ADR-006-byoa-onboarding-ux.md)
- 설계 결정 (Q1~Q6): 2026-05-01 대화 — Token=SHA256+raw1회 / Plan=hybrid steps+notes / 권한=assignment only / 기능팀=단일+트리 / 프로젝트팀=다중+flat (Project 에 필드)

> **MVP 트림 원칙**: 화요일 GitHub public 토글까지 닿는 최소 표면. 풍부한 기능은 v1.1 로 미룸. defer 항목은 각 절 끝에 명시.

---

## 1. 인증 — Agent Token

### 1.1 도메인

신규 엔티티 `AgentToken` — 한 agent (Resource.Kind=Agent) 당 1개 활성 토큰. Rotate 는 새 행 발급 + 옛 행 RevokedAt 셋.

```csharp
// src/backend/Domain/AgentToken.cs (NEW)
public class AgentToken
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = null!;

    [BsonRepresentation(BsonType.ObjectId)]
    public string ResourceId { get; set; } = null!;   // Resource (Kind=Agent) 의 id

    public string TokenHashSha256 { get; set; } = string.Empty;  // hex 64 chars
    public string LastFourChars { get; set; } = string.Empty;    // 표시용 (예: "...3a9f")

    public DateTime CreatedAt { get; set; }
    public DateTime? RevokedAt { get; set; }   // null = active
    public DateTime? LastSeenAt { get; set; }  // 마지막 인증 성공 시점 (telemetry, defer OK)
}
```

### 1.2 토큰 생성

```csharp
// 32 random bytes → URL-safe base64 (43 chars after stripping padding)
var bytes = RandomNumberGenerator.GetBytes(32);
var raw = Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');
var presented = $"mk_{raw}";  // prefix "mk_" 로 깃에 leak 시 검출 용이
```

### 1.3 인증 헤더 (ADR-004 §2)

```
Authorization: Bearer mk_{raw}
X-Agent-Id: <resource-id>     # redundancy. token 의 ResourceId 와 일치해야 함
```

검증 흐름 (middleware):
1. `Authorization` 파싱 → raw token 추출
2. SHA-256 hash 계산
3. AgentToken 컬렉션에서 hash 매칭 + RevokedAt is null 인 1건 찾기
4. `X-Agent-Id` 가 token.ResourceId 와 일치하는지 검증
5. UserContext 에 agent 의 ResourceId 와 RbacPreset 채우기 → ScopeService 가 인식

### 1.4 인덱스
- `AgentToken.TokenHashSha256` — unique
- `AgentToken.ResourceId` — non-unique (rotate 시 옛 토큰 revoked 상태로 남음)

### 1.5 Defer
- LastSeenAt 갱신 (수동 cron / 후속) — 인증마다 update 하면 부하
- 다중 토큰 (한 agent 가 여러 환경에서 동시 사용) — v1 은 1 active

---

## 2. 매트릭스 팀 레이어

### 2.1 기능팀 — `Department` (NEW)

```csharp
// src/backend/Domain/Department.cs (NEW)
public class Department
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = null!;

    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }

    [BsonRepresentation(BsonType.ObjectId)]
    public string? ParentDepartmentId { get; set; }   // 단일 부모 트리

    [BsonRepresentation(BsonType.ObjectId)]
    public string? LeadResourceId { get; set; }       // 부서장 (선택)

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
```

검증 (application 단):
- `ParentDepartmentId` 가 자기 자신이거나 자손이면 거부 (cycle 방지)

### 2.2 Resource 의 단일 부서 멤버십

```csharp
// src/backend/Domain/Resource.cs — ADD
[BsonRepresentation(BsonType.ObjectId)]
public string? DepartmentId { get; set; }
```

### 2.3 프로젝트 팀 — `Project.MemberResourceIds`

기존 Project 엔티티에 필드 추가. 별도 엔티티 X.

```csharp
// src/backend/Domain/Project.cs — ADD
[BsonRepresentation(BsonType.ObjectId)]
public List<string> MemberResourceIds { get; set; } = new();
```

### 2.4 Matrix endpoint 필터

```
GET /api/matrix?from=...&to=...
GET /api/matrix?from=...&to=...&departmentId=xxx       # 부서로 좁힘 (해당 부서 멤버만)
GET /api/matrix?from=...&to=...&projectId=xxx          # 프로젝트로 좁힘 (해당 프로젝트 멤버만)
```

응답 row 에 `departmentId` 필드 추가 (프론트에서 group 가능). `projectId` 별 카운트는 응답 메타에 옵션 (defer).

### 2.5 Defer (v1.1 으로)
- 부서 단위 capacity / allocation 합계 위젯
- Project 멤버 외에 직접 task assignment 없는 멤버를 합산에 포함할지 정책
- DAG (다중 부모 부서) 지원

---

## 3. Plan Gate

### 3.1 도메인 — `AgentPlan` (NEW)

```csharp
// src/backend/Domain/AgentPlan.cs (NEW)
public class AgentPlan
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = null!;

    [BsonRepresentation(BsonType.ObjectId)]
    public string TaskId { get; set; } = null!;   // 대상 task

    [BsonRepresentation(BsonType.ObjectId)]
    public string SubmittedByResourceId { get; set; } = null!;   // agent or human

    [BsonRepresentation(BsonType.String)]
    public PlanStatus Status { get; set; } = PlanStatus.PendingReview;

    public string Title { get; set; } = string.Empty;          // 짧은 요약 (한 줄)
    public int? EstimateMinutes { get; set; }

    public List<PlanStep> Steps { get; set; } = new();          // hybrid: 분리된 step
    public string? Notes { get; set; }                          // hybrid: markdown 자유

    public string? ReviewerComment { get; set; }                // 거부 사유 등
    [BsonRepresentation(BsonType.ObjectId)]
    public string? ReviewedByResourceId { get; set; }
    public DateTime? ReviewedAt { get; set; }

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public class PlanStep
{
    public string Description { get; set; } = string.Empty;
    public int? EstimateMinutes { get; set; }
}

public enum PlanStatus
{
    PendingReview,
    Approved,
    Rejected
}
```

### 3.2 상태 전이

```
[Draft (client only)] → POST /plans → PendingReview
PendingReview → PUT /approve  → Approved   (사람만 가능, 본인 RBAC.approveplan=true)
PendingReview → PUT /reject   → Rejected   (사유 필수)
Approved / Rejected: terminal — 새 plan 제출이 사실상의 revision
```

### 3.3 권한
- POST /plans: 본인이 assignment 갖는 task 에 대해서만 (Q3 strict)
- PUT /approve, /reject: RbacPreset.Human 만 (또는 Manager + 명시 권한 — v1 은 Human only)
- GET /plans: 본인이 submit 한 것 + 본인이 review 자격 있는 것

### 3.4 인덱스
- `AgentPlan.TaskId` — non-unique
- `AgentPlan.SubmittedByResourceId` — non-unique
- `AgentPlan.Status` — non-unique (review queue 조회)

### 3.5 Defer
- Revision history (한 task 에 여러 plan version) — v1 은 동일 task 에 새 PendingReview 가 단순 누적
- Plan diff 시각화
- Approval 권한을 agent 에게 위임 (Reviewer agent)

---

## 4. Work-queue

### 4.1 endpoint
```
GET /api/agents/work-queue
  → 토큰으로 인증된 agent 의 ResourceId 로 Assignment 조회
  → 그 task 들 + 각 task 의 latest AgentPlan (있으면) 묶어서 응답
```

응답 구조 (예시):
```json
[
  {
    "task": { "id": "...", "number": 31, "title": "TaskItem 5 필드 추가", "status": "InProgress", ... },
    "latestPlan": { "id": "...", "status": "Approved", "title": "..." }
  }
]
```

### 4.2 Defer
- claim/release 락킹 (한 task 를 한 agent 가 잡으면 다른 agent 못 가져감)
- assignment 외 자율 풀링

---

## 5. Middleware / RBAC 확장

### 5.1 UserContextMiddleware

```csharp
// 의사 코드
if (Authorization 헤더에 Bearer 있음) {
    raw = parse(Authorization)
    hash = sha256(raw)
    token = await tokens.Find(t => t.TokenHashSha256 == hash && t.RevokedAt == null).FirstOrDefault()
    if (token == null) return 401
    if (X-Agent-Id != token.ResourceId) return 401
    var resource = await resources.Get(token.ResourceId)
    userContext.ResourceId = resource.Id
    userContext.Rbac = resource.Rbac
    userContext.Kind = ResourceKind.Agent
} else if (X-Dev-User-Id 있음) {  // 기존 dev mode
    ...기존...
}
```

### 5.2 ScopeService 확장
- `Kind == Agent` 인 caller 의 `AccessibleTaskIdsAsync` 는 본인이 assigned 된 task 만 반환 (현행과 동일 RBAC 매핑이지만 명시)
- Project 접근: agent 가 멤버인 프로젝트만 (Project.MemberResourceIds 에 포함)

### 5.3 RbacPreset 액션 매핑 (런타임 단순 분기)

| Preset | view tasks | submit plan | update task status | approve plan | manage agents |
|---|:---:|:---:|:---:|:---:|:---:|
| Human | own + admin if anonymous | own assigned | own assigned | ✓ | ✓ |
| Manager (agent) | own assigned | ✓ | ✗ (자기 task 만) | ✗ | ✗ |
| Reviewer (agent) | own assigned | ✗ | ✗ | ✗ (v1 은 Human 만) | ✗ |
| Developer (agent) | own assigned | ✓ | ✓ | ✗ | ✗ |
| QA (agent) | own assigned | ✓ | ✓ | ✗ | ✗ |

- v1 은 *agent 의 approve plan = 항상 ✗*. 사람만 승인.
- agent 의 manage agents = 항상 ✗. 토큰 발급은 사람 admin 만.

---

## 6. Endpoints 요약

신규:
```
POST   /api/agents                           # admin: agent identity 생성 + 토큰 1회 응답
GET    /api/agents                           # admin: 리스트
GET    /api/agents/{id}                      # admin: 상세
DELETE /api/agents/{id}                      # admin: agent 비활성 + 토큰 모두 revoke
POST   /api/agents/{id}/rotate-token         # admin: 토큰 rotate, 새 raw 1회 응답

POST   /api/agents/plans                     # agent or human: plan 제출
GET    /api/agents/plans?status=PendingReview  # human: review queue
GET    /api/agents/plans/{id}                # 상세
PUT    /api/agents/plans/{id}/approve        # human only
PUT    /api/agents/plans/{id}/reject         # human only, 사유 필수

GET    /api/agents/work-queue                # agent: 본인 assigned task + 최신 plan

POST   /api/departments                      # CRUD
GET    /api/departments
GET    /api/departments/{id}
PUT    /api/departments/{id}
DELETE /api/departments/{id}

POST   /api/projects/{id}/members            # 추가 (resourceId)
DELETE /api/projects/{id}/members/{rid}      # 제거
```

수정:
```
GET /api/matrix  -- ?departmentId / ?projectId 필터 추가
Resource POST/PUT  -- DepartmentId 필드 수용
Project POST/PUT   -- MemberResourceIds 필드 수용
```

---

## 7. 마이그레이션 영향

신규 엔티티 (AgentToken, Department, AgentPlan): 빈 컬렉션으로 시작, 마이그레이션 불필요.

기존 도큐먼트 영향:
- `Resource.DepartmentId`: BSON 누락 시 null 로 deserialize → 기존 resource 들은 자동으로 무소속 ✓
- `Project.MemberResourceIds`: 누락 시 빈 list → 기존 프로젝트는 멤버 없음 ✓

마이그레이션 스크립트 불필요. UI 만 새 필드 채우면 됨.

---

## 8. 구현 순서 (체크리스트)

### 토 (PR α — backend agent identity + 팀 레이어)
- [ ] `Domain/AgentToken.cs` 생성
- [ ] `Domain/Department.cs` 생성
- [ ] `Resource.cs` 에 `DepartmentId` 추가
- [ ] `Project.cs` 에 `MemberResourceIds` 추가
- [ ] `Infrastructure/AgentTokenRepository.cs`
- [ ] `Infrastructure/DepartmentRepository.cs`
- [ ] `MongoContext` 에 컬렉션 핸들 추가 + 인덱스
- [ ] `Endpoints/AgentEndpoints.cs` (identity CRUD + rotate-token)
- [ ] `Endpoints/DepartmentEndpoints.cs`
- [ ] `Endpoints/ProjectEndpoints.cs` 에 members 서브 경로 추가
- [ ] `UserContextMiddleware` 에 Bearer 토큰 분기
- [ ] `ScopeService` 의 agent 분기 명시
- [ ] `Endpoints/MatrixEndpoints.cs` 에 departmentId/projectId 필터
- [ ] curl 스모크: 새 agent 생성 → 토큰으로 GET /tasks → 200

### 일 오전 (PR β-1 — Plan Gate backend)
- [ ] `Domain/AgentPlan.cs` (+ PlanStep + PlanStatus)
- [ ] `Infrastructure/AgentPlanRepository.cs`
- [ ] `Endpoints/AgentEndpoints.cs` 에 /plans 서브 경로
- [ ] approve / reject 권한 체크 (RbacPreset.Human 만)

### 일 오후 (PR β-2 — work-queue + E2E)
- [ ] /api/agents/work-queue endpoint
- [ ] `tools/demo_agent_flow.sh` — agent 생성 → assign → plan 제출 → 인간 approve → work-queue → task 진행 까지 한 시나리오

### 월 (PR γ — Frontend)
- [ ] `AppSection.agents` 화면 (agent 리스트, 생성 모달, rotate, revoke)
- [ ] Plan review queue 화면 (PendingReview 리스트, inline approve/reject)
- [ ] Matrix 의 department/project 필터 UI
- [ ] api_client.dart 에 새 endpoint 메서드들

### 화 (PR ε — README + 공개)
- [ ] README "Status" 섹션 업데이트
- [ ] README "Quick start" 섹션 (mongo + dotnet + flutter 설치 + 실행)
- [ ] README 에 agent flow 데모 (curl 스니펫 포함)
- [ ] CONTRIBUTING.md 짧게
- [ ] GitHub repo visibility 토글
