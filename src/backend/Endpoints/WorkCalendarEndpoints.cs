using MoraKnode.Domain;
using MoraKnode.Infrastructure;

namespace MoraKnode.Endpoints;

public static class WorkCalendarEndpoints
{
    public static IEndpointRouteBuilder MapWorkCalendarEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/work-calendar").WithTags("WorkCalendar");

        // Returns the configured calendar, or the 24/7 fallback with isFallback=true
        // so the client can surface "not yet configured" UX.
        group.MapGet("/", async (WorkCalendarRepository repo, CancellationToken ct) =>
        {
            var (cal, isFallback) = await repo.GetOrFallbackAsync(ct);
            return Results.Ok(new
            {
                isFallback,
                calendar = cal
            });
        });

        group.MapPut("/", async (WorkCalendar incoming, WorkCalendarRepository repo, CancellationToken ct) =>
        {
            if (incoming.DailyEndMinutes <= incoming.DailyStartMinutes)
                return Results.BadRequest(new { error = "DailyEnd must be after DailyStart" });
            if (incoming.DailyStartMinutes < 0 || incoming.DailyEndMinutes > 24 * 60)
                return Results.BadRequest(new { error = "Daily window must fall within [0, 24h]" });

            var saved = await repo.UpsertAsync(incoming, ct);
            return Results.Ok(saved);
        });

        return app;
    }
}
