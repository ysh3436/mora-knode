"""Phase 1.5 — split Sat-Tue work into Track 1 / Track 2 parallel lanes.

Repurposes MK-77 / MK-78 as the two track parents (instead of single-day
PRs), cancels MK-79 (its scope is absorbed into the tracks), and creates 6
new children — one per (track x day) cell.

Final tree under MK-75:
  MK-76  sketch                                [Done]
  MK-77  Track 1 (main worktree — backend)     [parent]
    ├── 토 agent identity + middleware
    ├── 일 plan gate + work-queue (β)
    └── 월 plan review UI 통합
  MK-78  Track 2 (side worktree — matrix+UI)   [parent]
    ├── 토 matrix teams data layer
    ├── 일 agent UI 스켈레톤
    └── 월 matrix filter UI
  MK-79  [Cancelled — absorbed into Track 1/2]
  MK-80  화 README + 공개 토글                  [unchanged]

Run once. Re-running creates duplicate children — guard by checking that
MK-77 children currently number 0 (script asserts this).
"""
import json
import sys
import urllib.request
import io

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

import os
BASE = os.environ.get("MORA_KNODE_API", "http://localhost:5163")
PROJECT_ID = "69f4404e24095755bdd41bdb"
PARENT_ID = "69f4b3ef114fed107bb64afe"  # MK-75
MK77 = "69f4b3ef114fed107bb64b00"
MK78 = "69f4b3ef114fed107bb64b01"
MK79 = "69f4b3ef114fed107bb64b02"


def get_task(tid):
    with urllib.request.urlopen(f"{BASE}/api/tasks/{tid}") as r:
        return json.load(r)


def put_task(tid, payload):
    req = urllib.request.Request(
        f"{BASE}/api/tasks/{tid}",
        data=json.dumps(payload).encode("utf-8"),
        method="PUT",
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req) as r:
        return json.load(r)


def post_task(payload):
    req = urllib.request.Request(
        f"{BASE}/api/projects/{PROJECT_ID}/tasks",
        data=json.dumps(payload).encode("utf-8"),
        method="POST",
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req) as r:
        return json.load(r)


def all_day(s, e):
    return {
        "start": f"{s}T00:00:00Z",
        "end": f"{e}T23:59:59.999Z",
        "isAllDay": True,
    }


def assert_safe_to_run():
    with urllib.request.urlopen(
        f"{BASE}/api/projects/{PROJECT_ID}/tasks/hierarchy"
    ) as r:
        all_tasks = json.load(r)
    for tid in (MK77, MK78):
        kids = [t for t in all_tasks if t.get("parentTaskId") == tid]
        if kids:
            raise SystemExit(
                f"refusing to run — {tid} already has {len(kids)} children"
            )


