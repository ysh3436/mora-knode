using MongoDB.Bson;
using MongoDB.Driver;
using MoraKnode.Domain;

namespace MoraKnode.Infrastructure;

public class ChangeLogRepository
{
    private readonly MongoContext _ctx;
    public ChangeLogRepository(MongoContext ctx) => _ctx = ctx;

    public Task<List<ScheduleChangeLog>> ListAsync(
        ChangeEntityType? entityType = null,
        string? entityId = null,
        int limit = 100,
        CancellationToken ct = default)
    {
        var filter = Builders<ScheduleChangeLog>.Filter.Empty;
        if (entityType is not null)
            filter &= Builders<ScheduleChangeLog>.Filter.Eq(x => x.EntityType, entityType.Value);
        if (!string.IsNullOrWhiteSpace(entityId))
            filter &= Builders<ScheduleChangeLog>.Filter.Eq(x => x.EntityId, entityId);

        return _ctx.ChangeLogs
            .Find(filter)
            .SortByDescending(x => x.ChangedAt)
            .Limit(limit)
            .ToListAsync(ct);
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
