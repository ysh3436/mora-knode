# Mora Knode External Agent API Reference (v1)

- 대상: mora-knode 와 통신하는 외부 AI 에이전트 (Claude Code / Cursor / CrewAI / 자체 봇 등)
- API 버전: v1 (path 별도 prefix 없음, 향후 변경 시 `/v2/` 도입)
- 진실 원천: 본 문서와 코드의 diff 발생 시 **코드가 우선** ([src/backend/Endpoints/](../../src/backend/Endpoints))
- 비고: mora-knode 는 LLM·SDK·모델·키를 호출하지도 알지도 않는다 ([ADR-005](../architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md))
- 최종 수정: 2026-05-06

## 0. Overview

mora-knode 는 외부 AI 에이전트의 **host** 다. 외부 에이전트는 본 문서의 REST API 만 호출해서:

1. agent identity 등록 후 토큰 받음
2. 자기에게 할당된 task 를 polling 으로 인지
3. plan 제출 → 사람 검토 → 승인 → 실행 → 결과 보고

mora-knode 는 어떤 LLM/모델/SDK 를 쓰는지 모르며, 비용·토큰·프롬프트도 추적하지 않는다.

본 문서는 **API 사양** 만 담는다. 운영 패턴 (역할 분담 / Git 가드 / 2-layer delegation 등) 은 [docs/dogfooding/agent-operations.md](../dogfooding/agent-operations.md) 참고.

---

## 1. Authentication

### 1.1 토큰 획득

`POST /api/agents` 등록 응답에 `rawToken` 이 한 번만 노출된다. 형식: `mk_<base64url>` ([TokenGenerator](../../src/backend/Auth/TokenGenerator.cs)).

저장 책임은 외부 도구 측. 분실 시 `POST /api/agents/{id}/rotate` 로 재발급.

### 1.2 호출 시 두 헤더 동시 필요

```
Authorization: Bearer mk_<token>
X-Agent-Id: <agent-resource-id>
```

`X-Agent-Id` 가 없거나 token owner 와 불일치하면 **401**. defense-in-depth — 토큰만 유출되어도 paired ID 없이는 사용 불가, 로그에 명백한 mismatch 흔적이 남는다 ([UserContextMiddleware.cs](../../src/backend/Auth/UserContextMiddleware.cs)).

### 1.3 실패 응답

| 상태 | 의미 |
|---|---|
| **401** | Authorization 누락 / Bearer 외 scheme / `mk_` prefix 외 / hash 불일치 / revoked / X-Agent-Id 불일치 / agent kind 가 Agent 아님 |
| **403** | 인증은 OK, 권한 부족 (RBAC) |

응답 본문 (현재):
```json
{ "error": "Unauthorized", "detail": "..." }
```

### 1.4 Dev mode (mora-knode UI 전용, 외부 에이전트 사용 금지)

`X-Dev-User-Id: <resource-id>` — Bearer 없을 때 fallback. 외부 에이전트는 **항상 Bearer + X-Agent-Id** 사용.

### 1.5 인증 흐름

```
Request 도착
   │
   ├─ Authorization 헤더 있음?
   │     │ Yes
   │     ├─ "Bearer " 로 시작? ──── No ──► 401 (scheme 오류)
   │     │     │ Yes
   │     ├─ token format mk_<...>? ── No ──► 401 (format 오류)
   │     │     │ Yes
   │     ├─ hash DB 매칭 + active? ── No ──► 401 (unknown/revoked)
   │     │     │ Yes
   │     ├─ X-Agent-Id == token owner? ── No ──► 401 (ownership mismatch)
   │     │     │ Yes
   │     └─ agent.Kind == Agent? ──── No ──► 401 (invalid kind)
   │           │ Yes
   │           └─► CurrentUser = agent  → 다음 미들웨어
   │
   └─ Authorization 없음 + X-Dev-User-Id 헤더?
         │ Yes (dev only)
         └─► CurrentUser = resource (없으면 anonymous)
```

---

## 2. RBAC Presets

[RbacPreset](../../src/backend/Domain/Enums.cs):

| Preset | Plan approve/reject | Plan 제출 | Comment 편집 (남의 것) |
|---|---|---|---|
| **Human** (default) | ✓ | ✓ | ✓ (admin) |
| **Manager** | ✓ | ✓ | ✓ (admin) |
| **Reviewer** | ✓ | ✓ | ✓ (admin) |
| **Developer** | ✗ | ✓ (assigned task only) | ✗ (자기 것만) |
| **QA** | ✗ | ✓ (assigned task only) | ✗ (자기 것만) |

핵심 규칙:
- Plan **approve / reject / revert** 는 Human/Manager/Reviewer 만 ([AgentEndpoints.cs:382-396](../../src/backend/Endpoints/AgentEndpoints.cs))
- Plan **submit** 은 IsAdmin 또는 task 에 assigned 된 자만 ([AgentEndpoints.cs:153-163](../../src/backend/Endpoints/AgentEndpoints.cs))
- Comment **edit/delete** 는 author 또는 IsAdmin
- IsAdmin = `Rbac ∈ {Human, Manager, Reviewer}`

---

## 3. Endpoints

전체 50+ endpoint. 외부 에이전트가 자주 쓰는 영역만 표로, 나머지 CRUD 는 한 줄 요약.

### 3.1 Agent management (5)

