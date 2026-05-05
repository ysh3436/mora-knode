using MongoDB.Bson;
using MongoDB.Driver;
using MoraKnode.Domain;

namespace MoraKnode.Infrastructure;

public class ChangeLogRepository
{
    private readonly MongoContext _ctx;
    public ChangeLogRepository(MongoContext ctx) => _ctx = ctx;

    /// <summary>
    /// Returns the slice [offset, offset+limit) of change-log rows matching
    /// the given filters (newest first), paired with the total count for
    /// the same filters so callers can render a "page X of Y" indicator.
    ///
    /// Supported filters:
    /// - entityType: limit to one kind (Task / Project / Milestone)
    /// - entityId: limit to one specific entity
    /// - projectId: limit to a project's worth of activity — the project
    ///   itself, every task that belongs to it, and every milestone tied
    ///   to it. Composes with entityType (e.g. "tasks in this project").
    /// - from / to: half-open ChangedAt range [from, to) UTC
    /// </summary>
    public async Task<(List<ScheduleChangeLog> rows, long total)> ListAsync(
        ChangeEntityType? entityType = null,
        string? entityId = null,
        string? projectId = null,
        DateTime? from = null,
        DateTime? to = null,
        int offset = 0,
        int limit = 100,
        CancellationToken ct = default)
    {
        var f = Builders<ScheduleChangeLog>.Filter.Empty;
        if (entityType is not null)
            f &= Builders<ScheduleChangeLog>.Filter.Eq(x => x.EntityType, entityType.Value);
        if (!string.IsNullOrWhiteSpace(entityId))
            f &= Builders<ScheduleChangeLog>.Filter.Eq(x => x.EntityId, entityId);
        if (from is not null)
            f &= Builders<ScheduleChangeLog>.Filter.Gte(x => x.ChangedAt, from.Value);
        if (to is not null)
            f &= Builders<ScheduleChangeLog>.Filter.Lt(x => x.ChangedAt, to.Value);

        if (!string.IsNullOrWhiteSpace(projectId))
        {
            // Project scope spans three entity buckets — the project doc
            // itself, its tasks, and its milestones. Resolve the latter
            // two from their respective collections so the audit feed
            // shows everything that "happened on this project" without
            // the caller having to union three queries.
            var taskIds = await _ctx.Tasks
                .Find(t => t.ProjectId == projectId)
                .Project(t => t.Id)
                .ToListAsync(ct);
            var milestoneIds = await _ctx.Milestones
                .Find(m => m.ProjectId == projectId)
                .Project(m => m.Id)
                .ToListAsync(ct);
            var allIds = new List<string> { projectId };
            allIds.AddRange(taskIds);
            allIds.AddRange(milestoneIds);
            f &= Builders<ScheduleChangeLog>.Filter.In(x => x.EntityId, allIds);
        }

        var total = await _ctx.ChangeLogs.CountDocumentsAsync(f, cancellationToken: ct);
        var rows = await _ctx.ChangeLogs
            .Find(f)
            .SortByDescending(x => x.ChangedAt)
            .Skip(offset)
            .Limit(limit)
            .ToListAsync(ct);
        return (rows, total);
    }

    public Task InsertManyAsync(IReadOnlyList<ScheduleChangeLog> logs, CancellationToken ct = default)
    {
        if (logs.Count == 0) return Task.CompletedTask;

        var now = DateTime.UtcNow;
        foreach (var log in logs)
        {
            if (string.IsNullOrEmpty(log.Id))
                log.Id = ObjectId.GenerateNewId().ToString();
            if (log.ChangedAt == default)
                log.ChangedAt = now;
        }
        return _ctx.ChangeLogs.InsertManyAsync(logs, cancellationToken: ct);
    }
}
