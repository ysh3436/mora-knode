using MongoDB.Bson;
using MongoDB.Driver;
using MoraKnode.Domain;

namespace MoraKnode.Infrastructure;

public class MilestoneRepository
{
    private readonly MongoContext _ctx;
    public MilestoneRepository(MongoContext ctx) => _ctx = ctx;

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

        incoming.Id = id;
        incoming.ProjectId = existing.ProjectId;
        incoming.CreatedAt = existing.CreatedAt;
        incoming.UpdatedAt = DateTime.UtcNow;

        await _ctx.Milestones.ReplaceOneAsync(m => m.Id == id, incoming, cancellationToken: ct);
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
}
