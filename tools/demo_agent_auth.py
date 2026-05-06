"""End-to-end check that agent identity + Bearer auth path works.

Steps:
  1. POST /api/agents to create a fresh agent + initial token (raw shown once)
  2. Verify GET /api/projects with no auth still returns 200 (anonymous = admin-equivalent — unchanged)
  3. Verify Bearer auth with valid token + X-Agent-Id resolves the agent
     - Confirms we can hit GET /api/agents/{id}/tokens with the agent's own creds
  4. Verify Bearer auth fails when X-Agent-Id is missing or wrong (defence in depth)
  5. Verify Bearer auth fails after rotate (old token revoked)
  6. Verify the rotated token works
  7. Verify revoke kills both new and old tokens

Run with backend up at http://localhost:5163. Cleans up by revoking, but
leaves the demo Resource for inspection (delete via API if you want).
"""
import json
import sys
import io
import urllib.request
import urllib.error
from datetime import datetime

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

import os
BASE = os.environ.get("MORA_KNODE_API", "http://localhost:5163")


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
    print(f"  {icon}  {label}: got {actual}, expected {expected}")
    if actual != expected:
        sys.exit(1)


def main():
    name = f"smoke-agent-{datetime.utcnow().strftime('%Y%m%d-%H%M%S')}"
    print(f"# 1. Create agent {name!r}")
    code, created = request("POST", "/api/agents", body={
        "name": name,
        "description": "smoke test from tools/demo_agent_auth.py",
        "rbac": "Developer",
    })
    expect(code, 201, "POST /api/agents")
    agent_id = created["agent"]["id"]
    raw_token = created["rawToken"]
    last_four = created["lastFour"]
    assert raw_token.startswith("mk_"), "token should be prefixed mk_"
    print(f"  agent_id={agent_id}  raw_token={raw_token[:8]}…{last_four}")

    print()
    print("# 2. Anonymous GET /api/projects still works (no breaking change)")
    code, _ = request("GET", "/api/projects")
    expect(code, 200, "anonymous /api/projects")

    print()
    print("# 3. Bearer auth + X-Agent-Id resolves the agent")
    auth = {"Authorization": f"Bearer {raw_token}", "X-Agent-Id": agent_id}
    code, tokens = request("GET", f"/api/agents/{agent_id}/tokens", headers=auth)
    expect(code, 200, "GET /api/agents/{id}/tokens with agent's own bearer")
    active = [t for t in tokens if t["isActive"]]
    expect(len(active), 1, "exactly one active token")

    print()
    print("# 4. Defence in depth: Bearer without X-Agent-Id → 401")
    code, _ = request("GET", "/api/projects",
                      headers={"Authorization": f"Bearer {raw_token}"},
                      allow_status={401})
    expect(code, 401, "Bearer without X-Agent-Id")

    print("    Bearer with WRONG X-Agent-Id → 401")
    code, _ = request("GET", "/api/projects",
                      headers={"Authorization": f"Bearer {raw_token}", "X-Agent-Id": "ffffffffffffffffffffffff"},
                      allow_status={401})
    expect(code, 401, "Bearer with mismatched X-Agent-Id")

    print("    Malformed token → 401")
    code, _ = request("GET", "/api/projects",
                      headers={"Authorization": "Bearer notatoken", "X-Agent-Id": agent_id},
                      allow_status={401})
    expect(code, 401, "malformed bearer")

    print()
    print("# 5. Rotate: old token dies, new token works")
    code, rotated = request("POST", f"/api/agents/{agent_id}/rotate", headers=auth)
    expect(code, 200, "POST /api/agents/{id}/rotate")
    new_raw = rotated["rawToken"]
    assert new_raw != raw_token, "rotate must produce a new token"

    code, _ = request("GET", "/api/projects",
                      headers={"Authorization": f"Bearer {raw_token}", "X-Agent-Id": agent_id},
                      allow_status={401})
    expect(code, 401, "old token after rotate is rejected")

    new_auth = {"Authorization": f"Bearer {new_raw}", "X-Agent-Id": agent_id}
    code, _ = request("GET", "/api/projects", headers=new_auth)
    expect(code, 200, "new token after rotate works")

    print()
    print("# 6. Revoke: new token dies too")
    code, _ = request("POST", f"/api/agents/{agent_id}/revoke", headers=new_auth)
    expect(code, 200, "POST /api/agents/{id}/revoke")
    code, _ = request("GET", "/api/projects", headers=new_auth, allow_status={401})
    expect(code, 401, "revoked token rejected")

    print()
    print(f"# 7. Token history: 2 rows, both revoked")
    # No bearer needed for this — the agent is revoked, so we use anonymous
    code, history = request("GET", f"/api/agents/{agent_id}/tokens")
    expect(code, 200, "anonymous read of token history")
    expect(len(history), 2, "two rows total (initial + rotated)")
    expect(sum(1 for t in history if t["isActive"]), 0, "no active rows after revoke")

    print()
    print("All smoke checks passed.")


if __name__ == "__main__":
    main()
