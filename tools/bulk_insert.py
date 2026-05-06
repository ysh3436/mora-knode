#!/usr/bin/env python3
"""
Bulk insert a project + nested tasks + resources + milestones + assignments
into mora-knode via REST.

Pattern: ysh + AI 가 plan 을 JSON 으로 작성 -> 이 스크립트로 일괄 적재 ->
ysh 가 in-app 에서 우선순위 / 일정 / 할당 조정. 향후 새 phase / PR plan
때마다 같은 도구 재사용. Plans / Issues / Initiatives 도메인이 들어오는
대로 이 스크립트도 같이 확장.

Usage:
    python tools/bulk_insert.py plans/<file>.json [--base-url http://localhost:5163]

JSON schema:
    {
      "project": {"name": "...", "description": "...", "status": "Active"},

      "resources": [
        {"name": "ysh", "role": "Solo dev", "capacityPercent": 100,
         "kind": "Human", "rbac": "Manager", "agentDescription": null}
      ],

      "milestones": [
        {"title": "M1 마감", "date": "2026-05-07", "status": "Upcoming"}
      ],

      "tasks": [
        {
          "title": "...",
          "description": "...",                 # optional
          "status": "NotStarted",               # optional, default NotStarted
          "currentTimeline": {                   # optional; missing = no schedule
            "start": "2026-05-08",              # date or ISO datetime
            "end":   "2026-05-09",
            "isAllDay": true
          },
          "originTimeline": {...},              # optional, defaults to currentTimeline
          "realTimeline":   {...},              # optional, usually empty until done
          "assignees": [                         # optional inline assignments
            {"resource": "ysh", "allocationPercent": 100,
             "start": "2026-05-08", "end": "2026-05-09"}
          ],
          "children": [ ... recursive ... ]     # optional nested subtasks
        }
      ]
    }

Date-only strings ("YYYY-MM-DD") are padded to 00:00:00Z.
Assignee resource name is resolved against created resources by `name`.
Assignee start/end default to the task's currentTimeline.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request

# Windows 콘솔 cp949 에서 한국어 외 유니코드 (em-dash 등) 가 깨지므로 강제 UTF-8.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")


def post(url: str, payload: dict) -> dict:
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=body,
        method="POST",
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
        sys.exit(f"POST {url} -> {e.code}: {body}")
    except urllib.error.URLError as e:
        sys.exit(f"POST {url} failed: {e.reason}. Is the backend running?")


def get(url: str) -> list | dict:
    req = urllib.request.Request(url, method="GET")
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
        sys.exit(f"GET {url} -> {e.code}: {body}")
    except urllib.error.URLError as e:
        sys.exit(f"GET {url} failed: {e.reason}. Is the backend running?")


def iso(v: str | None) -> str | None:
    if not v:
        return None
    return v if "T" in v else f"{v}T00:00:00Z"


def normalize_timeline(t: dict | None) -> dict:
    if not t:
        return {}
    out: dict = {}
    for k in ("start", "end"):
        v = iso(t.get(k))
        if v:
            out[k] = v
    out["isAllDay"] = bool(t.get("isAllDay", True))
    return out


def insert_resources(base_url: str, resources: list[dict]) -> dict[str, str]:
    """Create each requested resource, or reuse existing one if a resource
    with the same name already exists. Idempotent on re-run / partial run."""
    existing = {r["name"]: r["id"] for r in get(f"{base_url}/api/resources")}
    name_to_id: dict[str, str] = {}
    for r in resources:
        if r["name"] in existing:
            name_to_id[r["name"]] = existing[r["name"]]
            print(f"= resource {existing[r['name']]}  {r['name']} (existing - reused)")
            continue
        body = {
            "name": r["name"],
            "role": r.get("role"),
            "capacityPercent": r.get("capacityPercent", 100),
            "kind": r.get("kind", "Human"),
            "rbac": r.get("rbac", "Human"),
            "agentDescription": r.get("agentDescription"),
        }
        created = post(f"{base_url}/api/resources", body)
        name_to_id[r["name"]] = created["id"]
        print(f"+ resource {created['id']}  {r['name']}")
    return name_to_id


def insert_milestones(base_url: str, project_id: str, milestones: list[dict]) -> None:
    for m in milestones:
        body = {
            "title": m["title"],
            "date": iso(m["date"]),
            "status": m.get("status", "Upcoming"),
        }
        created = post(f"{base_url}/api/projects/{project_id}/milestones", body)
        print(f"+ milestone {created['id']}  {m['title']} @ {m['date']}")


def insert_assignments(
    base_url: str,
    task_id: str,
    task_timeline: dict,
    assignees: list[dict],
    resource_ids: dict[str, str],
) -> None:
    for a in assignees:
        rname = a["resource"]
        if rname not in resource_ids:
            print(f"  ! skip assignment — unknown resource '{rname}'", file=sys.stderr)
            continue
        start = iso(a.get("start") or task_timeline.get("start"))
        end = iso(a.get("end") or task_timeline.get("end"))
        if not start or not end:
            print(f"  ! skip assignment — missing dates for '{rname}'", file=sys.stderr)
            continue
        body = {
            "resourceId": resource_ids[rname],
            "taskId": task_id,
            "allocationPercent": a.get("allocationPercent", 100),
            "start": start,
            "end": end,
        }
        post(f"{base_url}/api/assignments", body)
        print(f"  ~ assigned {rname} ({body['allocationPercent']}%)")


def insert_task(
    base_url: str,
    project_id: str,
    task: dict,
    resource_ids: dict[str, str],
    parent_id: str | None = None,
    depth: int = 0,
) -> None:
    current = normalize_timeline(task.get("currentTimeline"))
    body = {
        "projectId": project_id,
        "parentTaskId": parent_id,
        "title": task["title"],
        "description": task.get("description"),
        "status": task.get("status", "NotStarted"),
        "originTimeline": normalize_timeline(task.get("originTimeline")) or current,
        "currentTimeline": current,
        "realTimeline": normalize_timeline(task.get("realTimeline")),
    }
    created = post(f"{base_url}/api/projects/{project_id}/tasks", body)
    print(f"{'  ' * depth}+ task {created['id']}  {task['title']}")
    insert_assignments(base_url, created["id"], current, task.get("assignees", []), resource_ids)
    for child in task.get("children", []):
        insert_task(base_url, project_id, child, resource_ids, parent_id=created["id"], depth=depth + 1)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("plan", help="JSON plan file")
    ap.add_argument("--base-url", default=os.environ.get("MORA_KNODE_API", "http://localhost:5163"))
    args = ap.parse_args()

    with open(args.plan, encoding="utf-8") as f:
        plan = json.load(f)

    resource_ids = insert_resources(args.base_url, plan.get("resources", []))

    project_payload = plan["project"]
    project_payload.setdefault("status", "Active")
    project = post(f"{args.base_url}/api/projects", project_payload)
    print(f"+ project {project['id']}  {project['name']}")

    insert_milestones(args.base_url, project["id"], plan.get("milestones", []))

    for t in plan.get("tasks", []):
        insert_task(args.base_url, project["id"], t, resource_ids)

    print("Done.")


if __name__ == "__main__":
    main()
