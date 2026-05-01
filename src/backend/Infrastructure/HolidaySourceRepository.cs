using MongoDB.Driver;
using MoraKnode.Domain;

namespace MoraKnode.Infrastructure;

public class HolidaySourceRepository
{
    private readonly MongoContext _ctx;
    public HolidaySourceRepository(MongoContext ctx) => _ctx = ctx;

    public Task<List<HolidaySource>> ListAsync(CancellationToken ct = default) =>
        _ctx.HolidaySources.Find(FilterDefinition<HolidaySource>.Empty).ToListAsync(ct);

    public Task<HolidaySource?> GetAsync(string id, CancellationToken ct = default) =>
        _ctx.HolidaySources.Find(s => s.Id == id).FirstOrDefaultAsync(ct)!;

    public async Task<HolidaySource> CreateAsync(HolidaySource src, CancellationToken ct = default)
    {
        var now = DateTime.UtcNow;
        src.Id = null!; // let Mongo generate
        src.CreatedAt = now;
        src.UpdatedAt = now;
        await _ctx.HolidaySources.InsertOneAsync(src, cancellationToken: ct);
        return src;
    }

    /// <summary>
    /// Patch-style update — only Name / Url / ColorHex / Enabled are
    /// updatable. Cache + LastFetchedAt are managed by the fetcher.
    /// </summary>
    public async Task<HolidaySource?> UpdateAsync(string id, HolidaySource patch, CancellationToken ct = default)
    {
        var existing = await GetAsync(id, ct);
        if (existing is null) return null;
        if (!string.IsNullOrWhiteSpace(patch.Name)) existing.Name = patch.Name;
        if (!string.IsNullOrWhiteSpace(patch.Url)) existing.Url = patch.Url;
        existing.ColorHex = patch.ColorHex;
        existing.Enabled = patch.Enabled;
        existing.UpdatedAt = DateTime.UtcNow;
        await _ctx.HolidaySources.ReplaceOneAsync(s => s.Id == id, existing, cancellationToken: ct);
        return existing;
    }

    public async Task DeleteAsync(string id, CancellationToken ct = default)
    {
        await _ctx.HolidaySources.DeleteOneAsync(s => s.Id == id, ct);
        // Cascade — drop any cached events tied to the removed source so the
        // /api/holidays response stays clean without a separate sweep.
        await _ctx.HolidayCache.DeleteManyAsync(c => c.SourceId == id, ct);
    }

    public async Task UpdateFetchStatusAsync(string id, DateTime fetchedAt, string? error, CancellationToken ct = default)
    {
        var update = Builders<HolidaySource>.Update
            .Set(s => s.LastFetchedAt, fetchedAt)
            .Set(s => s.LastError, error)
            .Set(s => s.UpdatedAt, DateTime.UtcNow);
        await _ctx.HolidaySources.UpdateOneAsync(s => s.Id == id, update, cancellationToken: ct);
    }

    /// <summary>
    /// Replaces the entire cached event set for a source — atomic-ish via
    /// delete-then-insert. Safe because reads are eventually-consistent;
    /// during the gap the source contributes zero events to /api/holidays.
    /// </summary>
    public async Task ReplaceCacheAsync(string sourceId, IReadOnlyList<HolidayCacheEntry> entries, CancellationToken ct = default)
    {
        await _ctx.HolidayCache.DeleteManyAsync(c => c.SourceId == sourceId, ct);
        if (entries.Count == 0) return;
        foreach (var e in entries)
        {
            e.Id = null!;
            e.SourceId = sourceId;
        }
        await _ctx.HolidayCache.InsertManyAsync(entries, cancellationToken: ct);
    }

    public Task<List<HolidayCacheEntry>> CachedHolidaysAsync(DateTime from, DateTime to, CancellationToken ct = default) =>
        _ctx.HolidayCache.Find(c => c.Date >= from && c.Date < to).ToListAsync(ct);
}
