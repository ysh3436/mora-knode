# mora-knode 외부 에이전트 운영 가이드 (dogfooding 권장 패턴)

- 상태: guide (mora-knode 강제 사양 아님)
- 작성일: 2026-04-29
- 이전 문서: `docs/architecture/agent-system-v2.md` (Superseded — 폐기, 본 문서로 이동)
- 적용 범위: NilPop 오너 (ysh) 가 mora-knode 를 dogfooding 할 때 자신의 외부 AI 도구로 어떻게 일을 시킬지에 대한 *권장 운영 패턴*. mora-knode 자체의 사양/구현이 아니다

> **중요**: mora-knode 는 LLM·SDK·모델·키를 모른다 ([ADR-005](../architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md)). 본 문서는 외부에서 자기 에이전트를 운영할 때의 권장 패턴이며, mora-knode 는 어떤 도구로 만들어진 에이전트든 받아준다.

> 본 문서는 운영 패턴 (강제 아님). API 의 정확한 호출 사양 / 운영 모델 비교 / 우선순위·알람 로드맵은 [docs/api/external-agent-api.md](../api/external-agent-api.md) 참조.

## 1. 개요

mora-knode 는 매트릭스 PM 플랫폼이며, 외부 AI 에이전트가 [Agent Identity & API](../architecture/ADR-004-agent-identity-and-api.md) 를 통해 1급 시민으로 일한다. 본 가이드는 다음을 다룬다:

- 사용자가 외부 에이전트를 어떻게 셋업하는지 (Claude Code / Cursor / 자체 봇)
- 권장 역할 분담 (Manager / Developer / Researcher / QA) — 강제 아님
- 권장 워크플로우 (plan 제출 → 검토 → 승인 → 실행)
- Git 워크플로우 / 핸드오프 / 안전 가드 패턴

## 2. 셋업 (외부 도구 측)

### 2.1 mora-knode 에서 받아오는 것
1. **agent identity** 등록 — `Resource.Kind=Agent`, 표시 이름·설명
2. **API 토큰** 발급 — 외부 도구의 환경변수에 저장 (`MORA_KNODE_AGENT_TOKEN`)
3. **권한 (RBAC)** — 어떤 프로젝트의 어떤 task 를 pull/update 할 수 있는지
4. **매트릭스 슬롯** — 가동률 카운트 대상에 포함

### 2.2 외부 도구 자유 선택
- **CrewAI (현재 dogfooding 권장)** — VM 또는 OS 레벨에서 가볍게 핸들링만 담당. **N개 인스턴스** 운영, 각 인스턴스는 **1개 CLI 와 1:1** (CrewAI A ↔ Codex, CrewAI B ↔ Claude Code 등). pod 단위로 VM / 컨테이너 / OS 분리 → test / dev / research 환경이 서로 간섭 없이 병렬 가동. mora-knode 토큰으로 work-queue polling, 깊은 작업은 짝 CLI 를 subprocess 로 호출 (§8.2 의 Layer 1 패턴). CrewAI 자체는 토큰을 거의 안 씀
- **Claude Code** — `.claude/agents/` 의 sub-agent 로 mora-knode 클라이언트 정의
- **Cursor** — 자체 워크스페이스에서 mora-knode MCP 서버 연결
- **자체 봇** — Python/Node/C# 등 자유. mora-knode REST API 만 호출하면 됨
- **여러 도구 혼용** — Manager 는 CrewAI + Claude Code, Developer 는 Cursor, QA 는 자체 봇 — OK

mora-knode 입장에서 모두 동등한 외부 클라이언트.

### 2.3 환경변수 (외부 도구 측 권장)
```
MORA_KNODE_API=http://localhost:5163        # work stack on the same host
# 컨테이너 안이라면:
# MORA_KNODE_API=http://host.docker.internal:5163
# 다른 LAN 머신이라면:
# MORA_KNODE_API=http://192.168.x.x:5163

MORA_KNODE_AGENT_ID=<agent identifier received at registration>
MORA_KNODE_AGENT_TOKEN=<api token received at registration>

# LLM 키는 외부 도구 자기 관리 — mora-knode 는 모름
ANTHROPIC_API_KEY=...   # if using Claude
OPENAI_API_KEY=...       # if using OpenAI
```

> 참고: `tools/*.py` 도 동일하게 `MORA_KNODE_API` 환경변수를 읽는다 (없으면 `http://localhost:5163` default). worktree 별 다른 stack 가리킬 때 `$env:MORA_KNODE_API = "..."` 또는 `MORA_KNODE_API=... python tools/...` 로 override.

