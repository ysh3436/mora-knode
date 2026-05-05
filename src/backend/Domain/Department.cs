using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace MoraKnode.Domain;

/// <summary>
/// Functional org unit. One Resource sits in at most one Department
/// (Resource.DepartmentId), forming the "where do you report" axis of the
/// matrix. The "what do you work on" axis is Project.MemberResourceIds.
/// Two axes ⊥ → matrix view = department × project.
///
/// Tree shape: single parent (DAG / multi-parent deferred to v1.1). Cycle
/// prevention enforced application-side in the repository on update —
/// Mongo can't express "no cycles in self-referential graph" cheaply.
/// </summary>
public class Department
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = null!;

    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }

    [BsonRepresentation(BsonType.ObjectId)]
    public string? ParentDepartmentId { get; set; }

    /// <summary>Optional department head. Used for routing approvals
    /// later; left nullable so a freshly created department doesn't need
    /// a lead picked.</summary>
    [BsonRepresentation(BsonType.ObjectId)]
    public string? LeadResourceId { get; set; }

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
