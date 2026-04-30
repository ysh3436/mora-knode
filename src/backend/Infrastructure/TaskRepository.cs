using MongoDB.Bson;
using MongoDB.Driver;
using MoraKnode.Domain;

namespace MoraKnode.Infrastructure;

public class TaskRepository
{
    private readonly MongoContext _ctx;
    private readonly ChangeLogRepository _changeLogs;

    public TaskRepository(MongoContext ctx, ChangeLogRepository changeLogs)
    {
        _ctx = ctx;
        _changeLogs = changeLogs;
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

        // On first create, if OriginTimeline (L1) is empty and CurrentTimeline (L2) is set,
        // snapshot L2 into L1 to lock the baseline.
        if (task.OriginTimeline.IsEmpty && !task.CurrentTimeline.IsEmpty)
        {
            task.OriginTimeline = new Timeline
            {
                Start = task.CurrentTimeline.Start,
                End = task.CurrentTimeline.End
            };
        }

        await _ctx.Tasks.InsertOneAsync(task, cancellationToken: ct);
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

        await _ctx.Tasks.ReplaceOneAsync(t => t.Id == id, incoming, cancellationToken: ct);
        await _changeLogs.InsertManyAsync(logs, ct);
        return incoming;
    }

    public async Task<bool> DeleteAsync(string id, CancellationToken ct = default)
    {
        var result = await _ctx.Tasks.DeleteOneAsync(t => t.Id == id, ct);
        return result.DeletedCount > 0;
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
}
