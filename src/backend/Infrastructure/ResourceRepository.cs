using MongoDB.Bson;
using MongoDB.Driver;
using MoraKnode.Domain;

namespace MoraKnode.Infrastructure;

public class ResourceRepository
{
    private readonly MongoContext _ctx;
    public ResourceRepository(MongoContext ctx) => _ctx = ctx;

    public Task<List<Resource>> ListAsync(CancellationToken ct = default) =>
        _ctx.Resources.Find(FilterDefinition<Resource>.Empty).ToListAsync(ct);

    public Task<Resource?> GetAsync(string id, CancellationToken ct = default) =>
        _ctx.Resources.Find(r => r.Id == id).FirstOrDefaultAsync(ct)!;

    public Task<Resource?> GetByNameAsync(string name, CancellationToken ct = default) =>
        _ctx.Resources.Find(r => r.Name == name).FirstOrDefaultAsync(ct)!;

    public async Task<Resource> CreateAsync(Resource resource, CancellationToken ct = default)
    {
        var now = DateTime.UtcNow;
        resource.Id = ObjectId.GenerateNewId().ToString();
        resource.CreatedAt = now;
        resource.UpdatedAt = now;
        await _ctx.Resources.InsertOneAsync(resource, cancellationToken: ct);
        return resource;
    }

    public async Task<Resource?> ReplaceAsync(string id, Resource incoming, CancellationToken ct = default)
    {
        var existing = await GetAsync(id, ct);
        if (existing is null) return null;

        incoming.Id = id;
        incoming.CreatedAt = existing.CreatedAt;
        incoming.UpdatedAt = DateTime.UtcNow;

        await _ctx.Resources.ReplaceOneAsync(r => r.Id == id, incoming, cancellationToken: ct);
        return incoming;
    }

    public async Task<bool> DeleteAsync(string id, CancellationToken ct = default)
    {
        var result = await _ctx.Resources.DeleteOneAsync(r => r.Id == id, ct);
        return result.DeletedCount > 0;
    }
}
