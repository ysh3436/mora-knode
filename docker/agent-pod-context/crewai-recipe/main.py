"""Runnable CrewAI entry point for a mora-knode agent pod.

Sample / starting point. The real operator will likely:
  - swap the synchronous polling loop for an async / queue-driven version,
  - replace the inline REST calls with proper CrewAI Tool subclasses,
  - tune the per-role kickoff cadence to match the paired LLM CLI's quotas.

This file is intentionally minimal so it runs out of the box on the
agent-pod base image:

    python /work/crewai-recipe/main.py
"""
from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request

API = os.environ["MORA_KNODE_API"]
TOKEN = os.environ["MORA_KNODE_AGENT_TOKEN"]
AGENT = os.environ["MORA_KNODE_AGENT_ID"]
ROLE = os.environ.get("MORA_KNODE_AGENT_ROLE", "developer")
POLL_SECONDS = int(os.environ.get("MORA_KNODE_POLL_SECONDS", "60"))

HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "X-Agent-Id": AGENT,
    "Content-Type": "application/json",
}
PRIORITY = {"Urgent": -20, "High": -10, "Normal": 0, "Low": 10, "Unset": 100}


def _request(method: str, path: str, body=None):
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(f"{API}{path}", data=data, method=method, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            text = r.read().decode("utf-8")
            return r.status, json.loads(text) if text else None
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", errors="replace")


def fetch_queue():
    code, rows = _request("GET", "/api/agents/work-queue")
    if code != 200:
        raise RuntimeError(f"work-queue fetch failed: HTTP {code} — {rows}")
    rows.sort(key=lambda r: PRIORITY.get(r["task"]["priority"], 100))
    return rows


def handle_one(row, role):
    """Replace this with real CrewAI Crew.kickoff(...) calls.

    The dispatch below is a deliberately dumb scaffold — each role looks
    at the row and prints what it WOULD do. Wire CrewAI agents/tasks
    from agents.yaml + tasks.yaml here when you're ready.
    """
    task = row["task"]
    plan = row.get("latestPlan")
    print(f"[{role}]  MK-{task['number']:>3}  {task['status']:<11} {task['title'][:60]}")

    # Example dispatch sketch — fill in based on agents.yaml
    if role == "manager" and (plan is None or plan.get("status") == "Rejected"):
        print(f"  → would draft a plan for MK-{task['number']}")
    elif role == "developer" and plan and plan.get("status") == "Approved" and task["status"] == "InProgress":
        print(f"  → would execute plan {plan['id']} for MK-{task['number']}")
    elif role == "qa" and task["status"] == "WorkReview":
        print(f"  → would QA PR for MK-{task['number']}")
    elif role == "researcher":
        print(f"  → would investigate if needed for MK-{task['number']}")


def main() -> int:
    print(f"mora-knode pod loop — role={ROLE}, polling every {POLL_SECONDS}s")
    print(f"  api: {API}")
    print(f"  agent: {AGENT}")
    print()

    while True:
        try:
            rows = fetch_queue()
            if not rows:
                print(".", end="", flush=True)
            else:
                print()
                for row in rows[:5]:  # only the top 5 by priority each cycle
                    handle_one(row, ROLE)
                    break  # one task per cycle in this scaffold
        except Exception as e:  # broad on purpose: don't kill the loop
            print(f"\n[error] {e}", file=sys.stderr)
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    sys.exit(main() or 0)
