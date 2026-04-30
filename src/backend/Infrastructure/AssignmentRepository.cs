using MongoDB.Bson;
using MongoDB.Driver;
using MoraKnode.Domain;

namespace MoraKnode.Infrastructure;

public class AssignmentRepository
{
    private readonly MongoContext _ctx;
    public AssignmentRepository(MongoContext ctx) => _ctx = ctx;

    public Task<List<Assignment>> ListAsync(
        string? resourceId = null,
        string? taskId = null,
        CancellationToken ct = default)
    {
        var filter = Builders<Assignment>.Filter.Empty;
        if (!string.IsNullOrWhiteSpace(resourceId))
            filter &= Builders<Assignment>.Filter.Eq(x => x.ResourceId, resourceId);
        if (!string.IsNullOrWhiteSpace(taskId))
            filter &= Builders<Assignment>.Filter.Eq(x => x.TaskId, taskId);
        return _ctx.Assignments.Find(filter).ToListAsync(ct);
    }

    public Task<Assignment?> GetAsync(string id, CancellationToken ct = default) =>
        _ctx.Assignments.Find(a => a.Id == id).FirstOrDefaultAsync(ct)!;

    public async Task<Assignment> CreateAsync(Assignment assignment, CancellationToken ct = default)
    {
        var now = DateTime.UtcNow;
        assignment.Id = ObjectId.GenerateNewId().ToString();
        assignment.CreatedAt = now;
        assignment.UpdatedAt = now;
        await _ctx.Assignments.InsertOneAsync(assignment, cancellationToken: ct);
        return assignment;
    }

    public async Task<Assignment?> ReplaceAsync(string id, Assignment incoming, CancellationToken ct = default)
    {
        var existing = await GetAsync(id, ct);
        if (existing is null) return null;

        incoming.Id = id;
        incoming.CreatedAt = existing.CreatedAt;
        incoming.UpdatedAt = DateTime.UtcNow;

        await _ctx.Assignments.ReplaceOneAsync(a => a.Id == id, incoming, cancellationToken: ct);
        return incoming;
    }

    public async Task<bool> DeleteAsync(string id, CancellationToken ct = default)
    {
        var result = await _ctx.Assignments.DeleteOneAsync(a => a.Id == id, ct);
        return result.DeletedCount > 0;
    }

    public Task<List<Assignment>> ListOverlappingAsync(
        DateTime from,
        DateTime to,
        CancellationToken ct = default)
    {
        var filter = Builders<Assignment>.Filter.And(
            Builders<Assignment>.Filter.Lt(a => a.Start, to),
            Builders<Assignment>.Filter.Gt(a => a.End, from));
        return _ctx.Assignments.Find(filter).ToListAsync(ct);
    }

    public Task<List<Assignment>> ListByTaskIdsAsync(IEnumerable<string> taskIds, CancellationToken ct = default)
    {
        var list = taskIds.Distinct().ToList();
        if (list.Count == 0) return Task.FromResult(new List<Assignment>());
        var filter = Builders<Assignment>.Filter.In(a => a.TaskId, list);
        return _ctx.Assignments.Find(filter).ToListAsync(ct);
    }
}
