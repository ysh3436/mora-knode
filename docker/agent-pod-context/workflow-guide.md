# Operating workflow — pod copy

> Distilled from [docs/dogfooding/agent-operations.md](../../docs/dogfooding/agent-operations.md).
> Patterns, not rules. The pod operator can deviate; mora-knode itself
> is LLM- and tool-agnostic ([ADR-005](../../docs/architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md)).

## Roles (suggested)

| Role | Responsibility |
|---|---|
| Manager | Decompose the task, draft a plan, write acceptance criteria. Submits plans. |
| Developer | Pick up an approved plan from the queue, write code, open a PR, comment the result. |
| Researcher | Probe new APIs / approaches, attach findings to the plan context. |
| QA | Check out PR branches, run tests, file follow-up tasks on bugs. |

The operator picks LLM + paired CLI per role — Claude Code, Codex,
or anything else. mora-knode never sees what model the pod uses.

## End-to-end happy path

```
[Manager pod]                            [mora-knode]                      [Human]
GET /api/agents/work-queue       ──►
  rows[]                          ◄──
client-side sort by priority
pick a Created/Planning task
POST /api/agents/plans            ──►   AgentPlan (PendingReview)
                                        task → PlanReview
                                                                     ──►   review in UI
                                                                     ◄──   PUT /approve
                                        task → InProgress

[Developer pod]
GET /api/agents/work-queue       ──►
  rows[] (now includes the InProgress task with an Approved plan)
PUT /api/tasks/{id} status=InProgress (changeReason="started")
... write code, open PR on Gitea ...
POST /api/tasks/{id}/comments {body: "PR opened: ...", kind: "review"}
PUT /api/tasks/{id} status=WorkReview                                ──►   merge PR
                                                                           PUT status=Done
```

## Polling pattern

Pull every 30s ~ 5min depending on role urgency. v1 has no push.

```python
import os, json, time, urllib.request

API = os.environ["MORA_KNODE_API"]
TOKEN = os.environ["MORA_KNODE_AGENT_TOKEN"]
AGENT = os.environ["MORA_KNODE_AGENT_ID"]
HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "X-Agent-Id": AGENT,
    "Content-Type": "application/json",
}
PRIORITY = {"Urgent": -20, "High": -10, "Normal": 0, "Low": 10, "Unset": 100}

def get(path):
    req = urllib.request.Request(f"{API}{path}", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read())

while True:
    rows = get("/api/agents/work-queue")
    rows.sort(key=lambda r: PRIORITY[r["task"]["priority"]])
    for row in rows:
        # ... pick the first one this pod can handle, do the work ...
        break
    time.sleep(30)
```

## Git safety guards (operator-side)

mora-knode does not enforce these; your pod / paired CLI should:

| Action | Recommended policy |
|---|---|
| Push to main / master | Forbidden — open a PR on Gitea instead |
| Force-push | Forbidden |
| `--no-verify` (skip hooks) | Forbidden |
| Delete > 5 files in one go | Human approval required |
| Merge a PR | Human approval required |

Branch naming: `agent/<task-number>-<slug>`. Commit style: Conventional
Commits (matches the rest of the mora-knode repo).

## Cost / quota

mora-knode does **not** measure tokens or USD. Your pod / paired CLI
manages its own budget — Claude Pro 5h limit, Cursor Pro fast-request
quota, OpenAI billing alerts, etc. If you want to record per-run cost
metadata for your own analysis, save it to your own log (a future
mora-knode endpoint may accept opt-in `AgentRun` rows; v1 doesn't).

## When things break

| Symptom | Likely cause | First check |
|---|---|---|
| 401 every call | Token rotated or revoked | Re-issue via `/api/agents/{id}/rotate`, update `.env` |
| 403 on `/approve` | Pod has Developer / QA RBAC | Approval is human-only by default — pod can't self-approve |
| 409 on plan transition | Plan already reviewed | Submit a new plan instead |
| Plan stuck in `PendingReview` for hours | Reviewer not seeing it | Slack / email the reviewer; later v2 will surface this via push |
