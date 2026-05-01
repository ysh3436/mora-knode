using MongoDB.Bson.Serialization.Attributes;

namespace MoraKnode.Domain;

/// <summary>
/// Single org-level metadata document for "did we already do X?" flags.
/// Lives in its own collection so each backend module can flip a flag
/// without colliding with another's payload. Currently tracks just the
/// holiday auto-seed bit; add fields here when more "do once on first
/// run" behaviours appear.
/// </summary>
public class AppMeta
{
    public const string DefaultId = "default";

    [BsonId]
    public string Id { get; set; } = DefaultId;

    /// <summary>
    /// True after the first time the holiday auto-seed endpoint inserted
    /// a default subscription. Gates re-seeding so a user who deleted the
    /// auto-added source doesn't see it reappear on the next page load.
    /// </summary>
    public bool HolidaysAutoSeeded { get; set; }

    /// <summary>
    /// Monotonic counter for the global "MK-{N}" task identifier. Each
    /// task creation atomically increments this and stamps the
    /// pre-increment value onto TaskItem.Number. Starts at 0 → first
    /// allocated number is 1.
    /// </summary>
    public int NextTaskNumber { get; set; }

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