## 3. 권장 역할 분담 (강제 아님)

Lean Logic — 작은 매트릭스에서 잘 작동했던 패턴. 매트릭스가 커지면 더 분화 가능.

| 역할 | 책임 | 자주 쓰는 조합 (참고용, 강제 아님) |
|---|---|---|
| Manager | task 분해, plan 작성, acceptance criteria 정의 | Opus 4.7 (`claude-opus-4-7`) — 추론 강도 우선 |
| Developer | 승인된 plan 실행, 코드 작성, PR 생성 | Sonnet 4.6 (`claude-sonnet-4-6`) — 코드 처리량 우선 |
| Researcher | 새 기술/API 탐색, 결과 plan context 로 첨부 | Haiku 4.5 또는 Sonnet 4.6 |
| QA | PR 체크아웃, 테스트 실행, 버그 시 수정 task 생성 | Sonnet 4.6 |

**모델 선택은 운영자 자유** — 위 표는 ysh 의 현재 셋업 예시일 뿐. mora-knode 는 어느 모델을 썼는지 알지 못하며 추적도 안 함 ([ADR-005](../architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md)).

## 4. 권장 워크플로우

### 4.1 Plan 제출 → 검토 → 승인 ([ADR-002](../architecture/ADR-002-manager-approval-gate.md) 의 mora-knode 측 사양과 정합)

```
[사용자 또는 Manager 가 task 생성]
   ↓ (TaskItem 생성, Status=Created)
[Manager 가 plan v1 작성 후 mora-knode 에 제출]
   ↓ POST /api/agents/plans   (taskId 는 request body)
   ↓ (AgentPlan 저장, Status=PendingReview, task.Status → PlanReview)
[리뷰어 (Human/Manager/Reviewer 중 한 명) 가 검토]
   ├─ approve → plan.Status=Approved, task.Status=InProgress
   │            → Developer 에이전트가 work-queue 에서 pull
   ├─ reject  → plan.Status=Rejected (comment 필수), task.Status=InProgress
   │            → Manager 가 새 plan v2 제출 (이전 plan 보존)
   └─ revert  → 검토 결정 무효화 (원 reviewer 또는 Manager), task.Status=PlanReview
```

> 정확한 endpoint 사양 / 응답 형식 / 권한 매트릭스: [API 레퍼런스 §3.2](../api/external-agent-api.md)

mora-knode 측 사양:
- *누가* 만든 plan 인지는 `AgentPlan.SubmittedByResourceId` 에 식별자만 기록
- 같은 task 의 여러 plan 버전을 보존 (revision 메트릭의 데이터 소스). plan 은 **수정 불가**, revise = 새 plan 제출
- revision 5회 초과 시 "기획 난항" 경고 (mora-knode 가 발생, 사용자 직접 개입 필요)

### 4.2 Work-queue Pull 패턴 (Developer/QA 등)

```
[Developer 에이전트 polling, 30s~5m 간격]
   ↓ GET /api/agents/work-queue   (v1: 자기에게 assigned 된 non-terminal task + latest plan)
[클라이언트 사이드 우선순위 정렬 → 첫 task 선택]
   ↓ (예: priority=Urgent → High → Normal, deadline tiebreaker)
[plan.Status=Approved 인 task 만 작업 시작]
   ↓ PUT /api/tasks/{taskId} { status: "InProgress", changeReason, changedBy }
[plan 실행 — 코드 작성 / PR 생성]
[완료 또는 핸드오프]
   ↓ POST /api/tasks/{taskId}/comments  (PR URL / 결과 / 블로커 보고)
   ↓ PUT /api/tasks/{taskId} { status: "WorkReview" }   (사람이 PR 검토)
```

> v1 미구현 (v2 예정): query filter (`?role=`, `?status=`, `?sort=`), `claim/release` lock, `POST /api/agents/runs`. 자세한 트레이드오프와 도입 시점은 [API 레퍼런스 §6 / §8](../api/external-agent-api.md).

### 4.3 사용자 CLI (선택, 외부 도구 자유)

권장 패턴 — 사용자가 매일 5분 안에 검토:
```
mora plans pending                # 검토 대기 plan 목록
mora plans show <task_id>         # plan 내용 + 이전 버전 diff
mora plans approve <task_id>
mora plans revise <task_id> -m "피드백"
mora plans reject <task_id>
```

