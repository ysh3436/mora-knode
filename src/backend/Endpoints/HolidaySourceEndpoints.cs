using MoraKnode.Domain;
using MoraKnode.Infrastructure;

namespace MoraKnode.Endpoints;

public static class HolidaySourceEndpoints
{
    /// <summary>
    /// Locale → default holiday calendar preset. The "auto-seed" endpoint
    /// uses this map to insert one subscription on the first run so users
    /// see their country's public holidays without having to look up an
    /// .ics URL. Add more entries as we identify trustworthy public feeds.
    /// </summary>
    private static readonly Dictionary<string, (string Name, string Url)> _localePresets = new()
    {
        ["ko"] = (
            "한국 공휴일 (Google)",
            "https://calendar.google.com/calendar/ical/ko.south_korea%23holiday%40group.v.calendar.google.com/public/basic.ics"
        ),
        ["en"] = (
            "US Holidays (Google)",
            "https://calendar.google.com/calendar/ical/en.usa%23holiday%40group.v.calendar.google.com/public/basic.ics"
        ),
    };

    public static IEndpointRouteBuilder MapHolidaySourceEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/holiday-sources").WithTags("HolidaySources");

        group.MapGet("/", async (HolidaySourceRepository repo, CancellationToken ct) =>
        {
            var sources = await repo.ListAsync(ct);
            return Results.Ok(sources);
        });

        group.MapPost("/", async (HolidaySource src, HolidaySourceRepository repo, IcsFetcherService fetcher, CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(src.Url))
                return Results.BadRequest(new { error = "Url is required" });
            if (string.IsNullOrWhiteSpace(src.Name)) src.Name = src.Url;

            var created = await repo.CreateAsync(src, ct);
            // Trigger an initial fetch in the background so the user sees data
            // without waiting for the next manual refresh. Errors land on
            // LastError and surface in the settings UI.
            _ = Task.Run(() => fetcher.FetchOneAsync(created), CancellationToken.None);
            return Results.Ok(created);
        });

        group.MapPatch("/{id}", async (string id, HolidaySource patch, HolidaySourceRepository repo, IcsFetcherService fetcher, CancellationToken ct) =>
        {
            var existing = await repo.GetAsync(id, ct);
            if (existing is null) return Results.NotFound();
            var urlChanged = !string.IsNullOrWhiteSpace(patch.Url) &&
                             !string.Equals(existing.Url, patch.Url, StringComparison.Ordinal);
            var updated = await repo.UpdateAsync(id, patch, ct);
            if (updated is null) return Results.NotFound();
            // URL 변경 시 이전 캐시는 무의미해지므로 백그라운드로 즉시 재fetch.
            // 사용자가 "지금 갱신" 을 누를 필요 없이 다음 paint 에서 새 데이터 반영.
            if (urlChanged)
            {
                _ = Task.Run(() => fetcher.FetchOneAsync(updated), CancellationToken.None);
            }
            return Results.Ok(updated);
        });

        group.MapDelete("/{id}", async (string id, HolidaySourceRepository repo, CancellationToken ct) =>
        {
            await repo.DeleteAsync(id, ct);
            return Results.NoContent();
        });

        // On-demand refresh — used by the "지금 갱신" button in settings.
        group.MapPost("/{id}/refresh", async (string id, HolidaySourceRepository repo, IcsFetcherService fetcher, CancellationToken ct) =>
        {
            var src = await repo.GetAsync(id, ct);
            if (src is null) return Results.NotFound();
            try
            {
                await fetcher.FetchOneAsync(src, ct);
                var updated = await repo.GetAsync(id, ct);
                return Results.Ok(updated);
            }
            catch (Exception ex)
            {
                return Results.Problem(ex.Message);
            }
        });

        // First-run auto-seed: insert one default subscription matching the
        // user's locale so they don't start out staring at an empty list.
        // Idempotent — gated by the AppMeta.HolidaysAutoSeeded marker so a
        // user who deletes the auto-added source doesn't see it reappear.
        group.MapPost("/auto-seed", async (
            string? locale,
            HolidaySourceRepository repo,
            AppMetaRepository metaRepo,
            IcsFetcherService fetcher,
            CancellationToken ct) =>
        {
            var meta = await metaRepo.GetAsync(ct);
            if (meta.HolidaysAutoSeeded)
            {
                return Results.Ok(new { seeded = false, source = (HolidaySource?)null });
            }
            var key = (locale ?? "ko").ToLowerInvariant().Split('-')[0];
            if (!_localePresets.TryGetValue(key, out var preset))
            {
                // No preset for this locale — still mark as seeded so we
                // don't keep retrying on every page load.
                meta.HolidaysAutoSeeded = true;
                await metaRepo.UpsertAsync(meta, ct);
                return Results.Ok(new { seeded = false, source = (HolidaySource?)null });
            }
            var src = await repo.CreateAsync(new HolidaySource
            {
                Name = preset.Name,
                Url = preset.Url,
                Enabled = true,
                Kind = HolidayKind.Holiday,
            }, ct);
            meta.HolidaysAutoSeeded = true;
            await metaRepo.UpsertAsync(meta, ct);
            // Background fetch — don't block the response on the network
            // round-trip. Errors land on src.LastError.
            _ = Task.Run(() => fetcher.FetchOneAsync(src), CancellationToken.None);
            return Results.Ok(new { seeded = true, source = src });
        });

        return app;
    }
}
