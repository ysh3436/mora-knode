"""One-shot bulk update of Project 5 (mora-knode itself) tasks:
priority + date plan as agreed in 2026-05-01 conversation.

Idempotent — re-running just rewrites the same values.
"""
import json
import urllib.request

BASE = "http://localhost:5163"


def get_task(tid):
    with urllib.request.urlopen(f"{BASE}/api/tasks/{tid}") as r:
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


def all_day(start_ymd, end_ymd):
    return {
        "start": f"{start_ymd}T00:00:00Z",
        "end": f"{end_ymd}T23:59:59.999Z",
        "isAllDay": True,
    }


# (id, priority|None, (start_ymd, end_ymd)|None, status|None, label)
UPDATES = [
    # Phase 1.5 (active)
    ("69f4404e24095755bdd41be0", "High", None, None, "Phase 1.5 (parent)"),
    ("69f4404e24095755bdd41be6", "High", None, None, "PR 2 (parent)"),
    ("69f4404e24095755bdd41be7", "High",  ("2026-05-10", "2026-05-11"), None, "TaskItem 5 fields"),
    ("69f4404e24095755bdd41be9", "Normal", ("2026-05-11", "2026-05-11"), None, "MongoDB null regr"),
    ("69f4404e24095755bdd41bea", "High",  ("2026-05-12", "2026-05-12"), None, "FE TaskItem + Inspector"),
    ("69f4404e24095755bdd41beb", "Normal", None, None, "PR 3 (parent)"),
    ("69f4404e24095755bdd41bec", "Normal", ("2026-05-13", "2026-05-13"), None, "AgentPlanHistory"),
    ("69f4404e24095755bdd41bed", "Normal", ("2026-05-14", "2026-05-14"), None, "AgentRun"),
    ("69f4404e24095755bdd41bee", "Normal", ("2026-05-15", "2026-05-15"), None, "MongoContext + Repos"),
    ("69f4404e24095755bdd41bef", "Normal", ("2026-05-16", "2026-05-16"), None, "Indexes"),
    ("69f4404e24095755bdd41bf0", "Normal", None, None, "PR 4 (parent)"),
    ("69f4404e24095755bdd41bf1", "Normal", ("2026-05-17", "2026-05-17"), None, "/api/agents"),
    ("69f4404e24095755bdd41bf2", "Normal", ("2026-05-18", "2026-05-18"), None, "/api/agents/plans/*"),
    ("69f4404e24095755bdd41bf3", "Normal", ("2026-05-19", "2026-05-19"), None, "/api/agents/work-queue/*"),
    ("69f4404e24095755bdd41bf4", "Normal", ("2026-05-20", "2026-05-20"), None, "/api/agents/runs"),
    ("69f4404e24095755bdd41bf5", "Normal", ("2026-05-21", "2026-05-21"), None, "Program.cs + curl test"),
    ("69f4404e24095755bdd41bf6", "Low",  None, None, "(검토) MCP scaffolding loc"),

    # Phase 2 dogfooding (M2)
    ("69f4404e24095755bdd41bf7", "Normal", None, None, "Phase 2 (parent)"),
    ("69f4404e24095755bdd41bf9", "Normal", None, None, "Matrix util sum + 100% alert"),
    ("69f4404e24095755bdd41bfa", "Normal", None, None, "4 agent identities"),
    ("69f4404e24095755bdd41bfb", "Normal", None, None, "External tool setup"),
    ("69f4404e24095755bdd41bfc", "Normal", None, None, "E2E scenario"),
    ("69f4404e24095755bdd41bfd", "Normal", None, None, "2-week simulation"),

    # Stage 1 — Normal + push back (06-16 ~ 08-31)
    ("69f4404e24095755bdd41bfe", "Normal", ("2026-06-16", "2026-08-31"), None, "Stage 1 (parent)"),
    ("69f4404e24095755bdd41bff", "Normal", ("2026-06-16", "2026-06-22"), None, "MCP scaffolding (P0-1)"),
    ("69f4404e24095755bdd41c00", "Normal", ("2026-06-23", "2026-06-29"), None, ".claude common skill (P0-2)"),
    ("69f4404e24095755bdd41c01", "Normal", ("2026-06-30", "2026-07-06"), None, "Conv Commit hook (P0-3)"),
    ("69f4404e24095755bdd41c02", "Normal", ("2026-07-07", "2026-07-13"), None, "Manager approval gate UI (P1-5)"),
    ("69f4404e24095755bdd41c03", "Normal", ("2026-07-14", "2026-07-20"), None, "Revision count vis (P1-6)"),
    ("69f4404e24095755bdd41c04", "Normal", ("2026-07-21", "2026-07-27"), None, "Context Engine min (P1-7)"),
    ("69f4404e24095755bdd41c05", "Normal", ("2026-07-28", "2026-08-10"), None, "PR 5 Flutter agent UI"),
    ("69f4404e24095755bdd41c06", "Normal", ("2026-08-11", "2026-08-17"), None, "Human-in-the-loop alerts"),
    ("69f4404e24095755bdd41c07", "Normal", ("2026-08-18", "2026-08-24"), None, "docker scaffolding"),
    ("69f4404e24095755bdd41c08", "Normal", ("2026-08-25", "2026-08-31"), None, "docker E2E"),

    # 자유 백로그 (top-level UX) — Normal + further-future
    ("69f441c624095755bdd41c09", "Normal", ("2026-09-01", "2026-09-07"), None, "Project sort order"),
    ("69f441c624095755bdd41c0a", "Normal", ("2026-09-08", "2026-09-14"), None, "Project favorites/pin"),

    # Already shipped — mark Done
    ("69f46be324095755bdd41c0c", None, None, "Done", "Move user name under logo (DONE)"),
]


def main():
    print(f"Applying {len(UPDATES)} updates...")
    for tid, pri, dates, status, label in UPDATES:
        t = get_task(tid)
        if pri is not None:
            t["priority"] = pri
        if status is not None:
            t["status"] = status
        if dates is not None:
            rng = all_day(*dates)
            t["originTimeline"] = rng
            t["currentTimeline"] = rng
        t["changeReason"] = "bulk priority/date plan (2026-05-01)"
        t["changedBy"] = "ysh"
        put_task(tid, t)
        bits = []
        if pri: bits.append(f"pri={pri}")
        if dates: bits.append(f"dates={dates[0]}~{dates[1]}")
        if status: bits.append(f"status={status}")
        print(f"  OK {tid}  [{', '.join(bits)}]  {label}")
    print("Done.")


if __name__ == "__main__":
    main()
