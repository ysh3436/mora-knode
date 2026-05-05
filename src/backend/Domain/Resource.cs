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

    // ADR-004: distinguish human user from agent identity. Default Human so
    // documents written before this field existed deserialize as humans.
    [BsonDefaultValue((int)ResourceKind.Human)]
    public ResourceKind Kind { get; set; } = ResourceKind.Human;

    // ADR-004 §3 RBAC preset. Drives both UI affordance gating and view-scope
    // filtering on the backend (see seed-scenarios.md §3.4).
    [BsonDefaultValue((int)RbacPreset.Human)]
    public RbacPreset Rbac { get; set; } = RbacPreset.Human;

    // Free-text description for agent identities (model, tooling, prompt set).
    // Null for humans.
    public string? AgentDescription { get; set; }

    // Matrix axis 1: which functional org unit this resource reports into.
    // Null = unassigned / floater (legitimate for contractors, agents not
    // tied to a specific team, etc).
    [BsonRepresentation(BsonType.ObjectId)]
    public string? DepartmentId { get; set; }

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
