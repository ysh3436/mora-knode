using MongoDB.Bson;
using MongoDB.Driver;
using MoraKnode.Domain;

namespace MoraKnode.Infrastructure;

public class TaskRepository
{
    private readonly MongoContext _ctx;
    public TaskRepository(MongoContext ctx) => _ctx = ctx;

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

        incoming.Id = id;
        incoming.ProjectId = existing.ProjectId;
        incoming.CreatedAt = existing.CreatedAt;
        incoming.UpdatedAt = DateTime.UtcNow;

        // L1 Origin is write-once: never overwrite once set.
        if (!existing.OriginTimeline.IsEmpty)
        {
            incoming.OriginTimeline = existing.OriginTimeline;
        }

        await _ctx.Tasks.ReplaceOneAsync(t => t.Id == id, incoming, cancellationToken: ct);
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
}
