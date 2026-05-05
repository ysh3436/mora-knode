using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace MoraKnode.Domain;

/// <summary>
/// A note on a task. The thread is intended to host review rounds — UI
/// feedback with screenshots, bug reproductions, QA notes — so the body is
/// markdown and image references go inline as `![](url)` pointing at the
/// /api/attachments endpoint.
///
/// Hard delete: there is no soft-delete column. The audit story is the
/// ScheduleChangeLog the repository writes when a comment is added, edited,
/// or removed. v1 favours simplicity — if dogfooding shows we need to recover
/// deleted comments, we add a soft-delete flag later.
/// </summary>
public class TaskComment
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = null!;

    [BsonRepresentation(BsonType.ObjectId)]
    public string TaskId { get; set; } = null!;

    /// <summary>The Resource that wrote this. Could be a human (review,
    /// QA note) or an agent (work-result summary, blocker report).</summary>
    [BsonRepresentation(BsonType.ObjectId)]
    public string AuthorResourceId { get; set; } = null!;

    /// <summary>Markdown. Inline image refs use the /api/attachments URL
    /// shape returned by the attachment-upload endpoint.</summary>
    public string Body { get; set; } = string.Empty;

    /// <summary>Optional tag — null for a generic note, "review" for a
    /// review round, "bug" for a bug report, "qa" for a QA pass. Not
    /// validated against an enum yet (lean v1) so dogfooding can surface
    /// the kinds we actually need before we lock the vocabulary.</summary>
    public string? Kind { get; set; }

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
