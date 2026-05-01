using MoraKnode.Auth;
using MoraKnode.Domain;
using MoraKnode.Infrastructure;

namespace MoraKnode.Endpoints;

public static class TaskHierarchyEndpoints
{
    public static IEndpointRouteBuilder MapTaskHierarchyEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/projects/{projectId}/tasks/hierarchy", async (
            string projectId,
            TaskRepository tasks,
            AssignmentRepository assignments,
            ScopeService scope,
            CancellationToken ct) =>
        {
            if (!await scope.CanSeeProjectAsync(projectId, ct)) return Results.NotFound();
            var list = await tasks.ListByProjectAsync(projectId, ct);
            var allowed = await scope.AccessibleTaskIdsAsync(ct);
            if (allowed is not null)
            {
                list = list.Where(t => allowed.Contains(t.Id)).ToList();
            }
            if (list.Count == 0)
                return Results.Ok(Array.Empty<TaskHierarchyNode>());

            var byId = list.ToDictionary(t => t.Id);
            var childrenByParent = list
                .Where(t => t.ParentTaskId != null)
                .GroupBy(t => t.ParentTaskId!)
                .ToDictionary(g => g.Key, g => g.ToList());

            // Single query for all assignment counts per task (so non-leaf with assignments can surface a warning).
            var allAssignments = await assignments.ListByTaskIdsAsync(list.Select(t => t.Id), ct);
            var assignCountByTask = allAssignments
                .GroupBy(a => a.TaskId)
                .ToDictionary(g => g.Key, g => g.Count());

            // Cache computed values to avoid recomputing shared subtrees.
            var cache = new Dictionary<string, _Computed>();

            _Computed Compute(TaskItem t)
            {
                if (cache.TryGetValue(t.Id, out var cached)) return cached;

                if (!childrenByParent.TryGetValue(t.Id, out var kids) || kids.Count == 0)
                {
                    var leaf = new _Computed(
                        t.Status,
                        t.OriginTimeline,
                        t.CurrentTimeline,
                        t.RealTimeline);
                    cache[t.Id] = leaf;
                    return leaf;
                }

                Timeline orig = new();
                Timeline cur = new();
                Timeline real = new();
                var statuses = new List<Domain.TaskStatus>(kids.Count);
                foreach (var c in kids)
                {
                    var cc = Compute(c);
                    orig = Union(orig, cc.OriginTimeline);
                    cur = Union(cur, cc.CurrentTimeline);
                    real = Union(real, cc.RealTimeline);
                    statuses.Add(cc.Status);
                }

                var computed = new _Computed(
                    AggregateStatus(statuses),
                    orig,
                    cur,
                    real);
                cache[t.Id] = computed;
                return computed;
            }

            var nodes = list.Select(t =>
            {
                var hasChildren = childrenByParent.ContainsKey(t.Id);
                var c = Compute(t);
                var assignmentCount = assignCountByTask.GetValueOrDefault(t.Id, 0);
                return new TaskHierarchyNode(
                    Id: t.Id,
                    ProjectId: t.ProjectId,
                    ParentTaskId: t.ParentTaskId,
                    Title: t.Title,
                    Description: t.Description,
                    Status: t.Status,
                    OriginTimeline: t.OriginTimeline,
                    CurrentTimeline: t.CurrentTimeline,
                    RealTimeline: t.RealTimeline,
                    HasChildren: hasChildren,
                    ComputedStatus: c.Status,
                    ComputedOriginTimeline: c.OriginTimeline,
                    ComputedCurrentTimeline: c.CurrentTimeline,
                    ComputedRealTimeline: c.RealTimeline,
                    AssignmentCount: assignmentCount,
                    NonLeafAssignmentWarning: hasChildren && assignmentCount > 0,
                    CreatedAt: t.CreatedAt,
                    UpdatedAt: t.UpdatedAt);
            }).ToList();

            return Results.Ok(nodes);
        }).WithTags("Tasks");

        return app;
    }

    private static Timeline Union(Timeline a, Timeline b)
    {
        DateTime? start = (a.Start, b.Start) switch
        {
            (null, var x) => x,
            (var x, null) => x,
            (var x, var y) => x < y ? x : y,
        };
        DateTime? end = (a.End, b.End) switch
        {
            (null, var x) => x,
            (var x, null) => x,
            (var x, var y) => x > y ? x : y,
        };
        return new Timeline { Start = start, End = end };
    }

    private static Domain.TaskStatus AggregateStatus(List<Domain.TaskStatus> statuses)
    {
        if (statuses.Count == 0) return Domain.TaskStatus.NotStarted;
        // All children reached a terminal state (success or otherwise) → parent is done.
        if (statuses.All(s => s == Domain.TaskStatus.Done
                           || s == Domain.TaskStatus.Cancelled
                           || s == Domain.TaskStatus.Dropped))
            return Domain.TaskStatus.Done;
        if (statuses.Any(s => s == Domain.TaskStatus.Blocked)) return Domain.TaskStatus.Blocked;
        if (statuses.Any(s => s == Domain.TaskStatus.InProgress || s == Domain.TaskStatus.Done))
            return Domain.TaskStatus.InProgress;
        // No active work yet, but a child is awaiting review — surface that on the parent.
        if (statuses.Any(s => s == Domain.TaskStatus.InReview)) return Domain.TaskStatus.InReview;
        return Domain.TaskStatus.NotStarted;
    }

    private record _Computed(
        Domain.TaskStatus Status,
        Timeline OriginTimeline,
        Timeline CurrentTimeline,
        Timeline RealTimeline);
}

public record TaskHierarchyNode(
    string Id,
    string ProjectId,
    string? ParentTaskId,
    string Title,
    string? Description,
    Domain.TaskStatus Status,
    Timeline OriginTimeline,
    Timeline CurrentTimeline,
    Timeline RealTimeline,
    bool HasChildren,
    Domain.TaskStatus ComputedStatus,
    Timeline ComputedOriginTimeline,
    Timeline ComputedCurrentTimeline,
    Timeline ComputedRealTimeline,
    int AssignmentCount,
    bool NonLeafAssignmentWarning,
    DateTime CreatedAt,
    DateTime UpdatedAt);
