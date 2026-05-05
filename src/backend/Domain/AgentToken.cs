using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace MoraKnode.Domain;

/// <summary>
/// One issued credential for a Resource of Kind=Agent. Per ADR-004 the
/// raw token is shown to the user exactly once at issuance; only the
/// SHA-256 hash is persisted, so a leaked DB cannot be used to
/// impersonate the agent. Rotate = insert a new row with the same
/// ResourceId and RevokedAt set on the prior active row (so audit history
/// stays intact). v1 invariant: at most one row per ResourceId with
/// RevokedAt = null.
/// </summary>
public class AgentToken
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = null!;

    [BsonRepresentation(BsonType.ObjectId)]
    public string ResourceId { get; set; } = null!;

    /// <summary>SHA-256 hex (64 chars) of the raw token without the "mk_" prefix.</summary>
    public string TokenHashSha256 { get; set; } = string.Empty;

    /// <summary>Last 4 chars of the raw token, surfaced in UI as "…3a9f" for the user
    /// to recognize which key they pasted somewhere. Not enough to authenticate.</summary>
    public string LastFourChars { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; }

    /// <summary>Null = active. Setting this revokes the token; further auth attempts fail.</summary>
    public DateTime? RevokedAt { get; set; }

    /// <summary>Last time this token successfully authenticated. Telemetry only;
    /// not updated on every request (would be a hot write) — left for a follow-up cron.</summary>
    public DateTime? LastSeenAt { get; set; }
}
