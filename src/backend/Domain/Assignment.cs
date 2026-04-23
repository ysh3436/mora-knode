using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace MoraKnode.Domain;

public class Assignment
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = null!;

    [BsonRepresentation(BsonType.ObjectId)]
    public string ResourceId { get; set; } = null!;

    [BsonRepresentation(BsonType.ObjectId)]
    public string TaskId { get; set; } = null!;

    // Share of the resource's capacity this assignment consumes. 50 = 50%.
    public int AllocationPercent { get; set; }

    public DateTime Start { get; set; }
    public DateTime End { get; set; }

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
