using MoraKnode.Infrastructure;

namespace MoraKnode.Endpoints;

public static class HolidayEndpoints
{
    public static IEndpointRouteBuilder MapHolidayEndpoints(this IEndpointRouteBuilder app)
    {
        // Aggregated holiday read for gantt + calendar. Half-open range
        // [from, to) keyed by UTC midnight (matches HolidayCacheEntry.Date).
        // Joins source metadata so the client can colour by source.
        app.MapGet("/api/holidays", async (
            DateTime from,
            DateTime to,
            HolidaySourceRepository repo,
            CancellationToken ct) =>
        {
            var entries = await repo.CachedHolidaysAsync(from.ToUniversalTime(), to.ToUniversalTime(), ct);
            var sources = (await repo.ListAsync(ct)).ToDictionary(s => s.Id);
            // Drop entries whose source was deleted between read + join
            // (defensive — DeleteAsync already cascades).
            var result = entries
                .Where(e => sources.ContainsKey(e.SourceId))
                .Where(e => sources[e.SourceId].Enabled)
                .Select(e =>
                {
                    var s = sources[e.SourceId];
                    return new
                    {
                        date = e.Date,
                        name = e.Name,
                        sourceId = e.SourceId,
                        sourceName = s.Name,
                        colorHex = s.ColorHex,
                    };
                });
            return Results.Ok(result);
        }).WithTags("Holidays");

        return app;
    }
}
