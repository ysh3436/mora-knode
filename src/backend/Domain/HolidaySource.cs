using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace MoraKnode.Domain;

/// <summary>
/// User-configured iCalendar (.ics) subscription that supplies holiday /
/// non-working-day data to the gantt + calendar views. Multiple sources can
/// be active at once (e.g. legal Korean holidays, company workshops, target
/// country holidays). The fetched events are cached in
/// <see cref="HolidayCacheEntry"/> so the read path doesn't hit the network.
/// </summary>
public class HolidaySource
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = null!;

    /// <summary>Display name shown in settings + tooltip prefix.</summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>iCalendar URL. Public .ics, often Google Calendar export.</summary>
    public string Url { get; set; } = string.Empty;

    /// <summary>Optional accent color (#RRGGBB). null falls back to red.</summary>
    public string? ColorHex { get; set; }

    public bool Enabled { get; set; } = true;

    public DateTime? LastFetchedAt { get; set; }
    /// <summary>Last fetch error, null when the most recent fetch succeeded.</summary>
    public string? LastError { get; set; }

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

/// <summary>
/// One cached holiday event derived from a parsed .ics. Cleared + replaced on
/// every successful fetch of the parent source. Keyed by SourceId so deletes
/// of a source can cascade.
/// </summary>
public class HolidayCacheEntry
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = null!;

    [BsonRepresentation(BsonType.ObjectId)]
    public string SourceId { get; set; } = null!;

    /// <summary>UTC midnight of the day the event falls on.</summary>
    public DateTime Date { get; set; }

    public string Name { get; set; } = string.Empty;
}
