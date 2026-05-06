# ADR-010: Single self-hosted work stack + AI agent pod isolation

- 상태: Accepted
- 날짜: 2026-05-06
- 연관: [ADR-005 (LLM 비차별 원칙)](ADR-005-mora-knode-does-not-orchestrate-llms.md), [ADR-006 (BYOA 5분 셋업 UX)](ADR-006-byoa-onboarding-ux.md), [docs/api/external-agent-api.md](../api/external-agent-api.md), [docs/dogfooding/agent-operations.md](../dogfooding/agent-operations.md)

## Context

M2 dogfooding (2026-05-22 시작) 진입을 앞두고 운영 인프라가 다음 갭을 가진다:

1. **단일 host mongod 가 운영/테스트 데이터 섞임**. 현재 host 에 직접 설치된 mongod (`mora_knode_dev` DB) 한 곳에 in-app dogfooding 데이터 ("mora-knode itself" 프로젝트, MK-N task 트리), 데모 데이터 (`[데모] xxx`), 그리고 자동 회귀 (`tools/demo_*.py` 가 생성하는 smoke-bot-* 데이터) 가 모두 들어간다. M2 의 핵심 narrative 인 dogfooding 메트릭 (revision count / cycle time, MK-104) 의 신뢰도를 확보할 수 없다.

2. **README 의 Quick Start 가 호스트 모드 가정**. `dotnet run + flutter run + 호스트 mongod` 흐름이 1순위로 적혀 있으나, 실제 dogfooding 환경 (CrewAI pod ↔ mora-knode REST + Gitea) 에 맞지 않는다. 신규 외부 사용자가 README 만 따라 하면 self-hosted 의 핵심을 놓친다.

3. **외부 의존성 0 narrative 가 미실현**. Gitea 같은 self-hosted git 서버가 없어 PR 흐름이 GitHub 외부에 묶인다. M3 오픈소스 공개 시 핵심 셀링 포인트인 "self-hosted self-hosted" demo 가 안 된다.

4. **dev / test isolation 패턴 미정**. 5/5 머지된 [chore/docker-coordination](../../docker-compose.dev.yml) 은 mora-knode 자체를 다중 stack (work / dev / test) 으로 운영하는 방향을 prototype 했으나, 이 방향은 (a) 5+ docker stack 운영 부담, (b) port / DB / .env 분기 복잡, (c) AI agent 가 어느 stack 에 talk 해야 할지 불명확. 단순화 필요.

## Decision

### 1. mora-knode 자체는 단일 docker stack (work, always-on)

`docker-compose.yml` 한 파일로 mongo + backend + frontend + Gitea 4개 service 를 한 묶음에 운영. profiles / -p project name 으로 멀티 stack 분기하지 않는다. 모든 in-app task / agent token / plan / work-queue / git remote 가 이 한 stack 에 산다.

이유:
- 5/5 prototype 의 다중 stack 분기는 설정 복잡도가 가치 대비 컸다 — 5개 .env, 5세트 port, 5개 DB
- 1인 dogfooding 단계는 데이터 격리가 prefix 만으로 충분 (`[smoke-N]`, `[pod-a-test]`)
- 멀티 머신 분산 / cloud 배포는 M4 cloud alpha 의 별도 ADR 로 미룸

### 2. Gitea 를 work stack 의 4번째 service 로 포함

`gitea/gitea:1` image, SQLite storage. 1인 dogfooding 단계는 SQLite 로 충분. PostgreSQL 전환은 multi-machine / 외부 사용자 다수 시점 (M5+) 에 별도 결정.

이유:
- self-hosted self-hosted demo 가 M3 narrative 의 핵심
- Gitea webhook / Actions 통합은 별도 task — 본 ADR 은 git remote + UI 까지만

### 3. Host mongod 폐지 + docker mongo 단일 source of truth

Cutover 1회: `mongodump mora_knode_dev → mongorestore mora_knode_work (in docker)`. 절차는 [docker/README.md](../../docker/README.md) §C 에. host mongod 는 영구 비활성화 (uninstall 은 보류 — fallback 보존).

이유:
- 단일 source 가 dogfooding KPI 의 신뢰도 확보 전제
- host mongod / docker mongo 병행은 port 충돌 + 어느 쪽이 진실인지 모호

### 4. dev / test isolation 은 AI agent pod 측에서

mora-knode 측에 dev/test stack 을 두지 않는다. 대신 외부 AI agent 가 자기 docker container (`docker/agent-pod.Dockerfile`) 안에서 격리. 같은 work stack DB 를 가리키되 prefix (`[smoke-N]`, `[pod-a-test]`) 로 데이터 분리.

