using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace MoraKnode.Domain;

public class TaskItem
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = null!;

    [BsonRepresentation(BsonType.ObjectId)]
    public string ProjectId { get; set; } = null!;

    [BsonRepresentation(BsonType.ObjectId)]
    public string? ParentTaskId { get; set; }

    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }

    // Persisted as the enum name (NotStarted / InReview / ...) instead of an
    // integer so the sparse numeric values in TaskStatus can be reordered
    // freely without breaking stored data.
    [BsonRepresentation(BsonType.String)]
    public TaskStatus Status { get; set; } = TaskStatus.NotStarted;

    // Triage signal. Default Unset for tasks that pre-date the field or
    // simply weren't categorized. The property initializer is the default
    // — when BSON documents are missing this field, the deserializer
    // simply leaves the property at the constructor-assigned value
    // (BsonDefaultValue is intentionally not used because it bypasses the
    // BsonRepresentation conversion and would inject a raw string).
    [BsonRepresentation(BsonType.String)]
    public TaskPriority Priority { get; set; } = TaskPriority.Unset;

    public Timeline OriginTimeline { get; set; } = new();
    public Timeline CurrentTimeline { get; set; } = new();
    public Timeline RealTimeline { get; set; } = new();

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Transient fields: accepted from client on update requests to annotate the
    // schedule change log. Not persisted on the task document itself.
    [BsonIgnore]
    public string? ChangeReason { get; set; }

    [BsonIgnore]
    public string? ChangedBy { get; set; }
}
