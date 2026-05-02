using MongoDB.Bson;
using MongoDB.Driver;
using MoraKnode.Domain;

namespace MoraKnode.Infrastructure;

public class TaskRepository
{
    private readonly MongoContext _ctx;
    private readonly ChangeLogRepository _changeLogs;
    private readonly AppMetaRepository _appMeta;

    public TaskRepository(MongoContext ctx, ChangeLogRepository changeLogs, AppMetaRepository appMeta)
    {
        _ctx = ctx;
        _changeLogs = changeLogs;
        _appMeta = appMeta;
    }

    public Task<List<TaskItem>> ListByProjectAsync(string projectId, CancellationToken ct = default) =>
        _ctx.Tasks.Find(t => t.ProjectId == projectId).ToListAsync(ct);

    public Task<TaskItem?> GetAsync(string id, CancellationToken ct = default) =>
        _ctx.Tasks.Find(t => t.Id == id).FirstOrDefaultAsync(ct)!;

    public async Task<TaskItem> CreateAsync(TaskItem task, CancellationToken ct = default)
    {
        var now = DateTime.UtcNow;
        task.Id = ObjectId.GenerateNewId().ToString();
        task.CreatedAt = now;
        task.UpdatedAt = now;

        // MK-{N} identifier — atomic counter on the AppMeta singleton.
        // Migration backfills pre-existing tasks; new ones always pick up
        // a fresh number here so callers can't accidentally bypass it by
        // not setting the field client-side.
        task.Number = await _appMeta.AllocateNextTaskNumberAsync(ct);

        // On first create, if OriginTimeline (L1) is empty and CurrentTimeline (L2) is set,
        // snapshot L2 into L1 to lock the baseline.
        if (task.OriginTimeline.IsEmpty && !task.CurrentTimeline.IsEmpty)
        {
            task.OriginTimeline = new Timeline
            {
                Start = task.CurrentTimeline.Start,
                End = task.CurrentTimeline.End,
                IsAllDay = task.CurrentTimeline.IsAllDay
            };
        }

        NormalizeAllDay(task.OriginTimeline);
        NormalizeAllDay(task.CurrentTimeline);
        NormalizeAllDay(task.RealTimeline);

        await _ctx.Tasks.InsertOneAsync(task, cancellationToken: ct);
        // A new child shifts the rollup of its parent (and ancestors) — a
        // NotStarted child can pull a previously-Done parent back to
        // InProgress, etc.
        await RecomputeAncestorStatusAsync(task.ParentTaskId, ct);
        return task;
    }

    public async Task<TaskItem?> ReplaceAsync(string id, TaskItem incoming, CancellationToken ct = default)
    {
        var existing = await GetAsync(id, ct);
        if (existing is null) return null;

        var incomingReason = incoming.ChangeReason;
        var incomingChangedBy = incoming.ChangedBy;

        incoming.Id = id;
        incoming.ProjectId = existing.ProjectId;
        incoming.CreatedAt = existing.CreatedAt;
        incoming.UpdatedAt = DateTime.UtcNow;

        // L1 Origin is write-once: never overwrite once set.
        if (!existing.OriginTimeline.IsEmpty)
        {
            incoming.OriginTimeline = existing.OriginTimeline;
        }

        NormalizeAllDay(incoming.OriginTimeline);
        NormalizeAllDay(incoming.CurrentTimeline);
        NormalizeAllDay(incoming.RealTimeline);

        var logs = BuildTimelineChangeLogs(existing, incoming, incomingReason, incomingChangedBy);
        if (existing.Status != incoming.Status)
        {
            logs.Add(new ScheduleChangeLog
            {
                EntityType = ChangeEntityType.Task,
                EntityId = id,
                Field = "Status",
                BeforeValue = existing.Status.ToString(),
                AfterValue = incoming.Status.ToString(),
                Reason = incomingReason,
                ChangedBy = incomingChangedBy
            });
        }
        if (existing.IsWaiting != incoming.IsWaiting)
        {
            logs.Add(new ScheduleChangeLog
            {
                EntityType = ChangeEntityType.Task,
                EntityId = id,
                Field = "IsWaiting",
                BeforeValue = existing.IsWaiting.ToString(),
                AfterValue = incoming.IsWaiting.ToString(),
                Reason = incomingReason,
                ChangedBy = incomingChangedBy
            });
        }

        await _ctx.Tasks.ReplaceOneAsync(t => t.Id == id, incoming, cancellationToken: ct);
        await _changeLogs.InsertManyAsync(logs, ct);

        // Status rollup. Self first (in case this task has children and the
        // user nudged its status manually — children dictate the truth).
        // Then walk up to the current parent. If reparenting happened, the
        // *old* parent loses a child too and needs its own recompute.
        await RecomputeAncestorStatusAsync(id, ct);
        if (existing.ParentTaskId != incoming.ParentTaskId)
        {
            await RecomputeAncestorStatusAsync(existing.ParentTaskId, ct);
        }
        await RecomputeAncestorStatusAsync(incoming.ParentTaskId, ct);
        return incoming;
    }

    public async Task<bool> DeleteAsync(string id, CancellationToken ct = default)
    {
        // Capture the parent id before delete so the rollup can refresh
        // afterwards — losing a NotStarted child can flip a parent back
        // to Done if every remaining sibling is terminal.
        var existing = await GetAsync(id, ct);
        var parentTaskId = existing?.ParentTaskId;

        var result = await _ctx.Tasks.DeleteOneAsync(t => t.Id == id, ct);
        if (result.DeletedCount > 0)
        {
            await RecomputeAncestorStatusAsync(parentTaskId, ct);
        }
        return result.DeletedCount > 0;
    }