이건 외부 도구 측 CLI 의 권장 사양. mora-knode 는 REST API 만 제공하고, 사용자가 어떤 CLI 로 호출할지는 자유 (Claude Code skill / 자체 스크립트 등).

## 5. Git 워크플로우 (외부 에이전트 권장 안전 가드)

mora-knode 가 강제하지 않는 가드. 외부 에이전트 도구가 자체 정책으로 적용 권장.

| 행동 | 권장 정책 |
|---|---|
| main / master branch push | 항상 금지 (PR만) |
| force push | 항상 금지 |
| `--no-verify` | 항상 금지 |
| 5개 이상 파일 삭제 | 사람 승인 필수 |
| PR 머지 | 사람 승인 필수 |
| 일일 토큰 예산 초과 | 외부 도구 자체 정책 — mora-knode 는 모름 |

브랜치 명명: `agent/<task_id>-<slug>`
커밋: Conventional Commits ([NilPop CLAUDE.md](../../../../CLAUDE.md))
PR 생성: 에이전트 / PR 머지: 사람

## 6. 핸드오프 프로토콜 (Manager → Developer 권장 페이로드)

mora-knode 의 `AgentPlanHistory.PlanContent` 필드에 저장될 권장 JSON 구조:

```json
{
  "task_id": "...",
  "goal": "<최종 달성 목표>",
  "acceptance_criteria": ["...", "..."],
  "constraints": ["...", "..."],
  "context_refs": [{ "type": "task|doc|url", "id": "..." }],
  "subtasks": [{ "title": "...", "estimate_hours": 0.5 }],
  "risks": ["..."],
  "assumptions": ["..."]
}
```

Manager 는 이 구조에 맞춰 제출, Developer 는 이 구조를 읽어 실행. mora-knode 는 형식을 검증하지 않음 (JSON 문자열로 저장만) — 외부 도구가 Pydantic 등으로 자체 검증 권장.

> **mora-knode 가 형식을 강제하지 않는 이유**: 다양한 외부 에이전트가 자기 도메인에 맞게 plan 구조를 진화시킬 수 있게 함. 표준은 권장이지 강제 아님.

## 7. 비용 / 토큰 추적 (외부 에이전트 자유)

- **mora-knode 는 LLM 비용을 모른다** ([ADR-005](../architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md))
- 외부 에이전트가 *선택적으로* 자기 실행 메트릭을 `AgentRun` 으로 제출 가능 (`InputTokens`, `OutputTokens`, `CostUsd` 모두 optional)
- 제출하면 mora-knode 는 보존만 — 측정·과금·정책 결정 안 함
- 외부 도구 자체적으로 일일 비용 / 토큰 한도 / 자동 중단을 관리 (Claude Code 의 quota, OpenAI 의 budget alerts 등 활용)

## 8. ysh 의 dogfooding 셋업 예시

> 본 §8 의 Layer 1 (CrewAI) / Layer 2 (paired CLI) 패턴은 [docker/agent-pod.Dockerfile](../../docker/agent-pod.Dockerfile) + [docker/agent-pod-README.md](../../docker/agent-pod-README.md) 의 실제 image 로 출발하면 가장 빠르다. base image 는 Debian + Python + Node + git + CrewAI 까지 사전 설치. 짝 CLI (Claude Code / Codex 등) 는 사용자 subscription 에 맞춰 pod 안에서 능동 설치 (ADR-005).

### 8.1 단순 셋업 (시작 단계, 단일 layer)

가장 단순한 셋업 — 외부 에이전트가 LLM 을 직접 호출:

1. mora-knode 에 4개 agent identity 등록: `manager-01`, `developer-01`, `researcher-01`, `qa-01`
2. 각 identity 의 API 토큰을 받아 외부 도구의 환경변수에 입력
3. **Manager** = Claude Code 의 sub-agent 로 정의 (`.claude/agents/manager.md`)
4. **Developer** = Claude Code 의 다른 sub-agent 또는 Cursor (자유)
5. ysh 본인 = 매니저(사람) 역할. plan 검토 / 승인 / PR 머지 담당
6. mora-knode Flutter Web 또는 CLI 로 매일 5분 검토 루프

이 셋업은 강제 아님. ysh 가 다른 도구를 선호하면 자유롭게 변경.

### 8.2 2 layer 위임 패턴 (고급, 강력 권장 — ysh 환경 적합)

