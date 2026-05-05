"""End-to-end check that the plan-gate + work-queue loop works.

Mirrors the actor-driven flow described in the lifecycle plan and ADR-002:

  1. Setup: human reviewer + bot agent + a project + an InProgress task,
     and assign the agent to the task.
  2. Bot fetches /work-queue and sees the task with no plan yet.
  3. Bot submits a plan → task lifecycle bumps to PlanReview, plan is
     PendingReview, and /work-queue?status=PendingReview surfaces it as
     "needs human review".
  4. Reject path:
     - Human PUT /reject (with comment) → plan Rejected, task back to
       InProgress (per the 9-step lifecycle: rejection records the issue
       and the bot picks the task back up).
  5. Re-submit + approve path:
     - Bot submits a revised plan → task PlanReview again, latest plan
       refreshes in /work-queue.
     - Human PUT /approve → plan Approved, task moves to InProgress so
       the bot's next poll sees "ready to execute".
  6. Permission guards:
     - Bot trying to /approve its own plan → 403.
     - Anonymous /work-queue → 401.
     - /reject without comment → 400.
  7. Cleanup: revoke agent token + delete demo project (best-effort —
     leaves data on failure for inspection).

Run with backend up at http://localhost:5163.
"""
import io
import json
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

BASE = "http://localhost:5163"


def request(method, path, *, body=None, headers=None, allow_status=None):
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req) as r:
            text = r.read().decode("utf-8")
            return r.status, json.loads(text) if text else None
    except urllib.error.HTTPError as e:
        body_text = e.read().decode("utf-8", errors="replace")
        if allow_status and e.code in allow_status:
            try:
                return e.code, json.loads(body_text) if body_text else None
            except json.JSONDecodeError:
                return e.code, body_text
        print(f"HTTP {e.code} on {method} {path}: {body_text[:300]}")
        raise


def expect(actual, expected, label):
    icon = "OK  " if actual == expected else "FAIL"
    print(f"  {icon} {label}: got {actual!r}, expected {expected!r}")
    if actual != expected:
        sys.exit(1)


