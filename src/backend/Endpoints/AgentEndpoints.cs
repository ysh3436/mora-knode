using MoraKnode.Auth;
using MoraKnode.Domain;
using MoraKnode.Infrastructure;
using TaskStatus = MoraKnode.Domain.TaskStatus;

namespace MoraKnode.Endpoints;

public static class AgentEndpoints
{
    public static IEndpointRouteBuilder MapAgentEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/agents").WithTags("Agents");

        // List every Resource of Kind=Agent. Tokens are not joined here —
        // surfacing per-agent token info goes through GET /:id/tokens so
        // the list endpoint stays cheap.
        group.MapGet("/", async (ResourceRepository resources, CancellationToken ct) =>
        {
            var all = await resources.ListAsync(ct);
            return Results.Ok(all.Where(r => r.Kind == ResourceKind.Agent));
        });

        // Issue a new agent identity in one shot: a Resource (Kind=Agent) +
        // its first AgentToken. The raw token string is returned exactly
        // once in the response — losing it means the caller has to rotate.
        group.MapPost("/", async (
            CreateAgentRequest req,
            ResourceRepository resources,
            AgentTokenRepository tokens,
            CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(req.Name))
                return Results.BadRequest(new { error = "Name is required" });
            if (await resources.GetByNameAsync(req.Name.Trim(), ct) is not null)
                return Results.Conflict(new { error = $"Resource name '{req.Name}' is already in use" });

            var resource = await resources.CreateAsync(new Resource
            {
                Name = req.Name.Trim(),
                Role = req.Role,
                Kind = ResourceKind.Agent,
                Rbac = req.Rbac ?? RbacPreset.Developer,
                AgentDescription = req.Description,
                CapacityPercent = req.CapacityPercent ?? 100,
            }, ct);

            var issued = TokenGenerator.Issue();
            await tokens.InsertAsync(new AgentToken
            {
                ResourceId = resource.Id,
                TokenHashSha256 = issued.Hash,
                LastFourChars = issued.LastFour,
                CreatedAt = DateTime.UtcNow,
            }, ct);

            return Results.Created($"/api/agents/{resource.Id}", new CreateAgentResponse(
                Agent: resource,
                RawToken: issued.Raw,
                LastFour: issued.LastFour));
        });

        // Token history for one agent. Active = RevokedAt is null. The raw
        // token is never returned here (we only stored the hash); rotate
        // is the only path to see a usable raw token again.
        group.MapGet("/{id}/tokens", async (
            string id,
            AgentTokenRepository tokens,
            CancellationToken ct) =>
        {
            var rows = await tokens.ListByResourceAsync(id, ct);
            return Results.Ok(rows.Select(t => new TokenSummary(
                Id: t.Id,
                LastFour: t.LastFourChars,
                CreatedAt: t.CreatedAt,
                RevokedAt: t.RevokedAt,
                LastSeenAt: t.LastSeenAt,
                IsActive: t.RevokedAt is null)));
        });

        // Atomic rotate: revoke any active token row(s) for this agent,
        // then issue a fresh one. The new raw token is returned exactly
        // once. Audit-friendly: the prior row stays in the collection
        // with RevokedAt set, so "who has historically used what" is
        // still answerable.
        group.MapPost("/{id}/rotate", async (
            string id,
            ResourceRepository resources,
            AgentTokenRepository tokens,
            CancellationToken ct) =>
        {
            var resource = await resources.GetAsync(id, ct);
            if (resource is null || resource.Kind != ResourceKind.Agent)
                return Results.NotFound();

            await tokens.RevokeAllForResourceAsync(id, ct);
            var issued = TokenGenerator.Issue();
            await tokens.InsertAsync(new AgentToken
            {
                ResourceId = id,
                TokenHashSha256 = issued.Hash,
                LastFourChars = issued.LastFour,
                CreatedAt = DateTime.UtcNow,
            }, ct);
            return Results.Ok(new RotateTokenResponse(RawToken: issued.Raw, LastFour: issued.LastFour));
        });

        // Revoke without re-issuing. After this, every Bearer auth attempt
        // for this agent fails 401. The Resource itself stays in place so
        // historical assignments / change logs remain readable.
        group.MapPost("/{id}/revoke", async (
            string id,
            ResourceRepository resources,
            AgentTokenRepository tokens,
            CancellationToken ct) =>
        {
            var resource = await resources.GetAsync(id, ct);
            if (resource is null || resource.Kind != ResourceKind.Agent)
                return Results.NotFound();
            var n = await tokens.RevokeAllForResourceAsync(id, ct);
            return Results.Ok(new { revoked = n });
        });

        // ---------- Plan gate (ADR-002) ----------
        // POST /api/agents/plans
        // Submit a plan for review. Caller must be authenticated and
        // assigned to the target task (Q3 strict). Side-effect: bumps the
        // task's lifecycle into PlanReview so the matrix view surfaces "a
        // human needs to look at this" without polling. The bot doesn't
        // separately PUT /tasks/{id} — submission and lifecycle move are
        // one atomic actor decision.
        group.MapPost("/plans", async (
            SubmitPlanRequest req,
            UserContext userCtx,
            AgentPlanRepository plans,
            TaskRepository tasks,
            AssignmentRepository assignments,
            CancellationToken ct) =>
        {
            if (userCtx.CurrentUser is null)
                return Results.Json(new { error = "Authentication required to submit plans." },
                    statusCode: StatusCodes.Status401Unauthorized);
            if (string.IsNullOrWhiteSpace(req.TaskId))
                return Results.BadRequest(new { error = "TaskId is required" });
            if (string.IsNullOrWhiteSpace(req.Title))
                return Results.BadRequest(new { error = "Title is required" });

            var task = await tasks.GetAsync(req.TaskId, ct);
            if (task is null) return Results.NotFound(new { error = "Task not found" });

            // Strict: only assignees can submit. Humans (Manager/Reviewer/
            // Human preset) bypass — they can propose on any task in their
            // remit (matches the IsAdmin treatment in UserContext).
            if (!userCtx.IsAdmin)
            {
                var mine = await assignments.ListAsync(
                    resourceId: userCtx.CurrentUser.Id,
                    taskId: req.TaskId,
                    ct: ct);
                if (mine.Count == 0)
                    return Results.Json(
                        new { error = "Submitter is not assigned to this task." },
                        statusCode: StatusCodes.Status403Forbidden);
            }

            var plan = await plans.InsertAsync(new AgentPlan
            {
                TaskId = req.TaskId,
                SubmittedByResourceId = userCtx.CurrentUser.Id,
                Status = PlanStatus.PendingReview,
                Title = req.Title.Trim(),
                EstimateMinutes = req.EstimateMinutes,
                Steps = req.Steps?.Select(s => new PlanStep
                {
                    Description = s.Description ?? string.Empty,
                    EstimateMinutes = s.EstimateMinutes,
                }).ToList() ?? new List<PlanStep>(),
                Notes = req.Notes,
            }, ct);

            // Bump task into PlanReview unless the user's already moved it
            // somewhere terminal — we never drag a Done/Cancelled/Dropped
            // task back into the review flow on a stale submission.
            if (task.Status is TaskStatus.Created
                            or TaskStatus.Planning
                            or TaskStatus.PlanReview
                            or TaskStatus.InProgress
                            or TaskStatus.OnHold)
            {
                task.Status = TaskStatus.PlanReview;
                task.ChangeReason = $"plan submitted (plan id {plan.Id})";
                task.ChangedBy = userCtx.CurrentUser.Name;
                await tasks.ReplaceAsync(task.Id, task, ct);
            }

            return Results.Created($"/api/agents/plans/{plan.Id}", plan);
        });

        // GET /api/agents/plans?status=PendingReview&taskId=...&submittedBy=...
        // The review queue UI hits this with status=PendingReview. The
        // task-detail UI hits it with taskId=... to render plan history.
        group.MapGet("/plans", async (
            string? status,
            string? taskId,
            string? submittedBy,
            AgentPlanRepository plans,
            CancellationToken ct) =>
        {
            PlanStatus? statusFilter = null;
            if (!string.IsNullOrWhiteSpace(status))
            {
                if (!Enum.TryParse<PlanStatus>(status, ignoreCase: true, out var s))
                    return Results.BadRequest(new { error = $"Unknown plan status '{status}'" });
                statusFilter = s;
            }
            var rows = await plans.ListAsync(taskId, submittedBy, statusFilter, ct);
            return Results.Ok(rows);
        });

        group.MapGet("/plans/{id}", async (
            string id,
            AgentPlanRepository plans,
            CancellationToken ct) =>
        {
            var plan = await plans.GetAsync(id, ct);
            return plan is null ? Results.NotFound() : Results.Ok(plan);
        });

        // PUT /api/agents/plans/{id}/approve
        // Human-only gate. Approving is the actor decision that says "the
        // plan is good — do the work". Same call moves the task forward
        // into InProgress so the bot's next work-queue poll sees the
        // approved task ready to execute.
        group.MapPut("/plans/{id}/approve", async (
            string id,
            ApprovePlanRequest? req,
            UserContext userCtx,
            AgentPlanRepository plans,
            TaskRepository tasks,
            CancellationToken ct) =>
        {
            var (deny, _) = RequireHuman(userCtx);
            if (deny is not null) return deny;

            var plan = await plans.GetAsync(id, ct);
            if (plan is null) return Results.NotFound();
            if (plan.Status != PlanStatus.PendingReview)
                return Results.Conflict(new { error = $"Plan is already {plan.Status}." });

            plan.Status = PlanStatus.Approved;
            plan.ReviewerComment = req?.Comment;
            plan.ReviewedByResourceId = userCtx.CurrentUser!.Id;
            plan.ReviewedAt = DateTime.UtcNow;
            await plans.ReplaceAsync(id, plan, ct);

            await SyncTaskAfterReview(plan.TaskId, TaskStatus.InProgress,
                $"plan approved (plan id {id})", userCtx.CurrentUser.Name, tasks, ct);

            return Results.Ok(plan);
        });

        // PUT /api/agents/plans/{id}/reject
        // Reject requires a comment so the agent has something to act on.
        // Lifecycle goes back to InProgress per the 9-step design — the
        // bot picks the task back up, decides whether to re-plan or push
        // through, and submits a new plan or moves to WorkReview directly.
        group.MapPut("/plans/{id}/reject", async (
            string id,
            RejectPlanRequest req,
            UserContext userCtx,
            AgentPlanRepository plans,
            TaskRepository tasks,
            CancellationToken ct) =>
        {
            var (deny, _) = RequireHuman(userCtx);
            if (deny is not null) return deny;
            if (req is null || string.IsNullOrWhiteSpace(req.Comment))
                return Results.BadRequest(new { error = "Comment is required to reject a plan." });

            var plan = await plans.GetAsync(id, ct);
            if (plan is null) return Results.NotFound();
            if (plan.Status != PlanStatus.PendingReview)
                return Results.Conflict(new { error = $"Plan is already {plan.Status}." });

            plan.Status = PlanStatus.Rejected;
            plan.ReviewerComment = req.Comment.Trim();
            plan.ReviewedByResourceId = userCtx.CurrentUser!.Id;
            plan.ReviewedAt = DateTime.UtcNow;
            await plans.ReplaceAsync(id, plan, ct);

            await SyncTaskAfterReview(plan.TaskId, TaskStatus.InProgress,
                $"plan rejected (plan id {id}): {req.Comment.Trim()}",
                userCtx.CurrentUser.Name, tasks, ct);

            return Results.Ok(plan);
        });

        // PUT /api/agents/plans/{id}/revert
        // Undo a previous approve / reject. Allowed for the original
        // reviewer (so they can fix a misclick) or any Manager (override
        // path for cases where the original reviewer is unavailable).
        // Side effect: task lifecycle moves back to PlanReview so the
        // queue surface re-surfaces the plan.
        group.MapPut("/plans/{id}/revert", async (
            string id,
            UserContext userCtx,
            AgentPlanRepository plans,
            TaskRepository tasks,
            CancellationToken ct) =>
        {
            if (userCtx.CurrentUser is null)
                return Results.Json(
                    new { error = "Authentication required." },
                    statusCode: StatusCodes.Status401Unauthorized);

            var plan = await plans.GetAsync(id, ct);
            if (plan is null) return Results.NotFound();
            if (plan.Status == PlanStatus.PendingReview)
                return Results.Conflict(new { error = "Plan has not been reviewed yet." });

            // Self-or-Manager: the original reviewer can always undo their
            // own decision; Managers can override anyone (escalation path
            // when the original reviewer isn't around).
            var isOwner = string.Equals(plan.ReviewedByResourceId, userCtx.CurrentUser.Id, StringComparison.Ordinal);
            var isManager = userCtx.CurrentUser.Rbac == RbacPreset.Manager;
            if (!isOwner && !isManager)
                return Results.Json(
                    new { error = "Only the original reviewer or a Manager can revert this decision." },
                    statusCode: StatusCodes.Status403Forbidden);

            plan.Status = PlanStatus.PendingReview;
            plan.ReviewerComment = null;
            plan.ReviewedByResourceId = null;
            plan.ReviewedAt = null;
            await plans.ReplaceAsync(id, plan, ct);

            await SyncTaskAfterReview(plan.TaskId, TaskStatus.PlanReview,
                $"plan reverted to PendingReview (plan id {id})",
                userCtx.CurrentUser.Name, tasks, ct);

            return Results.Ok(plan);
        });

        // ---------- Work-queue ----------
        // GET /api/agents/work-queue
        // Returns the calling agent's assigned tasks paired with their
        // latest plan (if any). v1 doesn't lock or claim — every assigned
        // task surfaces, and the bot decides what to pick. The latest plan
        // is what tells the bot whether it should be planning, awaiting
        // review, or executing.
        group.MapGet("/work-queue", async (
            UserContext userCtx,
            AssignmentRepository assignments,
            TaskRepository tasks,
            AgentPlanRepository plans,
            CancellationToken ct) =>
        {
            if (userCtx.CurrentUser is null)
                return Results.Json(new { error = "Authentication required." },
                    statusCode: StatusCodes.Status401Unauthorized);

            var mine = await assignments.ListAsync(resourceId: userCtx.CurrentUser.Id, ct: ct);
            var rows = new List<WorkQueueRow>();
            foreach (var a in mine)
            {
                var task = await tasks.GetAsync(a.TaskId, ct);
                if (task is null) continue;
                // Terminal tasks aren't actionable — keep the queue lean
                // by hiding Done/Cancelled/Dropped. The bot can fetch full
                // history through /api/tasks if it ever needs them.
                if (task.Status is TaskStatus.Done
                                or TaskStatus.Cancelled
                                or TaskStatus.Dropped) continue;
                var latest = await plans.LatestForTaskAsync(task.Id, ct);
                rows.Add(new WorkQueueRow(task, latest));
            }
            return Results.Ok(rows);
        });

        return app;
    }

    private static (IResult? deny, Resource? user) RequireHuman(UserContext userCtx)
    {
        if (userCtx.CurrentUser is null)
            return (Results.Json(
                new { error = "Authentication required." },
                statusCode: StatusCodes.Status401Unauthorized), null);
        // ADR-004 §3 / phase15-domain-sketch §3.3: v1 confines plan
        // approval to human-class presets. Agents can submit but never
        // approve their own (or each other's) plans.
        var rbac = userCtx.CurrentUser.Rbac;
        if (rbac is not (RbacPreset.Human or RbacPreset.Manager or RbacPreset.Reviewer))
            return (Results.Json(
                new { error = "Plan approve/reject is restricted to human reviewers." },
                statusCode: StatusCodes.Status403Forbidden), null);
        return (null, userCtx.CurrentUser);
    }

    private static async Task SyncTaskAfterReview(
        string taskId,
        TaskStatus target,
        string reason,
        string? reviewerName,
        TaskRepository tasks,
        CancellationToken ct)
    {
        var task = await tasks.GetAsync(taskId, ct);
        if (task is null) return;
        // Don't drag a task that's already moved on (e.g. user manually
        // marked it Done after the plan was submitted) back into the flow.
        if (task.Status is TaskStatus.Done
                        or TaskStatus.Cancelled
                        or TaskStatus.Dropped) return;
        if (task.Status == target) return;
        task.Status = target;
        task.ChangeReason = reason;
        task.ChangedBy = reviewerName;
        await tasks.ReplaceAsync(taskId, task, ct);
    }
}

public record CreateAgentRequest(
    string Name,
    string? Role,
    string? Description,
    RbacPreset? Rbac,
    int? CapacityPercent);

public record CreateAgentResponse(
    Resource Agent,
    string RawToken,
    string LastFour);

public record RotateTokenResponse(
    string RawToken,
    string LastFour);

public record TokenSummary(
    string Id,
    string LastFour,
    DateTime CreatedAt,
    DateTime? RevokedAt,
    DateTime? LastSeenAt,
    bool IsActive);

public record SubmitPlanRequest(
    string TaskId,
    string Title,
    int? EstimateMinutes,
    List<PlanStepInput>? Steps,
    string? Notes);

public record PlanStepInput(
    string? Description,
    int? EstimateMinutes);

public record ApprovePlanRequest(string? Comment);

public record RejectPlanRequest(string Comment);

public record WorkQueueRow(TaskItem Task, AgentPlan? LatestPlan);