| Method | Path | Auth | RBAC | 비고 |
|---|---|---|---|---|
| GET | `/api/agents` | Bearer | scope filtered | Kind=Agent 인 Resource 목록 |
| POST | `/api/agents` | Bearer/Dev | Human | 새 agent + 토큰 1회 발급. raw 는 응답에서만 노출 |
| GET | `/api/agents/{id}/tokens` | Bearer | self/admin | 토큰 메타 (해시·last4·revokedAt) |
| POST | `/api/agents/{id}/rotate` | Bearer | self/admin | 기존 모두 revoke + 새 raw token 1회 반환 |
| POST | `/api/agents/{id}/revoke` | Bearer | self/admin | 모든 활성 토큰 즉시 revoke (Resource 는 보존) |

### 3.2 Plan gate (5) — ADR-002

| Method | Path | Auth | RBAC | 비고 |
|---|---|---|---|---|
| POST | `/api/agents/plans` | **Bearer 필수** | assigned to task **or** IsAdmin | 새 plan 제출. 부수효과: task.Status → PlanReview |
| GET | `/api/agents/plans` | Optional | scope filtered | query: `status`, `taskId`, `submittedBy` — 검토 큐 / 히스토리 |
| GET | `/api/agents/plans/{id}` | Optional | scope filtered | 단건 |
| PUT | `/api/agents/plans/{id}/approve` | **Bearer 필수** | Human/Manager/Reviewer | body: `{ "comment": "..." }` 선택. 부수효과: task → InProgress |
| PUT | `/api/agents/plans/{id}/reject` | **Bearer 필수** | Human/Manager/Reviewer | body: `{ "comment": "..." }` **필수**. 부수효과: task → InProgress (재계획 가능) |
| PUT | `/api/agents/plans/{id}/revert` | **Bearer 필수** | original reviewer **or** Manager | 검토 결정 되돌리기. 부수효과: task → PlanReview |

### 3.3 Work queue (1) — v1 polling-only

| Method | Path | Auth | 비고 |
|---|---|---|---|
| GET | `/api/agents/work-queue` | **Bearer 필수** | 호출 agent 에 assigned + non-terminal (Done/Cancelled/Dropped 제외) task + latest plan 묶음 |

응답:
```json
[
  { "task": { /* TaskItem */ }, "latestPlan": { /* AgentPlan or null */ } },
  ...
]
```

**v1 의도적 미구현** (v2/v3 예정 — §6 / §8):
- query filter (`?role=`, `?status=`, `?sort=`)
- `POST /api/agents/work-queue/{taskId}/claim` (race-free lock)
- `POST /api/agents/work-queue/{taskId}/release`
- `POST /api/agents/runs` (실행 메트릭)
- `GET /api/agents/work-queue/stream` (SSE push)

### 3.4 Tasks

| Method | Path | 비고 |
|---|---|---|
| GET | `/api/projects/{projectId}/tasks` | 프로젝트의 flat task 목록 |
| GET | `/api/projects/{projectId}/tasks/hierarchy` | parent/child 트리 + aggregated status/priority |
| POST | `/api/projects/{projectId}/tasks` | task 생성 |
| GET | `/api/tasks/{id}` | 단건 |
| PUT | `/api/tasks/{id}` | 갱신. body 에 `changeReason` / `changedBy` 동봉하면 ChangeLog 자동 기록 |
| DELETE | `/api/tasks/{id}` | 삭제 |

### 3.5 Comments

| Method | Path | Auth | 비고 |
|---|---|---|---|
| GET | `/api/tasks/{taskId}/comments` | Optional | 스레드 (생성순) |
| POST | `/api/tasks/{taskId}/comments` | **Bearer 필수** | body: `{ "body": "markdown", "kind": "review|bug|qa|null" }` |
| PUT | `/api/comments/{id}` | **Bearer 필수** | author 또는 admin |
| DELETE | `/api/comments/{id}` | **Bearer 필수** | author 또는 admin (hard delete) |

### 3.6 그 외 (CRUD 패턴)

scope-filtered, 인증은 optional (anonymous 는 admin-equivalent visibility — dev 환경 한정):

| 영역 | 경로 | 비고 |
|---|---|---|
| Projects | `/api/projects[/{id}[/members/{resourceId}]]` | 멤버 관리 포함 |
| Resources | `/api/resources[/{id}]` | Human + Agent 혼합 매트릭스 |
| Assignments | `/api/assignments[/{id}]` | resource ↔ task |
| Departments | `/api/departments[/{id}]` | 매트릭스 axis 1 (조직 단위) |
| Milestones | `/api/projects/{projectId}/milestones[/{id}]` | |
| ChangeLogs | `/api/change-logs?entityType&entityId&projectId&from&to&offset&limit` | 페이징 |
| Matrix load | `/api/matrix/load?from&to&departmentId&projectId` | 사람+Agent 합산 가동률 |
| WorkCalendar | `/api/work-calendar` | org-level singleton |
| Holidays / Holiday-Sources | `/api/holidays[...]`, `/api/holiday-sources[...]` | .ics 구독 등 |
| Health | `GET /health` | `{ "status": "ok" }` |

---

## 4. Wire formats

모든 ID 는 MongoDB ObjectId hex string. 모든 datetime 은 ISO 8601 UTC.

### 4.1 TaskItem

