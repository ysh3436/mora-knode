using MongoDB.Bson;
using MongoDB.Driver;
using MoraKnode.Domain;

namespace MoraKnode.Infrastructure;

public class ProjectRepository
{
    private readonly MongoContext _ctx;
    public ProjectRepository(MongoContext ctx) => _ctx = ctx;

    public Task<List<Project>> ListAsync(CancellationToken ct = default) =>
        _ctx.Projects.Find(FilterDefinition<Project>.Empty).ToListAsync(ct);

    public Task<Project?> GetAsync(string id, CancellationToken ct = default) =>
        _ctx.Projects.Find(p => p.Id == id).FirstOrDefaultAsync(ct)!;

    public async Task<Project> CreateAsync(Project project, CancellationToken ct = default)
    {
        var now = DateTime.UtcNow;
        project.Id = ObjectId.GenerateNewId().ToString();
        project.CreatedAt = now;
        project.UpdatedAt = now;
        await _ctx.Projects.InsertOneAsync(project, cancellationToken: ct);
        return project;
    }

    public async Task<Project?> ReplaceAsync(string id, Project incoming, CancellationToken ct = default)
    {
        var existing = await GetAsync(id, ct);
        if (existing is null) return null;

        incoming.Id = id;
        incoming.CreatedAt = existing.CreatedAt;
        incoming.UpdatedAt = DateTime.UtcNow;

        await _ctx.Projects.ReplaceOneAsync(p => p.Id == id, incoming, cancellationToken: ct);
        return incoming;
    }

    public async Task<bool> DeleteAsync(string id, CancellationToken ct = default)
    {
        var result = await _ctx.Projects.DeleteOneAsync(p => p.Id == id, ct);
        return result.DeletedCount > 0;
    }
}
