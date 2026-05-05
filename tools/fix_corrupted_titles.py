"""One-shot recovery: restores task titles + descriptions that got
mangled to '?' characters by PowerShell Invoke-WebRequest's cp949
codepage handling during PUT round-trips. Pulls correct values from
the pre-migration MongoDB dump (tools/backups/tasks_pre_v2_*.json) for
older tasks, and uses inline fallbacks for tasks created after the
backup.

Always run with Python — PowerShell will re-mangle the Korean chars
on the way out the network stack.
"""
import io
import json
import sys
import urllib.error
import urllib.request

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

BASE = "http://localhost:5163"
HUMAN_ID = "69f33ac19970f43fa673b115"

# Tasks that have a clean copy in the v1 backup. Map by id so we can
# pull both Title and Description verbatim.
BACKUP_FILE = "d:/NilPop/projects/mora-knode/tools/backups/tasks_pre_v2_20260501_160901.json"
BACKUP_IDS = [
    "69f4badc114fed107bb64b0e",  # MK-82
    "69f4badc114fed107bb64b0f",  # MK-83
    "69f4badc114fed107bb64b11",  # MK-85
    "69f4badc114fed107bb64b12",  # MK-86
]

# Tasks created after the backup — title + description known from the
# session that created them.
POST_BACKUP = {
    "69f9d60788474a4734daff14": {  # MK-99
        "title": "변경이력 통합 페이지",
        "description": (
            "Audit 섹션의 placeholder 를 실제 ChangeLog 리스트로 전환. "
            "백엔드 /api/change-logs 이미 존재. 필터 (entityType / entityId / 날짜) "
            "+ 페이지네이션 / 더 보기. status / IsWaiting / plan approve/reject/revert "
            "자취 한 화면에서 추적."
        ),
    },
}


def request(method, path, *, body=None):
    data = json.dumps(body, ensure_ascii=False).encode("utf-8") if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    req.add_header("X-Dev-User-Id", HUMAN_ID)
    with urllib.request.urlopen(req) as r:
        text = r.read().decode("utf-8")
        return r.status, json.loads(text) if text else None


def main():
    # Load backup
    backup_by_id = {}
    with open(BACKUP_FILE, "r", encoding="utf-8") as f:
        for line in f:
            row = json.loads(line)
            backup_by_id[row["_id"]] = row

    fixes = []
    for tid in BACKUP_IDS:
        row = backup_by_id.get(tid)
        if row is None:
            print(f"  --  {tid}: not in backup, skipping")
            continue
        fixes.append({
            "id": tid,
            "title": row["Title"],
            "description": row.get("Description") or None,
        })

    for tid, override in POST_BACKUP.items():
        fixes.append({"id": tid, **override})

    for fix in fixes:
        # Round-trip: GET current, overwrite title/description, PUT.
        # We need the full doc for PUT (backend ReplaceAsync expects it).
        with urllib.request.urlopen(f"{BASE}/api/tasks/{fix['id']}") as r:
            task = json.loads(r.read())
        before_title = task.get("title")
        task["title"] = fix["title"]
        if fix.get("description") is not None:
            task["description"] = fix["description"]
        task["changeReason"] = "auto: restore Korean title corrupted by PowerShell encoding"
        task["changedBy"] = "system"
        code, _ = request("PUT", f"/api/tasks/{fix['id']}", body=task)
        print(f"  {code}  MK-{task['number']}  {before_title!r} → {fix['title']!r}")

    print()
    print("Done.")


if __name__ == "__main__":
    main()
