using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace MoraKnode.Domain;

public class Project
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = null!;

    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public ProjectStatus Status { get; set; } = ProjectStatus.Planning;

    // Matrix axis 2: who's on this project. Resources can sit in many
    // projects (different from the single Department membership). Empty
    // list = nobody explicitly added; assignments-on-tasks still work but
    // matrix grouping by project loses the resource.
    [BsonRepresentation(BsonType.ObjectId)]
    public List<string> MemberResourceIds { get; set; } = new();

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
