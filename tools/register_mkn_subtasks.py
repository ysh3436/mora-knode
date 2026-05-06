"""Register the MK-N implementation breakdown as in-app tasks.

Promotes the existing "Task sequential number (MK-N) + 번호순 정렬" task
to a parent (priority High, spanning dates), and creates 4 child PRs
underneath. Idempotent only on parent edit — re-running creates more
children, so guard with grep before re-running.
"""
import json
import urllib.request

import os
BASE = os.environ.get("MORA_KNODE_API", "http://localhost:5163")
PROJECT_ID = "69f4404e24095755bdd41bdb"  # mora-knode itself
PARENT_ID = "69f48856f97eed91f6c10eab"   # existing MK-N task


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


def main():
    # 1. Promote parent: priority High + date span
    parent = get_task(PARENT_ID)
    parent["priority"] = "High"
    parent["currentTimeline"] = all_day("2026-05-01", "2026-05-05")
    parent["originTimeline"] = all_day("2026-05-01", "2026-05-05")
    parent["changeReason"] = "promote to MK-N implementation parent"
    parent["changedBy"] = "ysh"
    put_task(PARENT_ID, parent)
    print(f"OK parent: {parent['title']} -> High, 05-01~05-05")

    # 2. Create 4 child PRs
    children = [
        {
            "title": "PR A — MK-N 번호 시스템 토대 (필드 + 마이그레이션 + 표시)",
            "description": (
                "task 식별자 MK-N 의 데이터 기반과 List/Inspector 표시. "
                "검색·정렬·간트 표시 같은 후속 PR 들의 토대."
            ),
            "dates": ("2026-05-01", "2026-05-02"),
        },
        {
            "title": "PR B — MK-N 번호순 정렬 + 직접 검색",
            "description": (
                "번호순 정렬 키 추가 (▲▼ 일관 패턴) 와 'MK-12' 식 검색어 직접 매칭."
            ),
            "dates": ("2026-05-03", "2026-05-03"),
        },
        {
            "title": "PR C — Gantt 타이틀 컬럼 가변 너비 + MK-N 표시",
            "description": (
                "Gantt 의 타이틀 컬럼에 drag-handle 추가로 폭 조절 가능. "
                "row 에 MK-N 배지 표시."
            ),
            "dates": ("2026-05-04", "2026-05-04"),
        },
        {
            "title": "PR D — 인스펙터 inline number 편집 + 충돌 거부",
            "description": (
                "인스펙터에서 number 직접 수정. 다른 task 와 충돌 시 변경 거부 + 사용자 알림."
            ),
            "dates": ("2026-05-05", "2026-05-05"),
        },
    ]

    for c in children:
        s, e = c["dates"]
        payload = {
            "projectId": PROJECT_ID,
            "parentTaskId": PARENT_ID,
            "title": c["title"],
            "description": c["description"],
            "status": "NotStarted",
            "priority": "High",
            "currentTimeline": all_day(s, e),
            "originTimeline": all_day(s, e),
            "realTimeline": {"start": None, "end": None, "isAllDay": True},
        }
        created = post_task(payload)
        print(f"OK child: {created['id']}  {created['title'][:60]}")

    print("Done.")


if __name__ == "__main__":
    main()
