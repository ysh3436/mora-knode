using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace MoraKnode.Domain;

/// <summary>
/// ADR-002: every agent-driven plan goes through a human (or human-class)
/// approval gate before downstream work happens. One AgentPlan = one
/// proposal for how to attack a Task. Hybrid shape (Steps + free-text Notes)
/// because rigid step lists feel forced for some kinds of work but a single
/// blob loses the structured-approval feel.
///
/// PendingReview → Approved / Rejected is terminal. A revision = submit a
/// new AgentPlan against the same TaskId; the older row stays in place for
/// audit. v1 has no soft-edit on PendingReview either — to revise an
/// in-flight plan, the agent submits a new one (and the previous remains
/// visible in the task's plan history).
/// </summary>
public class AgentPlan
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = null!;

    [BsonRepresentation(BsonType.ObjectId)]
    public string TaskId { get; set; } = null!;

    /// <summary>The Resource that submitted this plan — typically an agent,
    /// but a human can also submit (so the same gate works for human-authored
    /// proposals when policy demands review).</summary>
    [BsonRepresentation(BsonType.ObjectId)]
    public string SubmittedByResourceId { get; set; } = null!;

    [BsonRepresentation(BsonType.String)]
    public PlanStatus Status { get; set; } = PlanStatus.PendingReview;

    public string Title { get; set; } = string.Empty;
    public int? EstimateMinutes { get; set; }

    public List<PlanStep> Steps { get; set; } = new();
    public string? Notes { get; set; }

    /// <summary>Reviewer's note on approve or (especially) reject. Required
    /// on reject so the agent knows what to fix when re-submitting.</summary>
    public string? ReviewerComment { get; set; }

    [BsonRepresentation(BsonType.ObjectId)]
    public string? ReviewedByResourceId { get; set; }

    public DateTime? ReviewedAt { get; set; }

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public class PlanStep
{
    public string Description { get; set; } = string.Empty;
    public int? EstimateMinutes { get; set; }
}

public enum PlanStatus
{
    PendingReview,
    Approved,
    Rejected
}
