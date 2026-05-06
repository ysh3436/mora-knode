#!/usr/bin/env python3
"""
Update task descriptions in mora-knode by re-reading a plan JSON file.

Use case: after seeding a project with bulk_insert.py, the team often wants
to expand the brief task descriptions into detailed work breakdowns
(file paths, acceptance criteria, dependencies). This script reads the
*same* plan JSON, walks its task tree, matches each entry to an existing
task by (project name, task title), and PUTs back the task with only the
description swapped in.

Other task fields are preserved (title, status, timelines, parent) — this
script intentionally does not move tasks around or change their schedule.
For new fields beyond description, extend `_diff_fields` below.

Usage:
    python tools/bulk_update_descriptions.py plans/<file>.json [--base-url ...]
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")


def get(url: str):
    req = urllib.request.Request(url, method="GET")
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        sys.exit(f"GET {url} -> {e.code}: {e.read().decode('utf-8', 'replace')}")
    except urllib.error.URLError as e:
        sys.exit(f"GET {url} failed: {e.reason}. Is the backend running?")


def put(url: str, payload: dict):
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url, data=body, method="PUT",
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        sys.exit(f"PUT {url} -> {e.code}: {e.read().decode('utf-8', 'replace')}")


def walk_plan_tasks(tasks):
    """Yield every task dict in the plan, depth-first."""
    for t in tasks:
        yield t
        for c in t.get("children", []) or []:
            yield from walk_plan_tasks([c])


def _diff_fields(existing: dict, planned: dict) -> dict | None:
    """Build a partial update if anything differs. Currently only description
    is swapped — extend here if more fields become editable from the plan."""
    desc_planned = planned.get("description")
    desc_existing = existing.get("description")
    if (desc_planned or "") == (desc_existing or ""):
        return None
    updated = dict(existing)
    updated["description"] = desc_planned
    return updated


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("plan", help="JSON plan file to re-apply")
    ap.add_argument("--base-url", default=os.environ.get("MORA_KNODE_API", "http://localhost:5163"))
    args = ap.parse_args()

    with open(args.plan, encoding="utf-8") as f:
        plan = json.load(f)

    project_name = plan["project"]["name"]
    projects = get(f"{args.base_url}/api/projects")
    matches = [p for p in projects if p["name"] == project_name]
    if not matches:
        sys.exit(f"Project '{project_name}' not found in mora-knode.")
    if len(matches) > 1:
        sys.exit(
            f"Multiple projects named '{project_name}' found "
            f"(ids: {[p['id'] for p in matches]}). Resolve duplicates first."
        )
    project = matches[0]
    project_id = project["id"]

    existing_tasks = get(f"{args.base_url}/api/projects/{project_id}/tasks")
    by_title: dict[str, dict] = {}
    for t in existing_tasks:
        by_title.setdefault(t["title"], t)

    updated_count = 0
    skipped_unchanged = 0
    missing: list[str] = []

    for planned in walk_plan_tasks(plan.get("tasks", [])):
        title = planned["title"]
        existing = by_title.get(title)
        if existing is None:
            missing.append(title)
            continue
        merged = _diff_fields(existing, planned)
        if merged is None:
            skipped_unchanged += 1
            continue
        put(f"{args.base_url}/api/tasks/{existing['id']}", merged)
        updated_count += 1
        print(f"~ updated  {title}")

    print()
    print(f"Updated: {updated_count}")
    print(f"Unchanged: {skipped_unchanged}")
    if missing:
        print(f"Missing in DB ({len(missing)}):")
        for m in missing:
            print(f"  - {m}")


if __name__ == "__main__":
    main()
