"""Populates the audit feed with one of each entity type so the
변경이력 통합 페이지 has something to show across all three filters
(Project / Task / Milestone). Idempotent-ish: each run creates a
fresh demo project + edits, so re-running just adds more activity.

What it does:
  1. Create a demo project "[데모] Audit showcase {timestamp}"
  2. Edit the project (name + status + description) → 3 ChangeLog rows
  3. Create 2 tasks in it, then flip Status / IsWaiting → ChangeLog rows
  4. Create a milestone, then edit Title + Date + Status → ChangeLog rows

Run with backend up at http://localhost:5163.
"""
import io
import json
import sys
import urllib.request
from datetime import datetime, timedelta

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

BASE = "http://localhost:5163"
HUMAN_ID = "69f33ac19970f43fa673b115"  # ysh — change-log ChangedBy attribution


def request(method, path, *, body=None, allow_status=None):
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    req.add_header("X-Dev-User-Id", HUMAN_ID)
    try:
        with urllib.request.urlopen(req) as r:
            text = r.read().decode("utf-8")
            return r.status, json.loads(text) if text else None
    except urllib.error.HTTPError as e:
        if allow_status and e.code in allow_status:
            return e.code, None
        raise


def main():
    stamp = datetime.utcnow().strftime("%H%M%S")

    # 1. Project create + edits
    print("# 1. Create + edit project")
    code, project = request("POST", "/api/projects", body={
        "name": f"[데모] Audit showcase {stamp}",
        "description": "변경이력 통합 페이지 데모용 프로젝트",
        "status": "Planning",
    })
    print(f"  {code}  POST /api/projects → {project['id'][:8]}…")
    pid = project["id"]

    project["status"] = "Active"
    project["changeReason"] = "kickoff: planning → active"
    project["changedBy"] = "ysh"
    code, _ = request("PUT", f"/api/projects/{pid}", body=project)
    print(f"  {code}  PUT status Planning→Active")

    project["name"] = f"[데모] Audit showcase {stamp} (renamed)"
    project["changeReason"] = "rename for clarity"
    code, _ = request("PUT", f"/api/projects/{pid}", body=project)
    print(f"  {code}  PUT name renamed")

    project["description"] = "변경이력 통합 페이지 데모용 프로젝트 — 한↔영 라벨 검증 포함"
    project["changeReason"] = "expanded scope description"
    code, _ = request("PUT", f"/api/projects/{pid}", body=project)
    print(f"  {code}  PUT description expanded")

    # 2. Tasks under that project
    print()
    print("# 2. Create + flip tasks")
    today = datetime.utcnow()
    later = today + timedelta(days=5)
    tasks = []
    for i, title in enumerate(["기획 회의 정리", "프로토타입 빌드"]):
        code, t = request("POST", f"/api/projects/{pid}/tasks", body={
            "title": title,
            "description": f"audit demo task #{i + 1}",
            "status": "Created",
            "currentTimeline": {
                "start": today.strftime("%Y-%m-%dT00:00:00Z"),
                "end": later.strftime("%Y-%m-%dT23:59:59Z"),
                "isAllDay": True,
            },
        })
        print(f"  {code}  POST task '{title}' → MK-{t['number']}")
        tasks.append(t)

    # Flip the first task: status, isWaiting
    t = tasks[0]
    t["status"] = "InProgress"
    t["changeReason"] = "ysh kicked off the work"
    t["changedBy"] = "ysh"
    code, _ = request("PUT", f"/api/tasks/{t['id']}", body=t)
    print(f"  {code}  PUT MK-{t['number']} status Created→InProgress")

    t["isWaiting"] = True
    t["changeReason"] = "blocked on external review"
    code, _ = request("PUT", f"/api/tasks/{t['id']}", body=t)
    print(f"  {code}  PUT MK-{t['number']} isWaiting false→true")

    t["isWaiting"] = False
    t["status"] = "WorkReview"
    t["changeReason"] = "review unblocked, sending for review"
    code, _ = request("PUT", f"/api/tasks/{t['id']}", body=t)
    print(f"  {code}  PUT MK-{t['number']} isWaiting→false + status→WorkReview")

    # 3. Milestone create + edits
    print()
    print("# 3. Create + edit milestone")
    target = today + timedelta(days=14)
    code, m = request("POST", f"/api/projects/{pid}/milestones", body={
        "title": "베타 발표",
        "date": target.strftime("%Y-%m-%dT00:00:00Z"),
        "status": "Upcoming",
    })
    print(f"  {code}  POST milestone → {m['id'][:8]}…")
    mid = m["id"]

    m["title"] = "베타 데모데이"
    m["changeReason"] = "renamed to match marketing copy"
    m["changedBy"] = "ysh"
    code, _ = request("PUT", f"/api/milestones/{mid}", body=m)
    print(f"  {code}  PUT milestone title")

    pushed = target + timedelta(days=3)
    m["date"] = pushed.strftime("%Y-%m-%dT00:00:00Z")
    m["changeReason"] = "pushed +3 days for venue conflict"
    code, _ = request("PUT", f"/api/milestones/{mid}", body=m)
    print(f"  {code}  PUT milestone date pushed +3d")

    m["status"] = "Reached"
    m["changeReason"] = "demo complete"
    code, _ = request("PUT", f"/api/milestones/{mid}", body=m)
    print(f"  {code}  PUT milestone status Upcoming→Reached")

    print()
    print(f"Done. Project id = {pid}  — open Audit and filter by 프로젝트 = '[데모] Audit showcase {stamp}'")


if __name__ == "__main__":
    main()
