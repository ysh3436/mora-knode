using MongoDB.Bson;
using MongoDB.Driver;
using MoraKnode.Domain;

namespace MoraKnode.Infrastructure;

public class TaskCommentRepository
{
    private readonly MongoContext _ctx;

    public TaskCommentRepository(MongoContext ctx) => _ctx = ctx;

    public Task<TaskComment?> GetAsync(string id, CancellationToken ct = default) =>
        _ctx.TaskComments.Find(c => c.Id == id).FirstOrDefaultAsync(ct)!;

    /// <summary>Oldest first. The thread reads top-down, with the latest
    /// entry sitting at the bottom where the reply box also lives.</summary>
    public Task<List<TaskComment>> ListByTaskAsync(string taskId, CancellationToken ct = default) =>
        _ctx.TaskComments
            .Find(c => c.TaskId == taskId)
            .SortBy(c => c.CreatedAt)
            .ToListAsync(ct);

    public async Task<TaskComment> InsertAsync(TaskComment comment, CancellationToken ct = default)
    {
        var now = DateTime.UtcNow;
        comment.Id = ObjectId.GenerateNewId().ToString();
        comment.CreatedAt = now;
        comment.UpdatedAt = now;
        await _ctx.TaskComments.InsertOneAsync(comment, cancellationToken: ct);
        return comment;
    }

    public async Task<TaskComment?> ReplaceAsync(string id, TaskComment incoming, CancellationToken ct = default)
    {
        var existing = await GetAsync(id, ct);
        if (existing is null) return null;
        incoming.Id = id;
        incoming.TaskId = existing.TaskId;
        incoming.AuthorResourceId = existing.AuthorResourceId;
        incoming.CreatedAt = existing.CreatedAt;
        incoming.UpdatedAt = DateTime.UtcNow;
        await _ctx.TaskComments.ReplaceOneAsync(c => c.Id == id, incoming, cancellationToken: ct);
        return incoming;
    }

    public async Task<bool> DeleteAsync(string id, CancellationToken ct = default)
    {
        var res = await _ctx.TaskComments.DeleteOneAsync(c => c.Id == id, ct);
        return res.DeletedCount > 0;
    }
}
