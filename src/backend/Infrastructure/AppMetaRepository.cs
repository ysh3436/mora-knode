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

    /// <summary>
    /// Atomically allocates the next "MK-{N}" task number. Race-free even
    /// under concurrent creates because MongoDB serialises FindOneAndUpdate
    /// at the document level. Upserts the meta doc on first call so a
    /// fresh deployment doesn't need any seed step.
    /// </summary>
    public async Task<int> AllocateNextTaskNumberAsync(CancellationToken ct = default)
    {
        var filter = Builders<AppMeta>.Filter.Eq(m => m.Id, AppMeta.DefaultId);
        var update = Builders<AppMeta>.Update
            .Inc(m => m.NextTaskNumber, 1)
            .SetOnInsert(m => m.CreatedAt, DateTime.UtcNow)
            .Set(m => m.UpdatedAt, DateTime.UtcNow);
        var options = new FindOneAndUpdateOptions<AppMeta>
        {
            IsUpsert = true,
            // Return the document AFTER the increment so the new value is
            // what's been "allocated" — start at 1, not 0.
            ReturnDocument = ReturnDocument.After,
        };
        var doc = await _ctx.AppMeta.FindOneAndUpdateAsync(filter, update, options, ct);
        return doc.NextTaskNumber;
    }
}
