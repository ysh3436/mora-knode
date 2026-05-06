"""Tiny helper: mark a task Done via the API. Avoids the PowerShell
cp949 hazard that mojibakes Korean titles on PUT round-trip.
Usage: python tools/mark_done.py <taskId>"""
import json
import os
import sys
import urllib.request

BASE = os.environ.get("MORA_KNODE_API", "http://localhost:5163")

if len(sys.argv) < 2:
    print("usage: python tools/mark_done.py <taskId>")
    sys.exit(2)

tid = sys.argv[1]
with urllib.request.urlopen(f"{BASE}/api/tasks/{tid}") as r:
    task = json.loads(r.read())
task["status"] = "Done"
req = urllib.request.Request(
    f"{BASE}/api/tasks/{tid}",
    data=json.dumps(task, ensure_ascii=False).encode("utf-8"),
    method="PUT",
)
req.add_header("Content-Type", "application/json")
req.add_header("X-Dev-User-Id", "69f33ac19970f43fa673b115")
with urllib.request.urlopen(req) as r:
    print(f"{r.status}  MK-{task['number']} → Done")
