using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace MoraKnode.Domain;

public class Milestone
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = null!;

    [BsonRepresentation(BsonType.ObjectId)]
    public string ProjectId { get; set; } = null!;

    public string Title { get; set; } = string.Empty;
    public DateTime Date { get; set; }
    public MilestoneStatus Status { get; set; } = MilestoneStatus.Upcoming;

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    [BsonIgnore]
    public string? ChangeReason { get; set; }

    [BsonIgnore]
    public string? ChangedBy { get; set; }
}
