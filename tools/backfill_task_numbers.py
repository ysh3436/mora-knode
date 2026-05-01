"""One-shot: assign MK-N numbers to all existing tasks (1..N by createdAt).

Idempotent: tasks that already have a positive Number are skipped, so
re-running just patches gaps without renumbering. After the pass the
AppMeta counter is reconciled to max(Number) so the next CreateAsync
allocation continues monotonically.

Usage:
  python tools/backfill_task_numbers.py [--dry-run]
"""
import io
import json
import sys
import urllib.request

# Windows-friendly: console codepage is cp949, so wrap stdout in UTF-8 to
# print Korean titles + em-dashes without UnicodeEncodeError.
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

BASE = "http://localhost:5163"


def get(path):
    with urllib.request.urlopen(f"{BASE}{path}") as r:
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


def main():
    dry = "--dry-run" in sys.argv

    projects = get("/api/projects")
    all_tasks = []
    for p in projects:
        if not p.get("id"):
            continue
        all_tasks.extend(get(f"/api/projects/{p['id']}/tasks"))

    # Stable order: createdAt then id (tie-break) so re-runs are deterministic.
    all_tasks.sort(key=lambda t: (t["createdAt"], t["id"]))

    # Numbering plan
    used = {t.get("number", 0) for t in all_tasks if t.get("number", 0) > 0}
    next_n = (max(used) + 1) if used else 1
    plan = []
    for t in all_tasks:
        if t.get("number", 0) > 0:
            continue
        plan.append((t, next_n))
        next_n += 1

    print(f"Tasks total: {len(all_tasks)}")
    print(f"Already numbered: {len(used)}")
    print(f"To assign: {len(plan)}")
    if dry:
        for t, n in plan[:30]:
            print(f"  MK-{n}  {t['title'][:60]}")
        if len(plan) > 30:
            print(f"  ... and {len(plan) - 30} more")
        return

    for t, n in plan:
        t["number"] = n
        t["changeReason"] = "backfill MK-N number"
        t["changedBy"] = "ysh"
        put_task(t["id"], t)

    final_max = max((next_n - 1, *used)) if (plan or used) else 0
    print(f"Done. Highest number now: MK-{final_max}")

    # Reconcile the AppMeta counter so the next CreateAsync allocates max+1.
    sync_req = urllib.request.Request(
        f"{BASE}/api/dev/sync-task-counter", data=b"", method="POST"
    )
    with urllib.request.urlopen(sync_req) as r:
        out = json.load(r)
    print(f"AppMeta synced: nextTaskNumber={out['nextTaskNumber']}, "
          f"next allocation will return MK-{out['nextAllocated']}")


if __name__ == "__main__":
    main()