    /// <summary>
    /// Walks up from [id], recomputing each ancestor's stored status from
    /// its current children using <see cref="StatusAggregator"/>. Stops
    /// when a task has no children (leaf — nothing to roll up) or when
    /// a recomputed value matches the existing one (no further changes
    /// would propagate). Each persisted change is written to the
    /// ScheduleChangeLog as an "auto: rolled up from children" entry so
    /// the audit trail remains complete.
    /// </summary>
    private async Task RecomputeAncestorStatusAsync(string? id, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(id)) return;
        var task = await GetAsync(id, ct);
        if (task is null) return;

        var children = await _ctx.Tasks
            .Find(t => t.ParentTaskId == id)
            .Project(t => t.Status)
            .ToListAsync(ct);
        if (children.Count == 0) return;

        var rolledUp = StatusAggregator.Aggregate(children);
        if (task.Status == rolledUp) return;

        var oldStatus = task.Status;
        task.Status = rolledUp;
        task.UpdatedAt = DateTime.UtcNow;
        await _ctx.Tasks.ReplaceOneAsync(t => t.Id == id, task, cancellationToken: ct);
        await _changeLogs.InsertManyAsync(new[]
        {
            new ScheduleChangeLog
            {
                EntityType = ChangeEntityType.Task,
                EntityId = id,
                Field = "Status",
                BeforeValue = oldStatus.ToString(),
                AfterValue = rolledUp.ToString(),
                Reason = "auto: rolled up from children",
                ChangedBy = "system",
            }
        }, ct);

        await RecomputeAncestorStatusAsync(task.ParentTaskId, ct);
    }

    public async Task<long> DeleteByProjectAsync(string projectId, CancellationToken ct = default)
    {
        var result = await _ctx.Tasks.DeleteManyAsync(t => t.ProjectId == projectId, ct);
        return result.DeletedCount;
    }

    // Returns the subset of the given task ids that have at least one child task.
    public async Task<HashSet<string>> NonLeafIdsAsync(IEnumerable<string> taskIds, CancellationToken ct = default)
    {
        var list = taskIds.Distinct().ToList();
        if (list.Count == 0) return new HashSet<string>();

        var filter = Builders<TaskItem>.Filter.In(t => t.ParentTaskId, list);
        var parents = await _ctx.Tasks
            .Find(filter)
            .Project(t => t.ParentTaskId)
            .ToListAsync(ct);
        return parents.Where(p => p != null).Cast<string>().ToHashSet();
    }

    private static List<ScheduleChangeLog> BuildTimelineChangeLogs(
        TaskItem before,
        TaskItem after,
        string? reason,
        string? changedBy)
    {
        var logs = new List<ScheduleChangeLog>();
        // L1 Origin is write-once, but still record if a late first-set happens (from empty to set).
        AppendTimelineDiff(logs, before.Id, "OriginTimeline", before.OriginTimeline, after.OriginTimeline, reason, changedBy);
        AppendTimelineDiff(logs, before.Id, "CurrentTimeline", before.CurrentTimeline, after.CurrentTimeline, reason, changedBy);
        AppendTimelineDiff(logs, before.Id, "RealTimeline", before.RealTimeline, after.RealTimeline, reason, changedBy);
        return logs;
    }

    private static void AppendTimelineDiff(
        List<ScheduleChangeLog> logs,
        string taskId,
        string layer,
        Timeline before,
        Timeline after,
        string? reason,
        string? changedBy)
    {
        if (before.Start != after.Start)
        {
            logs.Add(new ScheduleChangeLog
            {
                EntityType = ChangeEntityType.Task,
                EntityId = taskId,
                Field = $"{layer}.Start",
                BeforeValue = FormatDate(before.Start),
                AfterValue = FormatDate(after.Start),
                Reason = reason,
                ChangedBy = changedBy
            });
        }

        if (before.End != after.End)
        {
            logs.Add(new ScheduleChangeLog
            {
                EntityType = ChangeEntityType.Task,
                EntityId = taskId,
                Field = $"{layer}.End",
                BeforeValue = FormatDate(before.End),
                AfterValue = FormatDate(after.End),
                Reason = reason,
                ChangedBy = changedBy
            });
        }
    }

    private static string? FormatDate(DateTime? value) =>
        value?.ToString("o");

    /// <summary>
    /// ADR-009: when a timeline is marked all-day, snap Start to 00:00:00.000
    /// UTC and End to 23:59:59.999 UTC of their respective dates. Idempotent.
    /// Skipped when the timeline is empty.
    /// </summary>
    private static void NormalizeAllDay(Timeline t)
    {
        if (!t.IsAllDay) return;
        if (t.Start is { } s)
        {
            t.Start = DateTime.SpecifyKind(new DateTime(s.Year, s.Month, s.Day, 0, 0, 0, 0), DateTimeKind.Utc);
        }
        if (t.End is { } e)
        {
            // 23:59:59.999 of that calendar day in UTC.
            t.End = DateTime.SpecifyKind(
                new DateTime(e.Year, e.Month, e.Day, 23, 59, 59, 999),
                DateTimeKind.Utc);
        }
    }
}
