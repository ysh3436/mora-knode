"""Smoke test for the TaskComment endpoints.

Exercises the full happy path: create → list (oldest first) → edit → delete.
Image attachment is not covered here — that ships separately under the
image-attach follow-up task.

Run with backend up at http://localhost:5163.
"""
import io
import json
import sys
import urllib.request
import urllib.error

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

import os
BASE = os.environ.get("MORA_KNODE_API", "http://localhost:5163")
HUMAN = "69f33ac19970f43fa673b115"
PROJECT_MORA = "69f4404e24095755bdd41bdb"


def req(method, path, *, body=None, ok_codes=(200, 201, 204)):
    data = json.dumps(body, ensure_ascii=False).encode("utf-8") if body is not None else None
    r = urllib.request.Request(BASE + path, data=data, method=method)
    if body is not None:
        r.add_header("Content-Type", "application/json")
    r.add_header("X-Dev-User-Id", HUMAN)
    try:
        with urllib.request.urlopen(r) as resp:
            text = resp.read().decode("utf-8", errors="replace")
            assert resp.status in ok_codes, f"unexpected {resp.status}: {text}"
            return resp.status, json.loads(text) if text else None
    except urllib.error.HTTPError as e:
        body_text = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {e.code} on {method} {path}: {body_text[:300]}")


def main():
    code, tasks = req("GET", f"/api/projects/{PROJECT_MORA}/tasks")
    mk105 = next(t for t in tasks if t.get("number") == 105)
    task_id = mk105["id"]
    code, before = req("GET", f"/api/tasks/{task_id}/comments")
    base_count = len(before)
    print(f"# target task: MK-105  id={task_id}  (existing comments: {base_count})")
    print()

    # 1. Create two comments
    code, c1 = req("POST", f"/api/tasks/{task_id}/comments",
                   body={"body": "첫 번째 코멘트 — review 라벨", "kind": "review"})
    print(f"  {code}  POST 1st  →  id={c1['id'][:12]}…  kind={c1['kind']}")

    code, c2 = req("POST", f"/api/tasks/{task_id}/comments",
                   body={"body": "두 번째 코멘트 — 평문 노트", "kind": None})
    print(f"  {code}  POST 2nd  →  id={c2['id'][:12]}…")

    # 2. List (oldest first per repo)
    code, all_comments = req("GET", f"/api/tasks/{task_id}/comments")
    print(f"  {code}  GET       →  {len(all_comments)} entries (oldest first)")
    for c in all_comments:
        print(f"      {c['id'][:8]}…  {c.get('kind') or 'note':<6}  {c['body'][:40]!r}")

    # 3. Edit first
    code, c1u = req("PUT", f"/api/comments/{c1['id']}",
                    body={"body": c1["body"] + "\n\n*수정 후*", "kind": "review"})
    print(f"  {code}  PUT       →  body length {len(c1u['body'])}")

    # 4. Delete second
    code, _ = req("DELETE", f"/api/comments/{c2['id']}", ok_codes=(204,))
    print(f"  {code}  DELETE 2nd")

    # 5. Cleanup: delete the edited first one too. Net delta should be 0.
    code, _ = req("DELETE", f"/api/comments/{c1['id']}", ok_codes=(204,))
    print(f"  {code}  DELETE 1st (cleanup)")
    code, after = req("GET", f"/api/tasks/{task_id}/comments")
    print(f"  {code}  GET       →  {len(after)} total (was {base_count})")
    assert len(after) == base_count, f"expected {base_count}, got {len(after)}"

    print()
    print("All assertions passed ✓")


if __name__ == "__main__":
    main()
