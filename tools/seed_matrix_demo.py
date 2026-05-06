"""Seeds a small department tree + project memberships so the matrix
filter dropdowns have something to filter against. Idempotent: skips
departments that already exist by name, skips already-member resources
for project add.

Tree:
  Engineering
    ├── Frontend
    └── Backend
  Research
  QA

Resource → department mapping:
  ysh, dohyun → Frontend
  dev-01      → Backend
  researcher-01 → Research
  mira, junho, qa-01 → QA

Project membership:
  mora-knode itself: ysh, dohyun, dev-01, researcher-01, qa-01
  [데모] NilPop internal tools: dohyun, mira

Run with backend up at http://localhost:5163.
"""
import io
import json
import sys
import urllib.error
import urllib.request

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

import os
BASE = os.environ.get("MORA_KNODE_API", "http://localhost:5163")
HUMAN_ID = "69f33ac19970f43fa673b115"  # ysh — change-log attribution


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
        body_text = e.read().decode("utf-8", errors="replace")
        if allow_status and e.code in allow_status:
            return e.code, body_text
        print(f"HTTP {e.code} on {method} {path}: {body_text[:200]}")
        raise


def find_resource(resources, name):
    for r in resources:
        if r["name"] == name:
            return r
    return None


def find_project(projects, name):
    for p in projects:
        if p["name"] == name:
            return p
    return None


def ensure_department(existing, name, parent_id=None):
    """Creates the department if not present by name; returns its id."""
    for d in existing:
        if d["name"] == name and d.get("parentDepartmentId") == parent_id:
            print(f"  ··  {name} already exists ({d['id'][:8]}…)")
            return d["id"]
    body = {"name": name}
    if parent_id is not None:
        body["parentDepartmentId"] = parent_id
    code, created = request("POST", "/api/departments", body=body)
    print(f"  {code}  POST /api/departments {name} → {created['id'][:8]}…")
    existing.append(created)
    return created["id"]


def main():
    print("# 1. Build department tree")
    code, deps = request("GET", "/api/departments")
    deps = deps or []

    eng_id = ensure_department(deps, "Engineering")
    fe_id = ensure_department(deps, "Frontend", eng_id)
    be_id = ensure_department(deps, "Backend", eng_id)
    research_id = ensure_department(deps, "Research")
    qa_id = ensure_department(deps, "QA")

    print()
    print("# 2. Assign resources to departments")
    code, resources = request("GET", "/api/resources")
    mapping = [
        ("ysh", fe_id),
        ("dohyun", fe_id),
        ("dev-01", be_id),
        ("researcher-01", research_id),
        ("mira", qa_id),
        ("junho", qa_id),
        ("qa-01", qa_id),
    ]
    for name, dept_id in mapping:
        r = find_resource(resources, name)
        if r is None:
            print(f"  --  {name}: not found, skipping")
            continue
        if r.get("departmentId") == dept_id:
            print(f"  ··  {name} already in this department")
            continue
        # PUT updates the resource — backend ResourceEndpoints accepts
        # the full doc so we round-trip the existing fields.
        r["departmentId"] = dept_id
        code, _ = request("PUT", f"/api/resources/{r['id']}", body=r)
        print(f"  {code}  PUT {name} → department {dept_id[:8]}…")

    print()
    print("# 3. Assign resources to projects")
    code, projects = request("GET", "/api/projects")
    membership = [
        ("mora-knode itself", ["ysh", "dohyun", "dev-01", "researcher-01", "qa-01"]),
        ("[데모] NilPop internal tools", ["dohyun", "mira"]),
    ]
    for proj_name, members in membership:
        proj = find_project(projects, proj_name)
        if proj is None:
            print(f"  --  project {proj_name!r} not found, skipping")
            continue
        existing = set(proj.get("memberResourceIds") or [])
        for name in members:
            r = find_resource(resources, name)
            if r is None:
                continue
            if r["id"] in existing:
                print(f"  ··  {name} already a member of {proj_name}")
                continue
            code, _ = request("POST", f"/api/projects/{proj['id']}/members/{r['id']}",
                              allow_status={409})
            print(f"  {code}  add {name} → {proj_name}")

    print()
    print("Done. Open Matrix and try the Department / Project dropdowns.")


if __name__ == "__main__":
    main()
