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

            // Derive a Notion/MS-Project-style outline number ("1.2.3") from
            // current tree position. Per-sibling order = ascending Number, so
            // the WBS reads stably across requests as long as the underlying
            // MK-N values don't change. WBS itself is *derived per request*
            // — never stored, never persisted — because tree edits would
            // otherwise leave dangling values around. Stable identifier =
            // Number. Positional label = Wbs.
            var roots = list.Where(t => t.ParentTaskId == null)
                            .OrderBy(t => t.Number)
                            .ThenBy(t => t.CreatedAt)
                            .ToList();
            var wbsById = new Dictionary<string, string>(list.Count);

            void AssignWbs(IEnumerable<TaskItem> siblings, string prefix)
            {
                var i = 1;
                foreach (var sib in siblings)
                {
                    var code = prefix.Length == 0 ? i.ToString() : $"{prefix}.{i}";
                    wbsById[sib.Id] = code;
                    if (childrenByParent.TryGetValue(sib.Id, out var kids))
                    {
                        AssignWbs(kids.OrderBy(k => k.Number).ThenBy(k => k.CreatedAt), code);
                    }
                    i++;
                }
            }
            AssignWbs(roots, string.Empty);

            // Cache computed values to avoid recomputing shared subtrees.
            var cache = new Dictionary<string, _Computed>();

            _Computed Compute(TaskItem t)
            {
                if (cache.TryGetValue(t.Id, out var cached)) return cached;

                if (!childrenByParent.TryGetValue(t.Id, out var kids) || kids.Count == 0)
                {
                    var leaf = new _Computed(
                        t.Status,
                        t.Priority,
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
                // Only priorities of children that are still in flight feed
                // the aggregate — once a leaf reaches Done/Cancelled/Dropped
                // its urgency is no longer a triage signal for the parent.
                var activePriorities = new List<Domain.TaskPriority>(kids.Count);
                foreach (var c in kids)
                {
                    var cc = Compute(c);
                    orig = Union(orig, cc.OriginTimeline);
                    cur = Union(cur, cc.CurrentTimeline);
                    real = Union(real, cc.RealTimeline);
                    statuses.Add(cc.Status);
                    if (cc.Status != Domain.TaskStatus.Done
                        && cc.Status != Domain.TaskStatus.Cancelled
                        && cc.Status != Domain.TaskStatus.Dropped)
                    {
                        activePriorities.Add(cc.Priority);
                    }
                }

                var computed = new _Computed(
                    AggregateStatus(statuses),
                    AggregatePriority(activePriorities),
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
                    Number: t.Number,
                    Wbs: wbsById.GetValueOrDefault(t.Id, string.Empty),
                    Title: t.Title,
                    Description: t.Description,
                    Status: t.Status,
                    Priority: t.Priority,
                    OriginTimeline: t.OriginTimeline,
                    CurrentTimeline: t.CurrentTimeline,
                    RealTimeline: t.RealTimeline,
                    HasChildren: hasChildren,
                    ComputedStatus: c.Status,
                    ComputedPriority: c.Priority,
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

    private static Domain.TaskStatus AggregateStatus(List<Domain.TaskStatus> statuses) =>
        Domain.StatusAggregator.Aggregate(statuses);

    // Caller already filtered out children that are no longer in flight
    // (Done/Cancelled/Dropped) — what's left is the active triage pool.
    // The TaskPriority enum is anchored at Normal=0 with Urgent at the
    // most-negative end and Unset at +100, so a plain Min() naturally
    // surfaces the most urgent value and falls back to Unset only when
    // every active child is Unset.
    private static Domain.TaskPriority AggregatePriority(List<Domain.TaskPriority> activePriorities)
    {
        if (activePriorities.Count == 0) return Domain.TaskPriority.Unset;
        return activePriorities.Min();
    }

    private record _Computed(
        Domain.TaskStatus Status,
        Domain.TaskPriority Priority,
        Timeline OriginTimeline,
        Timeline CurrentTimeline,
        Timeline RealTimeline);
}

public record TaskHierarchyNode(
    string Id,
    string ProjectId,
    string? ParentTaskId,
    int Number,
    string Wbs,
    string Title,
    string? Description,
    Domain.TaskStatus Status,
    Domain.TaskPriority Priority,
    Timeline OriginTimeline,
    Timeline CurrentTimeline,
    Timeline RealTimeline,
    bool HasChildren,
    Domain.TaskStatus ComputedStatus,
    Domain.TaskPriority ComputedPriority,
    Timeline ComputedOriginTimeline,
    Timeline ComputedCurrentTimeline,
    Timeline ComputedRealTimeline,
    int AssignmentCount,
    bool NonLeafAssignmentWarning,
    DateTime CreatedAt,
    DateTime UpdatedAt);