```json
{
  "id": "507f1f77bcf86cd799439011",
  "projectId": "507f1f77bcf86cd799439001",
  "parentTaskId": null,
  "title": "API reference 작성",
  "description": "외부 에이전트가 호출할 모든 endpoint 를...",
  "status": "InProgress",
  "isWaiting": false,
  "priority": "High",
  "number": 42,
  "originTimeline":  { "start": "2026-05-01T00:00:00Z", "end": "2026-05-10T00:00:00Z" },
  "currentTimeline": { "start": "2026-05-01T00:00:00Z", "end": "2026-05-12T00:00:00Z" },
  "realTimeline":    { "start": "2026-05-02T00:00:00Z", "end": null },
  "createdAt": "2026-05-01T10:00:00Z",
  "updatedAt": "2026-05-06T14:30:00Z"
}
```

- `status` 9가지 string: `Created` / `Planning` / `PlanReview` / `InProgress` / `WorkReview` / `OnHold` / `Done` / `Cancelled` / `Dropped`
- `priority` 5가지 string: `Urgent` / `High` / `Normal` / `Low` / `Unset` — 정수 anchor 는 `Urgent=-20, High=-10, Normal=0, Low=10, Unset=100` ([Enums.cs](../../src/backend/Domain/Enums.cs))
- PUT 시 `changeReason` / `changedBy` 필드를 동봉하면 ChangeLog 에 사유 기록 (BsonIgnore — 저장 안 됨)

### 4.2 AgentPlan

```json
{
  "id": "507f1f77bcf86cd799439012",
  "taskId": "507f1f77bcf86cd799439011",
  "submittedByResourceId": "507f1f77bcf86cd799439013",
  "status": "PendingReview",
  "title": "API 레퍼런스 작성 plan v1",
  "estimateMinutes": 480,
  "steps": [
    { "description": "endpoint 인벤토리 추출", "estimateMinutes": 60 },
    { "description": "wire format 예시", "estimateMinutes": 90 },
    { "description": "운영 모델 비교 작성", "estimateMinutes": 180 },
    { "description": "E2E 워크스루 + curl 검증", "estimateMinutes": 150 }
  ],
  "notes": "ADR-005 톤 정렬 주의",
  "reviewerComment": null,
  "reviewedByResourceId": null,
  "reviewedAt": null,
  "createdAt": "2026-05-06T10:00:00Z",
  "updatedAt": "2026-05-06T10:00:00Z"
}
```

- `status` 3가지: `PendingReview` / `Approved` / `Rejected`
- 수정 불가. revise 는 **새 plan 제출** (이전 plan 은 audit 으로 보존)

### 4.3 Resource (Agent)

```json
{
  "id": "507f1f77bcf86cd799439013",
  "name": "developer-01",
  "role": "backend developer",
  "capacityPercent": 100,
  "kind": "Agent",
  "rbac": "Developer",
  "agentDescription": "Claude Code paired with CrewAI handler on laptop pod",
  "departmentId": null,
  "createdAt": "2026-04-29T00:00:00Z",
  "updatedAt": "2026-04-29T00:00:00Z"
}
```

- Human resource 는 `kind: "Human"`, `agentDescription: null`

### 4.4 TaskComment

```json
{
  "id": "507f1f77bcf86cd799439014",
  "taskId": "507f1f77bcf86cd799439011",
  "authorResourceId": "507f1f77bcf86cd799439013",
  "body": "PR opened: https://github.com/.../pull/42\n\n- API 레퍼런스 §1~5 완성\n- §6~8 작업 중",
  "kind": "review",
  "createdAt": "2026-05-06T16:00:00Z",
  "updatedAt": "2026-05-06T16:00:00Z"
}
```

- `body` 는 markdown. `kind` 는 `null` / `"review"` / `"bug"` / `"qa"` (validation 없음, lean v1)
- 인라인 이미지 (`![](url)`) 가능하나, **`/api/attachments` endpoint 는 v1 미구현** — TaskComment.cs 코드 주석에는 언급되나 실제 endpoint 코드 없음. 외부 URL 만 사용 가능 (M2 후반 결정)

---

## 5. End-to-End Walkthrough

### 5.1 다이어그램 — 외부 에이전트 lifecycle

