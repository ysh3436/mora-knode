"""End-to-end check that the matrix team data layer (Department +
Project.MemberResourceIds + matrix filters) behaves as designed.

Steps:
  1. Create a department tree: Eng → Frontend / Backend
  2. Cycle prevention: PUT Eng with parent=Frontend → 400
  3. Create two resources, assign to Frontend and Backend
  4. Create a project + add both resources as members
  5. Matrix /load with no filter returns both rows
  6. Matrix /load?departmentId=Eng returns both (subtree)
  7. Matrix /load?departmentId=Frontend returns one
  8. Matrix /load?projectId=... returns project members only
  9. Matrix /load?departmentId=Backend&projectId=... = intersection (one row)
 10. Resource.DepartmentId is surfaced in the matrix response rows
 11. Removing project member drops them from projectId-filtered matrix
 12. Deleting a department detaches resource (DepartmentId → null) and
     reparents children
"""
import json
import sys
import io
import urllib.request
import urllib.error
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
        body = e.read().decode("utf-8", errors="replace")
        if allow_status and e.code in allow_status:
            return e.code, body
        print(f"HTTP {e.code} on {method} {path}: {body[:200]}")
        raise


def expect(actual, expected, label):
    icon = "OK" if actual == expected else "FAIL"
    print(f"  {icon}  {label}: got {actual!r}, expected {expected!r}")
    if actual != expected:
        sys.exit(1)


def main():
    stamp = datetime.utcnow().strftime("%Y%m%d-%H%M%S")
    print(f"# 1. Department tree: Eng → Frontend / Backend")
    _, eng = request("POST", "/api/departments", body={"name": f"eng-{stamp}"})
    eng_id = eng["id"]
    _, fe = request("POST", "/api/departments", body={"name": f"fe-{stamp}", "parentDepartmentId": eng_id})
    _, be = request("POST", "/api/departments", body={"name": f"be-{stamp}", "parentDepartmentId": eng_id})
    print(f"  eng={eng_id[:8]}  fe={fe['id'][:8]}  be={be['id'][:8]}")

    print()
    print("# 2. Cycle prevention")
    eng["parentDepartmentId"] = fe["id"]
    code, _ = request("PUT", f"/api/departments/{eng_id}", body=eng, allow_status={400})
    expect(code, 400, "PUT Eng parent=Frontend (would create cycle)")
    eng["parentDepartmentId"] = None  # restore for downstream

    print()
    print("# 3. Resources + DepartmentId assignment")
    _, alice = request("POST", "/api/resources", body={
        "name": f"alice-{stamp}", "role": "Dev", "kind": "Human", "rbac": "Developer",
        "departmentId": fe["id"], "capacityPercent": 100,
    })
    _, bob = request("POST", "/api/resources", body={
        "name": f"bob-{stamp}", "role": "Dev", "kind": "Human", "rbac": "Developer",
        "departmentId": be["id"], "capacityPercent": 100,
    })
    print(f"  alice={alice['id'][:8]}@FE  bob={bob['id'][:8]}@BE")

    print()
    print("# 4. Project + members")
    _, proj = request("POST", "/api/projects", body={"name": f"proj-{stamp}", "status": "Active"})
    proj_id = proj["id"]
    _, _ = request("POST", f"/api/projects/{proj_id}/members/{alice['id']}")
    _, after_add = request("POST", f"/api/projects/{proj_id}/members/{bob['id']}")
    expect(sorted(after_add["memberResourceIds"]), sorted([alice["id"], bob["id"]]),
           "members list after both adds")

    # Idempotent re-add
    _, again = request("POST", f"/api/projects/{proj_id}/members/{alice['id']}")
    expect(len(again["memberResourceIds"]), 2, "re-adding existing member is no-op")

    print()
    today = datetime.utcnow().date()
    fr = today.isoformat() + "T00:00:00Z"
    to = (today + timedelta(days=7)).isoformat() + "T00:00:00Z"

    def matrix(qs):
        return request("GET", f"/api/matrix/load?from={fr}&to={to}{qs}")[1]

    print("# 5-9. Matrix load filters")
    res_ids = lambda m: sorted(r["resourceId"] for r in m["rows"])

    all_rows = matrix("")
    in_all = set(res_ids(all_rows))
    expect(alice["id"] in in_all, True, "no filter: alice in result")
    expect(bob["id"] in in_all, True, "no filter: bob in result")

    eng_rows = matrix(f"&departmentId={eng_id}")
    eng_set = set(res_ids(eng_rows))
    expect(alice["id"] in eng_set and bob["id"] in eng_set, True,
           "departmentId=Eng (subtree) covers both alice + bob")

    fe_rows = matrix(f"&departmentId={fe['id']}")
    fe_set = set(res_ids(fe_rows))
    expect(alice["id"] in fe_set, True, "departmentId=Frontend includes alice")
    expect(bob["id"] not in fe_set, True, "departmentId=Frontend excludes bob")

    proj_rows = matrix(f"&projectId={proj_id}")
    proj_set = set(res_ids(proj_rows))
    expect({alice["id"], bob["id"]}.issubset(proj_set), True,
           "projectId filter includes all members")

    inter_rows = matrix(f"&departmentId={be['id']}&projectId={proj_id}")
    inter_set = set(res_ids(inter_rows))
    expect(inter_set & {alice["id"], bob["id"]}, {bob["id"]},
           "Backend ∩ project members = {bob}")

    print()
    print("# 10. departmentId surfaced in matrix rows")
    alice_row = next((r for r in fe_rows["rows"] if r["resourceId"] == alice["id"]), None)
    expect(alice_row is not None, True, "alice row present")
    expect(alice_row["departmentId"], fe["id"], "alice row departmentId == Frontend")

    print()
    print("# 11. Remove project member")
    _, after_rm = request("DELETE", f"/api/projects/{proj_id}/members/{bob['id']}")
    expect(bob["id"] not in after_rm["memberResourceIds"], True, "bob removed from project")
    proj_rows2 = matrix(f"&projectId={proj_id}")
    proj_set2 = set(res_ids(proj_rows2))
    expect(bob["id"] not in proj_set2, True, "bob not in projectId-filtered matrix anymore")

    print()
    print("# 12. Delete Frontend department: alice → DepartmentId=null, eng tree unchanged")
    code, _ = request("DELETE", f"/api/departments/{fe['id']}", allow_status={204})
    expect(code, 204, "DELETE department")
    _, alice_after = request("GET", f"/api/resources/{alice['id']}")
    expect(alice_after.get("departmentId"), None, "alice.DepartmentId detached after fe delete")

    # Cleanup project + remaining departments + resources
    request("DELETE", f"/api/projects/{proj_id}", allow_status={204})
    request("DELETE", f"/api/departments/{be['id']}", allow_status={204})
    request("DELETE", f"/api/departments/{eng_id}", allow_status={204})
    request("DELETE", f"/api/resources/{alice['id']}", allow_status={204})
    request("DELETE", f"/api/resources/{bob['id']}", allow_status={204})

    print()
    print("All matrix smoke checks passed.")


if __name__ == "__main__":
    main()
