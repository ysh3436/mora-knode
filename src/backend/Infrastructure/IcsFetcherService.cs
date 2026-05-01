using MoraKnode.Domain;

namespace MoraKnode.Infrastructure;

/// <summary>
/// Fetches a <see cref="HolidaySource"/>'s .ics URL, parses it, and replaces
/// the source's cache entries. Errors get recorded on the source itself
/// (LastError) so the settings UI can surface them — never throws past the
/// per-source boundary in <see cref="FetchAllEnabledAsync"/>.
/// </summary>
public class IcsFetcherService
{
    private readonly HolidaySourceRepository _repo;
    private readonly HttpClient _http;
    private readonly ILogger<IcsFetcherService> _log;

    public IcsFetcherService(HolidaySourceRepository repo, IHttpClientFactory httpFactory, ILogger<IcsFetcherService> log)
    {
        _repo = repo;
        _http = httpFactory.CreateClient("ics");
        _http.Timeout = TimeSpan.FromSeconds(15);
        _log = log;
    }

    public async Task FetchOneAsync(HolidaySource source, CancellationToken ct = default)
    {
        try
        {
            var ics = await _http.GetStringAsync(source.Url, ct);
            var entries = IcsParser.Parse(ics)
                .Select(e => new HolidayCacheEntry { Date = e.Date, Name = e.Summary })
                .ToList();
            await _repo.ReplaceCacheAsync(source.Id, entries, ct);
            await _repo.UpdateFetchStatusAsync(source.Id, DateTime.UtcNow, null, ct);
            _log.LogInformation("Fetched {Count} events from holiday source {Id} ({Name})",
                entries.Count, source.Id, source.Name);
        }
        catch (Exception ex)
        {
            _log.LogWarning(ex, "Failed to fetch holiday source {Id} ({Name})", source.Id, source.Name);
            await _repo.UpdateFetchStatusAsync(source.Id, DateTime.UtcNow, ex.Message, ct);
            throw;
        }
    }

    /// <summary>
    /// Best-effort fetch of every enabled source. Per-source errors are
    /// recorded but do not abort the loop; callers (manual refresh-all,
    /// future cron) get partial-success behaviour.
    /// </summary>
    public async Task FetchAllEnabledAsync(CancellationToken ct = default)
    {
        var sources = await _repo.ListAsync(ct);
        foreach (var s in sources.Where(x => x.Enabled))
        {
            try { await FetchOneAsync(s, ct); }
            catch { /* per-source state already recorded */ }
        }
    }
}
