using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace MoraKnode.Domain;

public class ScheduleChangeLog
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = null!;

    public ChangeEntityType EntityType { get; set; }

    [BsonRepresentation(BsonType.ObjectId)]
    public string EntityId { get; set; } = null!;

    public string Field { get; set; } = string.Empty;
    public string? BeforeValue { get; set; }
    public string? AfterValue { get; set; }
    public string? Reason { get; set; }
    public string? ChangedBy { get; set; }

    public DateTime ChangedAt { get; set; }
}
