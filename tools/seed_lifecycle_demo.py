"""Seed a "Lifecycle demo" task tree so all 9 states + IsWaiting can be
browsed visually after the v2 migration.

Creates one parent + 9 children (one per TaskStatus value) under the
mora-knode self-tracking project. Two of them have IsWaiting=true so the
hourglass overlay is visible. Sets are done via the public API so the
ChangeLog records them with reason="lifecycle demo seed".
"""
import json
import sys
import io
import urllib.request

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

BASE = "http://localhost:5163"
PROJECT_ID = "69f4404e24095755bdd41bdb"


def post_task(payload):
    req = urllib.request.Request(
        f"{BASE}/api/projects/{PROJECT_ID}/tasks",
        data=json.dumps(payload).encode("utf-8"),
        method="POST",
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req) as r:
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


def get_task(tid):
    with urllib.request.urlopen(f"{BASE}/api/tasks/{tid}") as r:
        return json.load(r)


def main():
    # 1. Parent
    parent = post_task({
        "projectId": PROJECT_ID,
        "title": "Lifecycle demo — 9개 상태 + IsWaiting 예제",
        "description": (
            "각 lifecycle 상태별 1개씩 자식 task. 인스펙터에서 picker 옵션, "
            "pill 색, ⏳ 오버레이를 시각적으로 확인하기 위한 데모. "
            "실제 추적과 무관 — 검증 후 자유 삭제."
        ),
        "status": "Created",
        "priority": "Low",
        "currentTimeline": {"start": "2026-05-02T00:00:00Z", "end": "2026-05-02T23:59:59.999Z", "isAllDay": True},
        "originTimeline": {"start": "2026-05-02T00:00:00Z", "end": "2026-05-02T23:59:59.999Z", "isAllDay": True},
        "realTimeline": {"start": None, "end": None, "isAllDay": True},
    })
    print(f"OK parent MK-{parent['number']}  id={parent['id']}")

    # 2. 9 children, one per state. Two with IsWaiting=true.
    states = [
        ("Created",     False, "user 가 task 막 만든 직후 — bot 이 pickup 대기"),
        ("Planning",    False, "bot 이 plan 작성 중 (picker 에 안 보임 — bot-driven)"),
        ("PlanReview",  False, "bot 이 plan 제출, user 검토 대기 (picker 에 안 보임)"),
        ("InProgress",  True,  "bot 작업 중 + 무언가 막힘 (⏳ 오버레이 데모)"),
        ("WorkReview",  False, "bot 이 작업 완료 선언, user 코드 리뷰 대기"),
        ("OnHold",      False, "user 가 능동 보류 (능동 결정, ⏳ 와 다름)"),
        ("Done",        False, "review 승인되어 완료"),
        ("Cancelled",   False, "계획 단계 취소 (작업 시작 전/직후)"),
        ("Dropped",     True,  "작업 후 폐기 — IsWaiting 도 켜둬서 두 의미 구분 데모"),
    ]

    created_ids = []
    for status, waiting, desc in states:
        # 1st step: create with status=Created (default)
        child = post_task({
            "projectId": PROJECT_ID,
            "parentTaskId": parent["id"],
            "title": f"[데모] {status}",
            "description": desc,
            "status": "Created",
            "priority": "Low",
            "currentTimeline": {"start": "2026-05-02T00:00:00Z", "end": "2026-05-02T23:59:59.999Z", "isAllDay": True},
            "originTimeline": {"start": "2026-05-02T00:00:00Z", "end": "2026-05-02T23:59:59.999Z", "isAllDay": True},
            "realTimeline": {"start": None, "end": None, "isAllDay": True},
        })
        # 2nd step: PUT to target status + IsWaiting (so ChangeLog records the transition)
        child["status"] = status
        child["isWaiting"] = waiting
        child["changeReason"] = "lifecycle demo seed"
        child["changedBy"] = "system"
        updated = put_task(child["id"], child)
        created_ids.append((status, updated["number"], updated["id"], waiting))
        print(f"OK MK-{updated['number']:>3}  status={updated['status']:<12} isWaiting={str(updated['isWaiting']):<5} {desc[:50]}")

    print()
    print(f"Demo tree: parent MK-{parent['number']}  + {len(created_ids)} children")
    print()
    print("Browser 에서 확인할 것:")
    print("  - 인스펙터 picker 옵션 7개 (Planning/PlanReview 안 보임)")
    print("  - 각 자식의 status pill 색 9가지 모두 다름")
    print("  - InProgress / Dropped 자식에 ⏳ 오버레이 표시")
    print("  - OnHold (능동 보류) 와 InProgress+⏳ (대기) 시각적 구분")
    print("  - 부모의 computedStatus 가 자식들로부터 rollup (대부분 자식이 active+terminal 혼재 → InProgress)")


if __name__ == "__main__":
    main()