ysh 가 가진 자원 (Claude Pro / Cursor Pro / 여러 HW / 가상화 환경) 을 효율적으로 활용하는 패턴. **mora-knode 는 Layer 1 만 봄** — Layer 2 의 존재를 모름 ([ADR-005](../architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md)).

#### 패턴 구조

```
[mora-knode (host)]
       ↑ REST API (agent token)
       │
[Layer 1: 라우팅 / 모니터링 에이전트]
   - 가벼움, 24/7, 무료 / 저비용
   - work-queue polling, complexity 판단, Layer 2 위임
       │
       ↓ subprocess / api / sub-agent
[Layer 2: 깊은 작업 처리 (BYOA, 기 구독 활용)]
   - Claude Code (Claude Pro 구독)
   - Cursor (Cursor Pro 구독)
   - GPT-4 (OpenAI 키)
   - 자체 cli / Ollama 등
```

각 Layer 1 인스턴스 = mora-knode 의 agent identity 1개. Layer 2 = ysh 가 이미 가진 구독 자원 (정액 한도 안에서 추가 비용 0).

#### Layer 1 — 라우팅 / 모니터링 에이전트

| 차원 | 내용 |
|---|---|
| 특징 | 가벼움, 24/7 가동, 비용 거의 0 |
| 역할 | mora-knode work-queue polling → claim → complexity 판단 → Layer 2 위임 → 결과 mora-knode 보고 |
| 도구 후보 | **CrewAI (현재 dogfooding 사용)** / 자체 Python 스크립트 / Cline / OpenHands / opencode / Claude Code sub-agent / GitHub Actions cron |

기본 루프 (Python 예시):
```python
while True:
    tasks = mora_knode.get_work_queue(role=my_role_hint)
    for task in tasks:
        if mora_knode.claim(task.id):
            if task.complexity == "deep":
                result = call_layer_2(task)  # subprocess / api / sub-agent
            else:
                result = simple_local_processing(task)
            mora_knode.report(task.id, result)
    sleep(5)
```

#### Layer 2 — 깊은 작업 처리 (BYOA 활용)

| 도구 | 호출 방식 | 비용 |
|---|---|---|
| Claude Code (Claude Pro) | `subprocess.run(["claude", ...])` 또는 sub-agent | Claude Pro 정액 한도 안 (추가 비용 0) |
| Codex (ChatGPT Pro) | `subprocess.run(["codex", ...])` | ChatGPT Pro 정액 한도 안 (추가 비용 0) |
| Cursor (Cursor Pro) | CLI mode 또는 API | Cursor Pro 정액 한도 안 |
| Gemini / 자체 모델 / Ollama | API 또는 local | 변동 / local 무료 |

Layer 1 이 Layer 2 를 호출하는 인계 패턴 3 옵션 (사용자 자유):

**A. CLI subprocess** — Layer 1 이 Layer 2 의 CLI 를 spawn:
```python
result = subprocess.run(
    ["claude", "--prompt", task.payload],
    capture_output=True, text=True
)
```

**B. API 직접 호출** — Layer 1 이 Layer 2 API 호출:
```python
import anthropic
client = anthropic.Anthropic()  # ANTHROPIC_API_KEY
response = client.messages.create(model="claude-opus-4-7", ...)
```

**C. sub-agent** — Claude Code 안의 sub-agent 시스템:
```markdown
# .claude/agents/router.md (Layer 1)
당신은 mora-knode work-queue 라우터입니다.
깊은 작업은 developer sub-agent 에 위임...

# .claude/agents/developer.md (Layer 2)
당신은 코드 작성 전문 sub-agent 입니다...
```

세 옵션 모두 mora-knode 입장에서 동일 — Layer 1 의 결과만 도착.

#### 여러 HW / 가상화 환경 분산

ysh 가 가진 환경별 Layer 1 분산 예시:

각 환경 = 한 pod = CrewAI 인스턴스 1개 + 짝 CLI 1개 (1:1).

| 환경 | Layer 1 인스턴스 (예시) | Layer 2 도구 (예시, pod 마다 1개) |
|---|---|---|
| 노트북 (24/7) | `crewai-laptop` (Manager 역할) | Claude Code (Claude Pro) |
| 데스크탑 (낮 시간) | `crewai-desktop` (Developer 역할) | Codex (ChatGPT Pro) |
| VM / 가상화 1 | `crewai-vm-1` (QA 역할) | 자체 테스트 봇 (LLM 무관) |
| VM / 가상화 2 | `crewai-vm-2` (Researcher 역할) | Claude Code (다른 Pro 구독) |