```
┌────────────────────────────────────────────────────────────────────┐
│ Phase 1: One-time registration (사람이 mora-knode UI 또는 API 로) │
└────────────────────────────────────────────────────────────────────┘

  사람 (Human / Manager)            mora-knode backend
        │                                  │
        │ POST /api/agents                 │
        │ { name, rbac, agentDescription } │
        ├─────────────────────────────────►│
        │                                  ├── Resource (Kind=Agent) 생성
        │                                  ├── AgentToken 발급 (raw + hash)
        │ { agent, rawToken (1회만!) }     │
        │◄─────────────────────────────────┤
        │                                  │
        ├── rawToken 을 외부 도구의       │
        │   환경변수에 저장:               │
        │   MORA_KNODE_AGENT_TOKEN=mk_...  │
        │   MORA_KNODE_AGENT_ID=...        │

┌────────────────────────────────────────────────────────────────────┐
│ Phase 2: 24/7 operation loop (외부 에이전트가 자율 polling)       │
└────────────────────────────────────────────────────────────────────┘

  외부 에이전트 (CrewAI / Claude Code / 자체 봇)        mora-knode
        │                                                       │
   ┌────┴──── while True ─────────────────────────────────────┐ │
   │    │                                                     │ │
   │    │ GET /api/agents/work-queue                          │ │
   │    │ Auth: Bearer mk_... + X-Agent-Id: ...               │ │
   │    ├────────────────────────────────────────────────────►│ │
   │    │                                                     ├─┤ assigned task
   │    │                                                     │ │ + latest plan
   │    │ WorkQueueRow[] (TaskItem + AgentPlan?)              │ │
   │    │◄────────────────────────────────────────────────────┤ │
   │    │                                                     │ │
   │    ├── 클라이언트 사이드 우선순위 정렬                  │ │
   │    │   (Urgent first, deadline tiebreaker 등)            │ │
   │    │                                                     │ │
   │    ├── 첫 task 처리 분기:                                │ │
   │    │                                                     │ │
   │    │   ① plan 없음 (Status=Created/Planning) → plan 작성 │ │
   │    │      POST /api/agents/plans                         │ │
   │    │      { taskId, title, steps, ... }                  │ │
   │    │      → Status=PlanReview                            │ │
   │    │                                                     │ │
   │    │   ② plan Approved → 코드 작성 / PR                  │ │
   │    │      PUT /api/tasks/{id} { status: "InProgress" }   │ │
   │    │      ... 작업 ...                                   │ │
   │    │      POST /api/tasks/{id}/comments { body: "PR..."} │ │
   │    │      PUT /api/tasks/{id} { status: "WorkReview" }   │ │
   │    │                                                     │ │
   │    │ sleep(30)  # 30초~5분 권장 polling 간격             │ │
   │    │                                                     │ │
   └────┴────────────────────────────────────────────────────►┘ │
                                                                │
```

### 5.2 Phase 1 — 등록 (사람이 한 번만)

dev mode 로 (사람이 UI 또는 curl 로) agent 등록:

```bash
curl -X POST http://localhost:5163/api/agents \
  -H "X-Dev-User-Id: <human-resource-id>" \
  -H "Content-Type: application/json" \
  -d '{"name":"developer-01","rbac":"Developer","description":"Claude Code on laptop"}'
```

응답에서 `rawToken` 을 외부 도구 환경변수로:
```bash
export MORA_KNODE_API_URL=http://localhost:5163
export MORA_KNODE_AGENT_ID=<응답의 agent.id>
export MORA_KNODE_AGENT_TOKEN=<응답의 rawToken>
```

### 5.3 Phase 2 — work-queue polling

```python
import os, json, time, urllib.request

API   = os.environ["MORA_KNODE_API_URL"]
TOKEN = os.environ["MORA_KNODE_AGENT_TOKEN"]
AGENT = os.environ["MORA_KNODE_AGENT_ID"]
HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "X-Agent-Id": AGENT,
    "Content-Type": "application/json",
}

def get(path):
    req = urllib.request.Request(f"{API}{path}", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read())

def post(path, body):
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(f"{API}{path}", data=data, headers=HEADERS, method="POST")
    return json.loads(urllib.request.urlopen(req).read())

def put(path, body=None):
    data = json.dumps(body or {}).encode("utf-8")
    req = urllib.request.Request(f"{API}{path}", data=data, headers=HEADERS, method="PUT")
    return json.loads(urllib.request.urlopen(req).read())

while True:
    rows = get("/api/agents/work-queue")
    rows.sort(key=lambda r: PRIORITY[r["task"]["priority"]])  # client-side
    # ... 처리 ...
    time.sleep(30)
```

`PRIORITY` 매핑:
```python
PRIORITY = {"Urgent": -20, "High": -10, "Normal": 0, "Low": 10, "Unset": 100}
```

### 5.4 Phase 3 — Plan 제출

```python
plan = post("/api/agents/plans", {
    "taskId": row["task"]["id"],
    "title": "MK-100 plan v1",
    "estimateMinutes": 240,
    "steps": [
        {"description": "endpoint 분석", "estimateMinutes": 60},
        {"description": "코드 작성",       "estimateMinutes": 120},
        {"description": "테스트",           "estimateMinutes": 60},
    ],
    "notes": "ADR-005 톤 주의",
})
# plan["status"] == "PendingReview"
# task.Status 자동 PlanReview 로 전환
```

### 5.5 Phase 4 — 결과 보고 / 상태 전환

승인된 task 처리 후:

```python
# 작업 시작 표시
put(f"/api/tasks/{task_id}", {**task, "status": "InProgress",
                               "changeReason": "started", "changedBy": agent_name})

# ... 코드 작성 / PR 생성 ...

# 결과 코멘트
post(f"/api/tasks/{task_id}/comments", {
    "body": "PR opened: https://github.com/.../pull/42\n\n- 변경 요약\n- 검증 방법",
    "kind": "review",
})

# WorkReview 로 전환 → 사람이 PR 검토
put(f"/api/tasks/{task_id}", {**task, "status": "WorkReview",
                               "changeReason": "PR ready", "changedBy": agent_name})
```

> **참고 (PowerShell 사용자)**: PowerShell 의 `Invoke-RestMethod` 로 한국어 body 를 PUT/POST 하면 cp949 mojibake 발생 위험 — Python urllib 권장.

---

## 6. Operating model — v1 polling, v2/v3 roadmap

### 6.1 작업 인지 4가지 방법론 비교

