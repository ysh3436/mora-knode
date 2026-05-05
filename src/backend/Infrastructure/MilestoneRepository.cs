using MongoDB.Bson;
using MongoDB.Driver;
using MoraKnode.Domain;

namespace MoraKnode.Infrastructure;

public class MilestoneRepository
{
    private readonly MongoContext _ctx;
    private readonly ChangeLogRepository _changeLogs;

    public MilestoneRepository(MongoContext ctx, ChangeLogRepository changeLogs)
    {
        _ctx = ctx;
        _changeLogs = changeLogs;
    }

    public Task<List<Milestone>> ListByProjectAsync(string projectId, CancellationToken ct = default) =>
        _ctx.Milestones.Find(m => m.ProjectId == projectId).SortBy(m => m.Date).ToListAsync(ct);

    public Task<Milestone?> GetAsync(string id, CancellationToken ct = default) =>
        _ctx.Milestones.Find(m => m.Id == id).FirstOrDefaultAsync(ct)!;

    public async Task<Milestone> CreateAsync(Milestone milestone, CancellationToken ct = default)
    {
        var now = DateTime.UtcNow;
        milestone.Id = ObjectId.GenerateNewId().ToString();
        milestone.CreatedAt = now;
        milestone.UpdatedAt = now;
        await _ctx.Milestones.InsertOneAsync(milestone, cancellationToken: ct);
        return milestone;
    }

    public async Task<Milestone?> ReplaceAsync(string id, Milestone incoming, CancellationToken ct = default)
    {
        var existing = await GetAsync(id, ct);
        if (existing is null) return null;

        var reason = incoming.ChangeReason;
        var changedBy = incoming.ChangedBy;

        incoming.Id = id;
        incoming.ProjectId = existing.ProjectId;
        incoming.CreatedAt = existing.CreatedAt;
        incoming.UpdatedAt = DateTime.UtcNow;

        var logs = new List<ScheduleChangeLog>();
        if (existing.Title != incoming.Title)
            logs.Add(BuildLog(id, "Title", existing.Title, incoming.Title, reason, changedBy));
        if (existing.Date != incoming.Date)
            logs.Add(BuildLog(id, "Date", existing.Date.ToString("o"), incoming.Date.ToString("o"), reason, changedBy));
        if (existing.Status != incoming.Status)
            logs.Add(BuildLog(id, "Status", existing.Status.ToString(), incoming.Status.ToString(), reason, changedBy));

        await _ctx.Milestones.ReplaceOneAsync(m => m.Id == id, incoming, cancellationToken: ct);
        await _changeLogs.InsertManyAsync(logs, ct);
        return incoming;
    }

    public async Task<bool> DeleteAsync(string id, CancellationToken ct = default)
    {
        var result = await _ctx.Milestones.DeleteOneAsync(m => m.Id == id, ct);
        return result.DeletedCount > 0;
    }

    public async Task<long> DeleteByProjectAsync(string projectId, CancellationToken ct = default)
    {
        var result = await _ctx.Milestones.DeleteManyAsync(m => m.ProjectId == projectId, ct);
        return result.DeletedCount;
    }

    private static ScheduleChangeLog BuildLog(
        string milestoneId, string field, string? before, string? after, string? reason, string? changedBy) =>
        new()
        {
            EntityType = ChangeEntityType.Milestone,
            EntityId = milestoneId,
            Field = field,
            BeforeValue = before,
            AfterValue = after,
            Reason = reason,
            ChangedBy = changedBy,
        };
}