def main():
    stamp = datetime.utcnow().strftime("%Y%m%d-%H%M%S")
    human_name = f"smoke-human-{stamp}"
    agent_name = f"smoke-bot-{stamp}"
    project_name = f"[demo] plan-gate smoke {stamp}"

    print(f"# 1. Setup — human {human_name!r}, bot {agent_name!r}, project + task")
    # 1a. human reviewer
    code, human = request("POST", "/api/resources", body={
        "name": human_name,
        "kind": "Human",
        "rbac": "Human",
    })
    expect(code, 201, "POST /api/resources (human)")
    human_id = human["id"]

    # 1b. bot agent + initial token
    code, created = request("POST", "/api/agents", body={
        "name": agent_name,
        "description": "smoke test from tools/demo_agent_flow.py",
        "rbac": "Developer",
    })
    expect(code, 201, "POST /api/agents (bot)")
    agent_id = created["agent"]["id"]
    raw_token = created["rawToken"]

    bot_auth = {"Authorization": f"Bearer {raw_token}", "X-Agent-Id": agent_id}
    human_auth = {"X-Dev-User-Id": human_id}

    # 1c. project
    code, project = request("POST", "/api/projects", body={
        "name": project_name,
        "description": "auto-generated plan-gate smoke",
        "status": "Active",
    })
    expect(code, 201, "POST /api/projects")
    project_id = project["id"]

    # 1d. task
    today = datetime.utcnow()
    later = today + timedelta(days=3)
    code, task = request("POST", f"/api/projects/{project_id}/tasks", body={
        "title": "smoke task",
        "description": "do the thing",
        "status": "Created",
        "currentTimeline": {
            "start": today.strftime("%Y-%m-%dT00:00:00Z"),
            "end": later.strftime("%Y-%m-%dT23:59:59Z"),
            "isAllDay": True,
        },
    })
    expect(code, 201, "POST /api/projects/{id}/tasks")
    task_id = task["id"]

    # 1e. assign bot to task
    code, _ = request("POST", "/api/assignments", body={
        "resourceId": agent_id,
        "taskId": task_id,
        "allocationPercent": 100,
        "start": today.strftime("%Y-%m-%dT00:00:00Z"),
        "end": later.strftime("%Y-%m-%dT23:59:59Z"),
    })
    expect(code, 201, "POST /api/assignments (bot ↔ task)")

    print()
    print("# 2. Bot's /work-queue: 1 task, no plan yet")
    code, queue = request("GET", "/api/agents/work-queue", headers=bot_auth)
    expect(code, 200, "GET /api/agents/work-queue")
    expect(len(queue), 1, "queue rows")
    expect(queue[0]["task"]["id"], task_id, "queue row task id")
    expect(queue[0]["latestPlan"], None, "no plan yet")

    print()
    print("# 3. Bot submits a plan → task → PlanReview, plan PendingReview")
    code, plan_v1 = request("POST", "/api/agents/plans", headers=bot_auth, body={
        "taskId": task_id,
        "title": "first attempt",
        "estimateMinutes": 90,
        "steps": [
            {"description": "read the spec", "estimateMinutes": 15},
            {"description": "do the work", "estimateMinutes": 60},
            {"description": "self-review", "estimateMinutes": 15},
        ],
        "notes": "will revise if reviewer wants more detail",
    })
    expect(code, 201, "POST /api/agents/plans")
    plan_v1_id = plan_v1["id"]
    expect(plan_v1["status"], "PendingReview", "plan v1 status")

    code, refreshed = request("GET", f"/api/tasks/{task_id}")
    expect(refreshed["status"], "PlanReview", "task lifecycle after submit")

    code, queue2 = request("GET", "/api/agents/work-queue", headers=bot_auth)
    expect(code, 200, "GET /api/agents/work-queue (after submit)")
    expect(queue2[0]["latestPlan"]["id"], plan_v1_id, "queue surfaces latest plan")
    expect(queue2[0]["latestPlan"]["status"], "PendingReview", "queue plan status")

    print()
    print("# 4. Human REJECTS plan v1 (reject requires comment)")
    code, _ = request("PUT", f"/api/agents/plans/{plan_v1_id}/reject",
                      headers=human_auth, body={}, allow_status={400})
    expect(code, 400, "reject without comment → 400")

    code, rejected = request("PUT", f"/api/agents/plans/{plan_v1_id}/reject",
                             headers=human_auth,
                             body={"comment": "estimates look optimistic — please split"})
    expect(code, 200, "PUT /api/agents/plans/{id}/reject")
    expect(rejected["status"], "Rejected", "plan v1 final status")
    assert rejected["reviewerComment"], "rejected plan should record comment"

    code, after_reject = request("GET", f"/api/tasks/{task_id}")
    expect(after_reject["status"], "InProgress",
           "task back to InProgress after reject (lifecycle: bot picks back up)")

    print()
    print("# 5. Bot submits revised plan → human APPROVES")
    code, plan_v2 = request("POST", "/api/agents/plans", headers=bot_auth, body={
        "taskId": task_id,
        "title": "second attempt — split estimates",
        "estimateMinutes": 120,
        "steps": [
            {"description": "read the spec carefully", "estimateMinutes": 25},
            {"description": "draft", "estimateMinutes": 40},
            {"description": "polish", "estimateMinutes": 35},
            {"description": "self-review", "estimateMinutes": 20},
        ],
    })
    expect(code, 201, "POST /api/agents/plans (v2)")
    plan_v2_id = plan_v2["id"]

    code, mid = request("GET", f"/api/tasks/{task_id}")
    expect(mid["status"], "PlanReview", "task → PlanReview again on re-submit")

    code, approved = request("PUT", f"/api/agents/plans/{plan_v2_id}/approve",
                             headers=human_auth, body={"comment": "looks good"})
    expect(code, 200, "PUT /api/agents/plans/{id}/approve")
    expect(approved["status"], "Approved", "plan v2 final status")

    code, after_approve = request("GET", f"/api/tasks/{task_id}")
    expect(after_approve["status"], "InProgress", "task → InProgress after approve")

    print()
    print("# 6. Permission guards")
    code, _ = request("PUT", f"/api/agents/plans/{plan_v2_id}/approve",
                      headers=bot_auth, body={"comment": "self-approve!"},
                      allow_status={403, 409})
    # Already approved, so the conflict check fires before the rbac check
    # if the same plan is tried twice. Use a fresh PendingReview for a
    # clean 403 demo:
    code, plan_v3 = request("POST", "/api/agents/plans", headers=bot_auth, body={
        "taskId": task_id,
        "title": "third attempt",
        "steps": [{"description": "noop"}],
    })
    expect(code, 201, "POST /api/agents/plans (v3, for rbac test)")
    plan_v3_id = plan_v3["id"]
    code, _ = request("PUT", f"/api/agents/plans/{plan_v3_id}/approve",
                      headers=bot_auth, body={"comment": "self-approve!"},
                      allow_status={403})
    expect(code, 403, "bot approving own plan → 403")

    code, _ = request("GET", "/api/agents/work-queue", allow_status={401})
    expect(code, 401, "anonymous /work-queue → 401")

    code, _ = request("PUT", f"/api/agents/plans/{plan_v3_id}/reject",
                      headers=human_auth, body={"comment": "wrap-up reject"})
    expect(code, 200, "human cleanup-rejects v3")

    print()
    print("# 7. Plan history surfaces all 3 plans, newest first")
    code, history = request("GET", f"/api/agents/plans?taskId={task_id}", headers=human_auth)
    expect(code, 200, "GET /api/agents/plans?taskId=...")
    expect(len(history), 3, "plan history count")
    statuses = [p["status"] for p in history]
    expect(statuses, ["Rejected", "Approved", "Rejected"],
           "plan history statuses (v3 latest, then v2, then v1)")

    print()
    print("# 8. Cleanup")
    code, _ = request("POST", f"/api/agents/{agent_id}/revoke", headers=bot_auth,
                      allow_status={401, 200})
    # bot just revoked itself; further bot calls would 401 — fine.
    code, _ = request("DELETE", f"/api/projects/{project_id}", headers=human_auth)
    print(f"  cleanup project delete → {code}")
    print()
    print("ALL OK")


if __name__ == "__main__":
    main()