| 기준 | Polling | Webhook | Server-Sent Events (SSE) | gRPC streaming |
|---|---|---|---|---|
| **방향** | client→server pull | server→client push | server→client push | bidirectional |
| **셋업 복잡도** | 낮음 | 중 (URL + retry + signature) | 중 (Change Streams + replica set) | 높음 (proto + lib) |
| **외부 에이전트 자유도** | 매우 높음 (HTTP만) | 낮음 (reachable URL 필요) | 높음 (eventsource client) | 낮음 (gRPC lib) |
| **방화벽 친화** | ✓ outbound only | ✗ inbound 필요 | ✓ outbound only | △ HTTP/2 |
| **지연 시간** | 초~분 (interval 의존) | 즉시 | 즉시 | 즉시 |
| **backend 부하** | 높음 (빈 응답 다수) | 낮음 | 중 (연결 유지) | 중 |
| **MongoDB 요구사항** | standalone OK | standalone OK | **replica set 필수** | replica set 권장 |
| **외부 에이전트 형태** | 어떤 도구든 | 서버형 (24/7 listen) | long-lived process | native lib |
| **재시도 / 신뢰성** | 다음 polling 에서 자연 회복 | retry 정책 명시 필요 | 자동 reconnect | 자동 reconnect |

### 6.2 v1 결정과 도입 로드맵

**v1 (현재, M2)**: Polling-only.

이유:
1. 외부 에이전트 도구 다양성 — Claude Code / Cursor / CrewAI / 자체 봇 모두 HTTP outbound 만으로 동작. webhook 받을 reachable URL 이 없는 도구 (Claude Code sub-agent 등) 가 다수
2. dogfooding 단계 규모: 1~5 에이전트, 비실시간 (사람 검토 사이 분~시간 단위 지연 허용)
3. 인프라 단순성: standalone MongoDB OK, replica set 불필요
4. 카테고리 정렬: 외부 에이전트가 자기 페이스로 폴링 → ADR-005 의 "에이전트 자유" 원칙

**v2 후보 1: SSE (도입 권장 시점 M3 직전, ~2026-07~08)**

- 추가 endpoint: `GET /api/agents/work-queue/stream` (text/event-stream)
- backend 변경: MongoDB Change Streams 구독 + replica set 전환 + SSE 헤더 / heartbeat
- 외부 에이전트 변경: HTTP client 가 EventSource 또는 chunked stream 처리
- 도입 트리거: polling 지연 (30초~5분) 이 사람 검토 사이클 병목인 경우. 또는 5+ 에이전트로 인해 polling 부하 증가
- TODO Phase 4 Push 모드와 자연스럽게 합치므로 별도 ADR 불필요 (ADR-009 갱신 정도)

**v2 후보 2: Webhook (도입 권장 시점 M4 cloud alpha, ~2026-10)**

- 추가 endpoint: `POST /api/agents/{id}/webhooks` 등록 + mora-knode 가 이벤트 시 외부 URL 호출
- backend 변경: webhook 도메인 + retry 정책 (지수 백오프 + dead letter) + HMAC signature
- 외부 에이전트 변경: HTTPS 서버 운영, signature 검증
- 도입 트리거: cloud alpha 단계 — 외부 사용자 중 GitHub Actions / Lambda 같은 이벤트 기반 도구 운영자 존재 시
- ADR 신설: webhook 신뢰성 / signature 정책

**v3 후보: gRPC streaming (도입 검토 시점 M5+ GA 이후)**

- 외부 에이전트가 native lib 의존 가능한 환경 (Cursor / VSCode extension / 자체 데스크톱 앱) 에서만 의미
- 사용자 피드백 후 결정. 우선순위 낮음

### 6.3 도입 트리거 (의사결정)

| 신호 | 행동 |
|---|---|
| polling 지연이 사람 검토 사이클을 늦춤 | SSE (M3 직전) 도입 |
| 외부 사용자 중 GitHub Actions / 서버형 봇 비중 높음 | Webhook (M4) 도입 |
| Cursor / IDE extension 사용자 다수 보고 | gRPC streaming (M5+) 검토 |
| 5+ 에이전트가 동시 polling → backend 부하 | SSE 우선 (가장 자연스러운 진화) |

### 6.4 다이어그램 — v1 → v2 → v3 진화

```
┌──────────────────────── v1 (현재) ────────────────────────┐
│                                                           │
│   에이전트 루프              backend                      │
│        │                        │                         │
│        │ GET work-queue (30s)   │                         │
│        ├───────────────────────►│ (정렬 안 함)            │
│        │ rows[]                 │                         │
│        │◄───────────────────────┤                         │
│        ├ client-side sort       │                         │
│        ├ pick top, process      │                         │
│        ├ sleep(30)              │                         │
│        ▼                        │                         │
│      (반복)                     │                         │
│                                                           │
│   장점: 단순. 단점: 30초 지연, 빈 응답 부하              │
└───────────────────────────────────────────────────────────┘

┌────────── v2 (M2 후반 ~ M3, server sort + SSE) ──────────┐
│                                                           │
│   에이전트                  backend                       │
│        │                        │                         │
│        │ GET work-queue/stream  │                         │
│        │   (Server-Sent Events) │                         │
│        ├───────────────────────►│                         │
│        │                        ├ MongoDB Change Streams  │
│        │                        │   구독                  │
│        │                        │                         │
│        │ event: task-assigned   │                         │
│        │ data: {row, sorted}    │                         │
│        │◄═══════════════════════┤  (push, 즉시)           │
│        ├ process                │                         │
│        │                        │                         │
│        │ event: task-assigned   │                         │
│        │◄═══════════════════════┤                         │
│        │                        │                         │
│                                                           │
│   장점: 즉시. 단점: replica set 필요                     │
└───────────────────────────────────────────────────────────┘

┌──────────── v3 (M3+ multi-agent + claim lock) ───────────┐
│                                                           │
│   여러 에이전트            backend                        │
│   (5+ 동시 운영)                                         │
│        │                        │                         │
│        │ GET work-queue/next    │                         │
│        │   ?role=Developer      │                         │
│        ├───────────────────────►│                         │
│        │                        ├ priority 정렬           │
│        │                        ├ atomic claim            │
│        │                        │   (findAndUpdate lock)  │
│        │ row (1개만, locked)    │                         │
│        │◄───────────────────────┤                         │
│        │ process                │                         │
│        │ POST /release          │                         │
│        ├───────────────────────►│                         │
│                                                           │
│   장점: 다수 에이전트 race 안전. 단점: 복잡             │
└───────────────────────────────────────────────────────────┘
```

