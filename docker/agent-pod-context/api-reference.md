# mora-knode REST API reference (v1) — pod copy

> This file is a copy of [docs/api/external-agent-api.md](../../docs/api/external-agent-api.md)
> bundled into the agent-pod image. The live spec there is authoritative
> if the two ever drift; report drift as a bug.

## Authentication (must read)

Every request from a pod carries TWO headers:

```
Authorization: Bearer mk_<token>
X-Agent-Id: <agent-resource-id>
```

The token alone is not enough — `X-Agent-Id` must match the resource
that owns the token, or the request is rejected with **401**. This is
defence-in-depth so a leaked token without a paired ID can't silently
impersonate the agent.

## What the pod typically calls

| When | Method + path | Why |
|---|---|---|
| Operator one-time | `POST /api/agents` | Create the agent identity, get the raw token (only shown once). Done outside the pod. |
| Loop start | `GET /api/agents/work-queue` | Returns the agent's assigned non-terminal tasks + each task's latest plan. **No server-side sort in v1** — the pod sorts client-side. |
| Plan submit | `POST /api/agents/plans` | Body: `{taskId, title, steps[], notes?, estimateMinutes?}`. Side-effect: task → `PlanReview`. |
| Status update | `PUT /api/tasks/{id}` | After approval, mark `InProgress`; after PR ready, mark `WorkReview`. Include `changeReason` + `changedBy` in body for audit. |
| Result handoff | `POST /api/tasks/{taskId}/comments` | Body: `{body: "PR url + summary", kind: "review"}`. The reviewer sees this in the inspector. |

### Lifecycle states (string)

`Created → Planning → PlanReview → InProgress → WorkReview → Done`,
plus `OnHold`, `Cancelled`, `Dropped`. The pod never moves a task into
a terminal state on its own — that's the human's call.

### Priority sort (client-side)

```python
PRIORITY = {"Urgent": -20, "High": -10, "Normal": 0, "Low": 10, "Unset": 100}
rows.sort(key=lambda r: PRIORITY[r["task"]["priority"]])
```

### Plan gate

Submit creates a new `AgentPlan` (PendingReview). Reviewers (Human /
Manager / Reviewer) approve or reject. **Plans are immutable once
submitted** — to revise, submit a new plan; the old row stays for audit.

### What v1 doesn't have (don't try)

- `POST /api/agents/work-queue/{id}/claim` — no atomic lock. v1 relies
  on the pod / role separation to avoid races.
- `POST /api/agents/runs` — no execution metric reporting endpoint.
- `?sort=` / `?role=` query filters on `/work-queue`.
- SSE / webhook / push delivery.

These are roadmap items; see the full spec for timing.

## Error format

```json
{ "error": "<message>", "detail": "..." }
```

Status codes follow the obvious convention (200 / 201 / 204 / 400 / 401 /
403 / 404 / 409). The pod should treat **401 as fatal** (token rotation
in flight) and back off rather than retry.

## Concrete walkthrough

See [workflow-guide.md](workflow-guide.md) for an end-to-end example
(register → poll → submit plan → comment) using the patterns the
operator's bot will replicate.
