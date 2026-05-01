using MongoDB.Driver;
using MoraKnode.Domain;

namespace MoraKnode.Infrastructure;

public class AppMetaRepository
{
    private readonly MongoContext _ctx;
    public AppMetaRepository(MongoContext ctx) => _ctx = ctx;

    /// <summary>
    /// Returns the single meta doc, or a fresh in-memory default when none
    /// has been written yet. Callers can rely on getting a non-null instance.
    /// </summary>
    public async Task<AppMeta> GetAsync(CancellationToken ct = default)
    {
        var doc = await _ctx.AppMeta.Find(m => m.Id == AppMeta.DefaultId).FirstOrDefaultAsync(ct);
        return doc ?? new AppMeta();
    }

    public async Task<AppMeta> UpsertAsync(AppMeta incoming, CancellationToken ct = default)
    {
        var now = DateTime.UtcNow;
        incoming.Id = AppMeta.DefaultId;
        incoming.UpdatedAt = now;
        var existing = await _ctx.AppMeta.Find(m => m.Id == AppMeta.DefaultId).FirstOrDefaultAsync(ct);
        if (existing is null)
        {
            incoming.CreatedAt = now;
            await _ctx.AppMeta.InsertOneAsync(incoming, cancellationToken: ct);
        }
        else
        {
            incoming.CreatedAt = existing.CreatedAt;
            await _ctx.AppMeta.ReplaceOneAsync(m => m.Id == AppMeta.DefaultId, incoming, cancellationToken: ct);
        }
        return incoming;
    }
}