---

## 7. Notifications — out-of-band by external tools (v1), Slack/Email/Webhook roadmap

### 7.1 알람 4가지 옵션 비교

| 기준 | 외부 도구 자체 (v1) | Slack webhook | Email (SMTP) | Generic webhook |
|---|---|---|---|---|
| **셋업** | 0 (mora-knode 무관) | env 1개 (SLACK_WEBHOOK_URL) | SMTP 호스트 / SPF / DKIM | URL 등록 + signature |
| **실시간성** | polling 의존 | 즉시 | 분 단위 (메일 서버) | 즉시 |
| **대상자** | 외부 에이전트 운영자 | Slack 워크스페이스 멤버 | 누구나 | 임의 시스템 |
| **사용자 친숙도** | 낮음 (도구별 다름) | 매우 높음 (개발자) | 높음 (보편) | 중 |
| **ADR-005 종속** | 없음 (가장 정렬) | Slack 1개 | SMTP/SaaS 1개 | 없음 (일반화) |
| **self-hosted 친화** | ✓ | ✓ | ✓ (자체 SMTP) | ✓ |

### 7.2 v1 결정과 도입 로드맵

**v1 (현재, M2)**: 외부 도구 자체 책임.

- mora-knode 는 알람 채널 제공 안 함 (ADR-005 정렬)
- 외부 에이전트 (CrewAI / Claude Code sub-agent) 가 자체적으로 polling 결과 보고 OS notification / Slack / desktop alert
- ysh dogfooding 단계: ysh 본인이 mora-knode UI 매일 5분 검토

**v2: Slack webhook (도입 권장 시점 M2 후반, ~2026-06-15 직후)**

- 트리거: PlanReview / WorkReview 전환 (사람 개입 필요한 두 시점)
- 구현: backend 의 plan/work-review 핸들러에 `ISlackNotifier` interface + env 활성화
- 외부 의존: Slack Incoming Webhook (무료 plan 가능)
- 도입 트리거: dogfooding 중 plan 이 검토 안 되고 쌓이는 병목 발견
- 작업 분량: ~1 day (interface + Slack POST + env config + 1 test)
- ADR 메모만: Slack 은 LLM 이 아니라 channel 이므로 ADR-005 와 충돌 없음

**v3: Email (도입 권장 시점 M3 오픈소스 공개 직전, ~2026-08)**

- 구현: SMTP client (MailKit) + 템플릿 (HTML + plain text)
- 외부 의존: SMTP 서버 (자체 또는 SaaS — SendGrid / SES / Postmark)
- 도입 트리거: public 사용자 중 Slack 미사용자 비중
- 작업 분량: ~2 days (SMTP + 템플릿 + DKIM 안내 + 1 test)

**v4: Generic webhook (도입 권장 시점 M4 cloud alpha, ~2026-10)**

- mora-knode 가 사용자 정의 URL (Discord / Teams / 자체 시스템) 로 CloudEvents 형식 POST
- Slack / Email 도 generic webhook 의 special case 로 흡수 가능 (장기 코드 단순화)
- 작업 분량: ~3 days (CloudEvents 스펙 + retry + signature + 다채널 적응)

### 7.3 도입 트리거

| 신호 | 행동 |
|---|---|
| ysh dogfooding 시 plan 이 검토 안 되고 쌓임 | Slack v2 (M2 후반) 도입 |
| public 오픈 후 Slack 미사용자 issue 다수 | Email v3 (M3) 도입 |
| 사용자가 Discord / Teams 요청 다수 | Generic webhook v4 (M4) 도입 |

---

## 8. Priority handling — client-side sort (v1), server sort / claim lock (v2/v3)

### 8.1 현재 (v1) 동작

`/api/agents/work-queue` 핸들러 ([AgentEndpoints.cs:350-377](../../src/backend/Endpoints/AgentEndpoints.cs)):

1. 호출 agent 에 assigned 된 task 조회
2. 각 task 의 latest plan 묶어 `WorkQueueRow[]` 반환
3. **정렬 안 함** — DB 저장 순서 (대략 createdAt) 그대로
4. terminal task (Done/Cancelled/Dropped) 는 제외 — 큐가 가벼워짐

응답에 `task.priority` 가 포함되어 외부 에이전트가 클라이언트 사이드에서 정렬.

