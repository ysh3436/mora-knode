using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace MoraKnode.Domain;

public class Resource
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = null!;

    public string Name { get; set; } = string.Empty;
    public string? Role { get; set; }

    // Daily capacity as a percent of a full-time slot. 100 = full-time, 50 = half-time.
    public int CapacityPercent { get; set; } = 100;

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