이 방향이 README L31~63 의 "N CrewAI pods with 1:1 CLI pairing per isolated env" 다이어그램과 일치 — mora-knode 는 host, AI agent 는 pod.

### 5. AI agent pod base image = Standard − 짝 LLM CLI

`docker/agent-pod.Dockerfile` (Debian + Python + Node.js + git + curl + ssh + jq + CrewAI~=0.140 + bundled context + scaffold + entrypoint). 짝 LLM CLI (Claude Code / Codex / Cline / 자체 봇) 는 image 에 포함하지 않는다 — 사용자가 자기 subscription (Claude Pro / ChatGPT Pro / ...) 에 맞춰 pod 안에서 능동 설치 또는 host binary mount.

이유:
- ADR-005 의 "LLM/도구 무관" 원칙과 정합 — image 가 특정 CLI 묶으면 종속성 + 카테고리 흐림
- 사용자 subscription 자유 (paid CLI 마다 별도 구매 / login)
- 사전 번들된 context (`/opt/mora-knode-context/`) + scaffold 자동화 (`mora-pod-scaffold`) 로 첫 셋업 부담은 최소화

### 6. tools/ 의 BASE URL 은 환경변수 통일

`tools/*.py` 17개가 모두 `BASE = os.environ.get("MORA_KNODE_API", "http://localhost:5163")` 패턴. AI agent pod / 외부 도구가 자기 환경에 맞춰 base URL 을 override 가능 (예: `http://host.docker.internal:5163`, `http://192.168.x.x:5163`).

## Consequences

### Positive

- mora-knode infra 가 **compose 1개 / .env 1개 / port 1세트** 로 단순
- 데이터 격리는 work db 안의 prefix 로 — 5개 db 관리 부담 0
- self-hosted self-hosted (mora-knode + Gitea) 가 M3 demo narrative 의 핵심 자산
- AI agent pod 가 base image 1개 + 사용자 자유 (짝 CLI / SDK) 로 카테고리 정합성 + 셋업 자유 동시 확보
- worktree 별 docker stack 띄울 필요 없음 — 한 stack 에 다수 pod container 가 talk

### Negative / 위험

- **schema 호환성**: 모든 worktree 의 backend 가 같은 work db 가리키므로, schema 변경 (enum 추가, 새 collection 등) 시 worktree 간 코드 호환을 미리 합의해야 한다. AI agent 가 schema 변경 PR 을 머지하기 전에 다른 worktree 의 backend 를 stop 해야 할 수도 있다.
- **단일 mongo 장애 = 전체 정지**: host mongod 도 동일했지만 docker container 는 추가 의존 (Docker Desktop 자체 가용성).
- **D 드라이브 IO 제약**: Docker Desktop on Windows 11 의 WSL2 backend 가 D 드라이브 mount 를 C 드라이브 대비 느리게 처리 가능. 첫 빌드 5~10min 가 더 길어질 수 있다.

### Future work (별도 ADR)

- **ADR-011 후보**: Gitea push event → mora-knode task status 자동 전환 (webhook 통합)
- **ADR-012 후보**: Gitea Actions (CI) — PR 머지 시 자동 image rebuild + redeploy
- **ADR-013 후보**: Multi-machine 분산 (cloud alpha M4) — backend / frontend / mongo 머신 분리
- **ADR-014 후보**: PostgreSQL 전환 (Gitea storage) — SQLite 한계 도달 시
- **검토**: agent-pod 안에 .NET / Flutter SDK 포함 여부 (mora-knode 자체 재빌드 사용자 비중에 따라)

## 검증

본 ADR 의 효과는 다음 4가지로 검증:

1. `docker compose up -d` 로 work stack 4 service 모두 healthy
2. Cutover 후 `curl /api/projects` 응답에 "mora-knode itself" 보존
3. `MORA_KNODE_API=http://localhost:5163 python tools/demo_agent_flow.py` → ALL OK
4. agent-pod 컨테이너 부팅 시 entrypoint 가 health check + token 검증 통과

## 관련 문서

- [docs/api/external-agent-api.md](../api/external-agent-api.md) — REST 사양 (모든 stack URL 결정의 진실 원천)
- [docs/dogfooding/agent-operations.md](../dogfooding/agent-operations.md) — 운영 패턴 (Layer 1 / Layer 2 가 본 ADR 의 agent-pod 와 정렬)
- [docker/README.md](../../docker/README.md) — work stack 운영 + cutover 절차
- [docker/agent-pod-README.md](../../docker/agent-pod-README.md) — pod 운영 가이드
- [docs/planning/TODO.md](../planning/TODO.md) — Phase 2 일정 (MK-110 신규 root)
