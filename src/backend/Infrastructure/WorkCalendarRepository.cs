using MongoDB.Driver;
using MoraKnode.Domain;

namespace MoraKnode.Infrastructure;

public class WorkCalendarRepository
{
    private readonly MongoContext _ctx;
    public WorkCalendarRepository(MongoContext ctx) => _ctx = ctx;

    /// <summary>
    /// Returns the single org-level WorkCalendar, or the 24/7 fallback when no
    /// document has been written yet. Callers can rely on getting a non-null
    /// instance — they only need to branch on whether to surface the "not yet
    /// configured" UI state.
    /// </summary>
    public async Task<(WorkCalendar Calendar, bool IsFallback)> GetOrFallbackAsync(CancellationToken ct = default)
    {
        var doc = await _ctx.WorkCalendars.Find(c => c.Id == WorkCalendar.DefaultId).FirstOrDefaultAsync(ct);
        return doc is null ? (WorkCalendar.Fallback247(), true) : (doc, false);
    }

    public Task<WorkCalendar?> GetAsync(CancellationToken ct = default) =>
        _ctx.WorkCalendars.Find(c => c.Id == WorkCalendar.DefaultId).FirstOrDefaultAsync(ct)!;

    public async Task<WorkCalendar> UpsertAsync(WorkCalendar incoming, CancellationToken ct = default)
    {
        var now = DateTime.UtcNow;
        incoming.Id = WorkCalendar.DefaultId;
        incoming.UpdatedAt = now;

        var existing = await GetAsync(ct);
        if (existing is null)
        {
            incoming.CreatedAt = now;
            await _ctx.WorkCalendars.InsertOneAsync(incoming, cancellationToken: ct);
        }
        else
        {
            incoming.CreatedAt = existing.CreatedAt;
            await _ctx.WorkCalendars.ReplaceOneAsync(c => c.Id == WorkCalendar.DefaultId, incoming, cancellationToken: ct);
        }
        return incoming;
    }
}