mora-knode 매트릭스에는 4개 agent identity 등록. work-queue 에 task 가 들어오면 *경쟁* — 먼저 claim 한 인스턴스가 가져감 (mora-knode 의 lock 메커니즘).

#### 비용 / quota 관리 (Layer 2 측 책임)

mora-knode 는 비용 측정 안 함 ([ADR-005](../architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md)). Layer 1 이 Layer 2 호출 시:
- Layer 2 의 quota / rate limit 를 Layer 1 이 자체 관리
- Claude Pro 5시간 한도 / Cursor Pro 월 fast request / GPT-4 토큰 비용 등
- Layer 1 의 fallback 로직 (예시): Claude Code 한도 초과 시 → Cursor 로 위임 → 자체 모델 → 사용자에게 알림

선택적: Layer 1 이 자기 사용량을 mora-knode 에 `AgentRun` 메트릭으로 제출. mora-knode 는 보존만 — 측정 / 정책 결정 안 함.

#### 통합 체크리스트

dogfooding 시작 시:
1. 각 Layer 1 인스턴스에 대해 mora-knode agent identity 등록
2. RBAC 프리셋 적용 (Manager / Developer / Reviewer / QA)
3. API 토큰 발급 → Layer 1 환경변수 (`MORA_KNODE_AGENT_TOKEN`) 입력
4. Layer 2 도구 셋업 (Claude Code / Cursor / API 키 등) — Layer 1 환경변수 또는 OS 자격증명에 보관
5. Layer 1 의 polling 주기 / lock timeout / Layer 2 호출 방식 / fallback 정책 설정
6. mora-knode work-queue 에 test task 1개 → end-to-end 검증

#### 8.1 vs 8.2 — 어느 걸 선택할지

| 차원 | 8.1 단순 셋업 | 8.2 2 layer 위임 |
|---|---|---|
| 셋업 복잡도 | 낮음 | 중 (Layer 1 routing 로직 필요) |
| 비용 | LLM 호출 시마다 발생 | Layer 1 무료 + Layer 2 만 정액 한도 |
| HW 분산 | 단일 환경 | 여러 환경 (노트북 / VM / 가상화) |
| 24/7 가동 | 외부 도구 가동 시에만 | Layer 1 always-on |
| ysh 환경 적합도 | M2 dogfooding 시작 첫 주 | M2 dogfooding 안정화 후 |

**권장 진행**: M2 dogfooding 시작 첫 주는 8.1 (단순) 로 검증 → end-to-end 작동 확인 → 8.2 (2 layer) 로 진화. 처음부터 8.2 시도 시 디버깅 표면적 폭증.

## 9. 본 가이드의 mora-knode 사양과의 분리

| 영역 | mora-knode 사양 (강제) | 본 가이드 (권장) |
|---|---|---|
| Agent identity 등록 / API 토큰 / RBAC | ✓ ([ADR-004](../architecture/ADR-004-agent-identity-and-api.md)) | — |
| Plan 제출 / 검토 / 승인 게이트 | ✓ ([ADR-002](../architecture/ADR-002-manager-approval-gate.md)) | — |
| Work-queue API | ✓ ([ADR-004](../architecture/ADR-004-agent-identity-and-api.md)) | — |
| Audit trail / revision 메트릭 | ✓ | — |
| Manager / Developer 역할 분담 | — | ✓ |
| Plan JSON 구조 (`acceptance_criteria` 등) | — | ✓ |
| Git 안전 가드 (main push 금지 등) | — | ✓ (외부 도구 자체 적용) |
| 모델 선택 (Opus / Sonnet) | — | ✓ |
| 비용 추적 | — | ✓ (외부 도구 자체 관리) |

## 10. 관련 문서

- [../architecture/ADR-002-manager-approval-gate.md](../architecture/ADR-002-manager-approval-gate.md) — Plan 제출/검토/승인 게이트 (mora-knode 측)
- [../architecture/ADR-004-agent-identity-and-api.md](../architecture/ADR-004-agent-identity-and-api.md) — Agent Identity & API
- [../architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md](../architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md) — LLM 비차별 원칙
- [../architecture/schema-integration-for-agents.md](../architecture/schema-integration-for-agents.md) — mora-knode 스키마 (외부 에이전트 협업 지원)
- [../prd.md](../prd.md) — PRD
- [../research/2026-04-29-ai-agent-trends-fit-review.md](../research/2026-04-29-ai-agent-trends-fit-review.md) — 적합도 검토