### 8.2 왜 서버가 정렬 안 하나 (설계 의도)

에이전트마다 우선순위 정책이 다를 수 있다:
- "Urgent 부터" — 화재 진압형
- "deadline 가까운 것부터" — 계획형
- "blocked (IsWaiting=true) 풀기 먼저" — 흐름 관리형
- "내가 잘하는 도메인 먼저" — 전문화형

mora-knode 가 한 정책 강제 → 카테고리 흐림 (ADR-005)

### 8.3 옵션 A: 클라이언트 사이드 정렬 (현재 v1, **권장**)

```python
# 정책 1: priority 우선 (Urgent → Low → Unset)
PRIORITY = {"Urgent": -20, "High": -10, "Normal": 0, "Low": 10, "Unset": 100}
rows.sort(key=lambda r: PRIORITY[r["task"]["priority"]])

# 정책 2: deadline 우선
rows.sort(key=lambda r: r["task"]["currentTimeline"]["end"] or "9999-12-31")

# 정책 3: blocked 풀기 먼저
rows.sort(key=lambda r: (0 if r["task"]["isWaiting"] else 1,
                         PRIORITY[r["task"]["priority"]]))

for row in rows:
    if can_handle(row):
        process(row)
        break  # 한 task 처리 후 다음 polling
```

부모 task 의 priority 는 hierarchy endpoint 응답에 자식 active priority 의 min 으로 미리 집계됨 — 외부 에이전트는 그대로 사용.

**장점**:
- 에이전트마다 정책 자유 (ADR-005 정렬)
- backend 단순, 추가 코드 0
- 정책 변경 시 backend 배포 불필요

**단점**:
- 모든 에이전트가 같은 응답 → 5+ 에이전트 동시 polling 시 모두 1순위 task 시도
- v1 은 lock 미구현 → race 발생 (먼저 PUT 한 에이전트가 이김)
- **현실**: ysh dogfooding 은 1~4 에이전트 + 역할 분리 (Manager / Developer / Researcher / QA) → race 거의 없음

**적합 시점**: v1 ~ M2 dogfooding (5 에이전트 이하)

### 8.4 옵션 B: 서버 정렬 query (M2 후반 검토)

backend 변경 (예시):
```csharp
var sort = ctx.Request.Query["sort"].ToString();
var ordered = sort switch
{
    "priority" => rows.OrderBy(r => r.PriorityValue).ThenBy(r => r.Deadline),
    "deadline" => rows.OrderBy(r => r.Deadline).ThenBy(r => r.PriorityValue),
    "blocked"  => rows.OrderBy(r => r.IsWaiting ? 0 : 1).ThenBy(r => r.PriorityValue),
    _          => rows  // default: 무정렬 (옵션 A 유지)
};
```

호출:
```
GET /api/agents/work-queue?sort=priority
```

**장점**: 클라이언트 단순 / 일관성 / 페이지네이션 자연스러움
**단점**: 서버가 정책 결정 (ADR-005 약화 — 단 sort 옵션 4~5개로 한정 → 영향 작음)
**작업 분량**: ~0.5 day

### 8.5 옵션 C: Server-side claim lock + priority lease (M3+ 본격 서비스)

backend 변경:
- TaskItem 에 `ClaimedBy` (agent ID, nullable) + `ClaimedAt` + `LeaseExpiresAt` 필드 추가
- 새 endpoint: `POST /api/agents/work-queue/{taskId}/claim` (atomic findAndUpdate)
- 새 endpoint: `POST /api/agents/work-queue/{taskId}/release`
- 자동 release: lease 만료 시 백그라운드 job 이 ClaimedBy=null 로 reset

핵심 코드 (race-free):
```csharp
var claimed = await tasks.FindOneAndUpdateAsync(
    Builders<TaskItem>.Filter.Eq(t => t.Id, taskId)
        & (Builders<TaskItem>.Filter.Eq(t => t.ClaimedBy, null)
           | Builders<TaskItem>.Filter.Lt(t => t.LeaseExpiresAt, DateTime.UtcNow)),
    Builders<TaskItem>.Update
        .Set(t => t.ClaimedBy, agentId)
        .Set(t => t.ClaimedAt, DateTime.UtcNow)
        .Set(t => t.LeaseExpiresAt, DateTime.UtcNow.AddMinutes(30)),
    new FindOneAndUpdateOptions<TaskItem> { ReturnDocument = ReturnDocument.After });
if (claimed == null) return Results.Conflict("already claimed");
```

**장점**: 다수 에이전트 race 안전 (10+ OK), lease 만료 자동 회수, fair 분배
**단점**: 가장 복잡 (lock state / TTL / fail-recovery / lease 갱신)
**작업 분량**: ~3~5 days
**적합 시점**: M3 오픈소스 공개 후 — 외부 사용자가 5+ 에이전트 운영 보고 시

### 8.6 도입 트리거

| 신호 | 행동 |
|---|---|
| 같은 task 를 2 에이전트가 동시 시도 보고 | 옵션 B (서버 정렬) 또는 옵션 C 검토 |
| 5+ 에이전트 동시 운영 안정화 | 옵션 C (claim lock) 도입 |
| 정책 일관성 요구 (sort 무관 모두 같은 순서) | 옵션 B (server sort) 도입 |
| 단일 에이전트 / 역할 분리 잘 됨 | 옵션 A 유지 |