def main():
    assert_safe_to_run()

    # 1. MK-77 → Track 1 parent
    t1 = get_task(MK77)
    t1["title"] = "Track 1 — main worktree (backend-focused)"
    t1["description"] = (
        "병렬 작업의 메인 트랙. 외부 agent 가 1급 시민으로 들어오는 백엔드 핵심 — "
        "agent identity 토대부터 plan gate, plan review UI 통합까지. "
        "main worktree (port 5163, db mora_knode) 에서 진행."
    )
    t1["currentTimeline"] = all_day("2026-05-02", "2026-05-04")
    t1["originTimeline"] = all_day("2026-05-02", "2026-05-04")
    t1["priority"] = "High"
    t1["changeReason"] = "split into Track 1 (main worktree, 3 days)"
    t1["changedBy"] = "ysh"
    put_task(MK77, t1)
    print(f"OK MK-77 -> Track 1 parent")

    # 2. MK-78 → Track 2 parent
    t2 = get_task(MK78)
    t2["title"] = "Track 2 — side worktree (matrix + UI)"
    t2["description"] = (
        "병렬 작업의 서브 트랙. 매트릭스 조직 데이터 레이어부터 agent UI 스켈레톤, "
        "팀 필터 UI 까지. side worktree (port 5102, db mora_knode_t2) 에서 진행해 "
        "main 과 파일 충돌 없이 진행."
    )
    t2["currentTimeline"] = all_day("2026-05-02", "2026-05-04")
    t2["originTimeline"] = all_day("2026-05-02", "2026-05-04")
    t2["priority"] = "High"
    t2["changeReason"] = "split into Track 2 (side worktree, 3 days)"
    t2["changedBy"] = "ysh"
    put_task(MK78, t2)
    print(f"OK MK-78 -> Track 2 parent")

    # 3. Cancel MK-79
    t3 = get_task(MK79)
    t3["status"] = "Cancelled"
    t3["changeReason"] = (
        "absorbed into Track 1/2 split — Monday work is now MK-{T1.월} + MK-{T2.월}"
    )
    t3["changedBy"] = "ysh"
    put_task(MK79, t3)
    print(f"OK MK-79 -> Cancelled")

    # 4. Track 1 children (3)
    track1_kids = [
        {
            "title": "토 — agent identity + middleware",
            "description": (
                "AgentToken 도메인/repo + /api/agents 엔드포인트 + middleware Bearer "
                "분기 + X-Agent-Id 검증. raw 토큰은 mk_ prefix + 32자, 응답 1회만 반환."
            ),
            "dates": ("2026-05-02", "2026-05-02"),
        },
        {
            "title": "일 — plan gate + work-queue (β)",
            "description": (
                "AgentPlan + PlanStatus + /api/agents/plans (POST/list/approve/reject) "
                "+ /api/agents/work-queue + tools/demo_agent_flow.sh E2E."
            ),
            "dates": ("2026-05-03", "2026-05-03"),
        },
        {
            "title": "월 — plan review UI 통합",
            "description": (
                "AppSection.agents 화면의 plan review 큐를 /api/agents/plans 와 연결. "
                "approve/reject 동작 + E2E 시나리오 브라우저 검증."
            ),
            "dates": ("2026-05-04", "2026-05-04"),
        },
    ]

    # 5. Track 2 children (3)
    track2_kids = [
        {
            "title": "토 — matrix teams data layer",
            "description": (
                "Department 도메인 (parentDepartmentId 트리, leadResourceId) + repo + "
                "/api/departments + Resource.DepartmentId + Project.MemberResourceIds "
                "+ Matrix ?departmentId=/?projectId= 필터."
            ),
            "dates": ("2026-05-02", "2026-05-02"),
        },
        {
            "title": "일 — agent 관리 UI 스켈레톤",
            "description": (
                "AppSection.agents 라우트 + agent 목록/생성/토큰 발급 화면 (raw 토큰 1회 표시). "
                "토 머지된 /api/agents 만 의존, plan review 는 월에 통합."
            ),
            "dates": ("2026-05-03", "2026-05-03"),
        },
        {
            "title": "월 — matrix 팀 필터 UI",
            "description": (
                "Resources/Matrix 화면에 department/project 필터 드롭다운 추가. "
                "토 머지된 ?departmentId=/?projectId= 쿼리 사용."
            ),
            "dates": ("2026-05-04", "2026-05-04"),
        },
    ]

    for parent_id, kids, label in [
        (MK77, track1_kids, "Track 1"),
        (MK78, track2_kids, "Track 2"),
    ]:
        for c in kids:
            s, e = c["dates"]
            payload = {
                "projectId": PROJECT_ID,
                "parentTaskId": parent_id,
                "title": c["title"],
                "description": c["description"],
                "status": "NotStarted",
                "priority": "High",
                "currentTimeline": all_day(s, e),
                "originTimeline": all_day(s, e),
                "realTimeline": {"start": None, "end": None, "isAllDay": True},
            }
            created = post_task(payload)
            print(f"OK {label} child: MK-{created.get('number','?')}  {created['title'][:60]}")

    print("Done.")


if __name__ == "__main__":
    main()
