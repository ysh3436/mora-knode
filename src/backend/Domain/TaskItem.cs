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
    public TaskStatus Status { get; set; } = TaskStatus.NotStarted;

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