---

## 9. Plan gate state machine

```
                ┌──────────┐
                │ Created  │  사람 또는 에이전트가 task 생성
                └────┬─────┘
                     │ (에이전트가 작업 시작)
                     ▼
                ┌──────────┐
                │ Planning │  에이전트가 plan 작성 중
                └────┬─────┘
                     │ POST /api/agents/plans
                     ▼
              ┌─────────────┐
        ┌────►│ PlanReview  │  사람 (Human/Manager/Reviewer) 검토 대기
        │     └──┬──────┬───┘
        │        │      │
        │        │      │ PUT /plans/{id}/reject (comment 필수)
        │        │      │  → task → InProgress (재계획 가능)
        │        │      └──────────────────────┐
        │        │                              │
        │        │ PUT /plans/{id}/approve      │
        │        ▼                              ▼
        │ ┌──────────────┐                  (에이전트가 새 plan 제출 시
        │ │ InProgress   │                   다시 PlanReview 또는 종료)
        │ └──────┬───────┘
        │        │ PUT /api/tasks/{id} { status: "WorkReview" }
        │        ▼
        │ ┌──────────────┐
        │ │ WorkReview   │  사람이 결과물 (PR) 검토
        │ └──┬───────┬───┘
        │    │       │
        │    │       │ 사람이 revise 요청 (comment + status 되돌림)
        └────┘       │
                     │ 사람이 PR 머지 + 완료 처리
                     ▼
                ┌──────────┐
                │   Done   │  종료
                └──────────┘

  보조 상태 (어디서나 진입 가능):
  • OnHold    — 임시 보류 (자원 / 대기)
  • Cancelled — 작업 자체 취소 (비기각)
  • Dropped   — 의도적으로 안 하기로 결정

  Revert (원 reviewer 또는 Manager):
  • PUT /plans/{id}/revert → task 다시 PlanReview 로 (검토 결정 무효화)
```

**중요 규칙**:
- 에이전트는 plan 을 **수정할 수 없다**. revise = 새 plan 제출 (audit 보존)
- approve / reject 는 한 plan 당 1회만. Conflict (이미 review 됨) 시 409
- 모든 transition 은 **actor 기반** — backend 가 자체 판단으로 status 안 바꿈 (ADR-005)
- 단, plan 제출 시 task → PlanReview, approve 시 task → InProgress, reject 시 task → InProgress 는 **부수효과** (단 task 가 이미 Done/Cancelled/Dropped 면 무시)

---

## 10. Error responses

현재 형식:
```json
{ "error": "<message>", "detail": "..." }
```

상태 코드 규칙:
- **200** OK — 정상
- **201** Created — 신규 생성
- **204** No Content — 삭제
- **400** Bad Request — 검증 실패 (필수 필드 누락 / enum 파싱 실패 / 빈 body)
- **401** Unauthorized — 인증 실패 (§1.3)
- **403** Forbidden — RBAC 권한 부족
- **404** Not Found — 자원 없음
- **409** Conflict — 상태 불일치 (이미 reviewed plan 재 review 등)

**v2 표준화 후보** (M2 후반 결정):
```json
{ "errorCode": "AUTH_REQUIRED", "message": "...", "timestamp": "2026-05-06T10:00:00Z" }
```

---

## 11. v1 미구현 / v2 / v3 로드맵 한눈에

| 항목 | v1 | v2 도입 시점 | v3 도입 시점 |
|---|---|---|---|
| 작업 인지 | polling | SSE (M3 직전 ~2026-07~08) | gRPC (M5+) |
| webhook (server→client) | ✗ | M4 cloud alpha (~2026-10) | — |
| 알람 채널 | 외부 도구 자체 | Slack (M2 후반 ~2026-06 후) | Email (M3 ~2026-08), Generic webhook (M4) |
| work-queue claim lock | ✗ (race 가능) | — | M3+ (옵션 C, 5+ 에이전트 시) |
| work-queue query filter | ✗ | M2 후반 (옵션 B sort query, ~0.5d) | — |
| `POST /api/agents/runs` 실행 메트릭 | ✗ | M3 (선택적) | — |
| `/api/attachments` (이미지 업로드) | ✗ (모델 코멘트만 참조) | M2 후반 결정 | — |
| 에러 응답 표준화 | `{error, detail}` | M2 후반 (`{errorCode, message, timestamp}`) | — |

각 도입 트리거 / 작업 분량 / 권장 시점은 §6/§7/§8 참조.

---

## 12. 관련 문서

- [ADR-002 (Plan 게이트)](../architecture/ADR-002-manager-approval-gate.md)
- [ADR-004 (Agent Identity & API)](../architecture/ADR-004-agent-identity-and-api.md)
- [ADR-005 (LLM 비차별 원칙)](../architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md)
- [ADR-006 (BYOA 5분 셋업 UX)](../architecture/ADR-006-byoa-onboarding-ux.md)
- [ADR-008 (Flutter Web desktop only)](../architecture/ADR-008-flutter-web-desktop-only.md)
- [docs/dogfooding/agent-operations.md](../dogfooding/agent-operations.md) — 운영 패턴 (강제 아님)
- [docs/architecture/schema-integration-for-agents.md](../architecture/schema-integration-for-agents.md) — 설계 의도 (shipped, 보존용)
- [docs/prd.md](../prd.md) — PRD
