"""Register the MK-110 self-hosted infrastructure tree as in-app tasks.

Creates one root MK-110 ("Self-hosted infrastructure") under the
"mora-knode itself" project, then 7 child tasks (MK-110.1 ~ MK-110.7).
The five children whose work is already shipped on master at run time
are marked Done with a short ChangeLog reason; the two waiting on
Docker Desktop install (Gitea first-run + host-mongod cutover) stay
as Created.

Idempotent on title — checks the project's task list first and skips if
the MK-110 root title already exists.

Usage:
    python tools/register_mk110.py
    MORA_KNODE_API=http://localhost:5163 python tools/register_mk110.py
"""
from __future__ import annotations

import io
import json
import os
import sys
import urllib.request

# Windows 콘솔 cp949 codec 회피 — em-dash 등 유니코드를 그대로 출력.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
else:
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

BASE = os.environ.get("MORA_KNODE_API", "http://localhost:5163")
PROJECT_ID = "69f4404e24095755bdd41bdb"  # mora-knode itself
HUMAN_ID = "69f33ac19970f43fa673b115"     # ysh — for ChangedBy attribution

ROOT_TITLE = "Self-hosted infrastructure (work stack + Gitea + AI agent pod)"
ROOT_DESC = (
    "M2 dogfooding 진입 직전 단일 self-hosted 인프라 셋업. mongo + backend + "
    "frontend + Gitea 한 stack (always-on) + AI agent pod base image. "
    "host mongod 폐지 + cutover. ADR-010 결정. dev/test isolation 은 pod "
    "측에서 처리 (mora-knode 측 stack 분기 안 함)."
)


def get(path: str):
    with urllib.request.urlopen(f"{BASE}{path}") as r:
        return json.load(r)


def post_task(payload: dict) -> dict:
    req = urllib.request.Request(
        f"{BASE}/api/projects/{PROJECT_ID}/tasks",
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        method="POST",
    )
    req.add_header("Content-Type", "application/json")
    req.add_header("X-Dev-User-Id", HUMAN_ID)
    with urllib.request.urlopen(req) as r:
        return json.load(r)


def put_task(tid: str, payload: dict) -> dict:
    req = urllib.request.Request(
        f"{BASE}/api/tasks/{tid}",
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        method="PUT",
    )
    req.add_header("Content-Type", "application/json")
    req.add_header("X-Dev-User-Id", HUMAN_ID)
    with urllib.request.urlopen(req) as r:
        return json.load(r)


def all_day(start: str, end: str) -> dict:
    return {
        "start": f"{start}T00:00:00Z",
        "end": f"{end}T23:59:59.999Z",
        "isAllDay": True,
    }


# (title, description, status_after, change_reason)
CHILDREN = [
    (
        "MK-110.1 docker-compose.yml + .env.example + .gitattributes",
        "단일 work stack 의 mongo + backend + frontend + Gitea 4개 service 와 env override 표면을 잡는 인프라 코드. dev.yml 폐기, .gitattributes 로 Windows CRLF 회피.",
        "Done",
        "shipped (chore/docker-compose-single-stack)",
    ),
    (
        "MK-110.2 Gitea 첫 셋업 + admin user / repo push 검증",
        "work stack 시작 후 http://localhost:3000 에서 admin 계정 만들고 mora-knode repo 생성, git remote add gitea + push 까지 1회 검증. SSH 는 옵션 (HTTP 만으로 충분).",
        "Created",
        None,
    ),
    (
        "MK-110.3 Cutover — host mongod → docker mongo",
        "host 의 mongod (mora_knode_dev) 를 mongodump → mongorestore --nsTo mora_knode_work 로 docker mongo 로 1회 이전. host mongod 영구 비활성화. 절차/롤백은 docker/README §C.",
        "Created",
        None,
    ),
    (
        "MK-110.4 tools/ 17개 BASE 환경변수 통일 (MORA_KNODE_API)",
        "demo / seed / bulk / migrate / mark / fix / cleanup / restructure / register / test 스크립트가 모두 os.environ.get('MORA_KNODE_API', 'http://localhost:5163') 패턴을 쓰도록 일괄 변경. AI agent pod 가 host.docker.internal 등 다른 base URL 가리킬 수 있게.",
        "Done",
        "shipped (chore/tools-env-base)",
    ),
    (
        "MK-110.5 agent-pod base image (Dockerfile + bundled context + scaffold + entrypoint + README)",
        "docker/agent-pod.Dockerfile (Standard − 짝 LLM CLI) + /opt/mora-knode-context/ (api ref / workflow guide / 4 sub-agent template / CrewAI recipe) + mora-pod-scaffold + entrypoint health/token check + 운영 README.",
        "Done",
        "shipped (chore/agent-pod-base-image)",
    ),
    (
        "MK-110.6 docs 동기화 (README + agent-operations + external-agent-api + docker/README)",
        "Quick Start 를 Docker work stack 우선으로 재구조화, status 에 Phase 2 infra 행 추가, BYOA 셋업에 pod 변형 추가, agent-operations §2.3 의 stale localhost:5000 정정, external-agent-api §5.2 에 host.docker.internal 변형 명시.",
        "Done",
        "shipped (docs/api-readme-stack-update)",
    ),
    (
        "MK-110.7 ADR-010 신설 + 통합 검증",
        "단일 work stack + Gitea + agent-pod isolation + cutover + base image 범위 + tools env 6개 결정을 ADR-010 으로 lock-in. 검증은 docker compose up + curl /health + demo_agent_flow.py + agent-pod 부팅까지 (마지막 두 항목은 Docker 설치 후 진행).",
        "Done",
        "shipped (docs/adr-010-self-hosted-infra)",
    ),
]


def main() -> int:
    # idempotency guard
    existing = get(f"/api/projects/{PROJECT_ID}/tasks/hierarchy")
    if any(t["title"] == ROOT_TITLE for t in existing):
        print(f"skip: '{ROOT_TITLE}' already exists; nothing to do.")
        return 0

    # 1. root
    root_payload = {
        "projectId": PROJECT_ID,
        "title": ROOT_TITLE,
        "description": ROOT_DESC,
        "status": "InProgress",
        "priority": "High",
        "currentTimeline": all_day("2026-05-07", "2026-05-10"),
        "originTimeline": all_day("2026-05-07", "2026-05-10"),
    }
    root = post_task(root_payload)
    print(f"OK  root  MK-{root['number']:>3}  {root['title'][:60]}")

    # 2. seven children, with status_after applied via PUT for the Done ones
    for i, (title, desc, status_after, reason) in enumerate(CHILDREN, start=1):
        # day mapping: 1/4/5/6/7 = Done quickly on 5/7~5/10; 2/3 = Created waiting Docker
        if status_after == "Done":
            dates = ("2026-05-07", "2026-05-10")
        else:
            dates = ("2026-05-08", "2026-05-09")

        child_payload = {
            "projectId": PROJECT_ID,
            "parentTaskId": root["id"],
            "title": title,
            "description": desc,
            "status": "Created",
            "priority": "High",
            "currentTimeline": all_day(*dates),
            "originTimeline": all_day(*dates),
        }
        child = post_task(child_payload)
        print(f"OK  child MK-{child['number']:>3}  {child['title'][:60]}")

        if status_after != "Created":
            child["status"] = status_after
            child["changeReason"] = reason or f"shipped"
            child["changedBy"] = "ysh"
            put_task(child["id"], child)
            print(f"     → {status_after}  ({reason})")

    print("\ndone.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
