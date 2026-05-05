using MongoDB.Bson;
using MongoDB.Driver;
using MoraKnode.Domain;

namespace MoraKnode.Infrastructure;

public class AgentPlanRepository
{
    private readonly MongoContext _ctx;

    public AgentPlanRepository(MongoContext ctx) => _ctx = ctx;

    public Task<AgentPlan?> GetAsync(string id, CancellationToken ct = default) =>
        _ctx.AgentPlans.Find(p => p.Id == id).FirstOrDefaultAsync(ct)!;

    /// <summary>Filtered list. All filters are AND'd; null/empty filters are
    /// no-ops. Newest first (the review queue UI wants recent submissions
    /// at the top).</summary>
    public Task<List<AgentPlan>> ListAsync(
        string? taskId = null,
        string? submittedByResourceId = null,
        PlanStatus? status = null,
        CancellationToken ct = default)
    {
        var filter = Builders<AgentPlan>.Filter.Empty;
        if (!string.IsNullOrWhiteSpace(taskId))
            filter &= Builders<AgentPlan>.Filter.Eq(p => p.TaskId, taskId);
        if (!string.IsNullOrWhiteSpace(submittedByResourceId))
            filter &= Builders<AgentPlan>.Filter.Eq(p => p.SubmittedByResourceId, submittedByResourceId);
        if (status is not null)
            filter &= Builders<AgentPlan>.Filter.Eq(p => p.Status, status.Value);
        return _ctx.AgentPlans
            .Find(filter)
            .SortByDescending(p => p.CreatedAt)
            .ToListAsync(ct);
    }

    /// <summary>Most recent plan (any status) for a task. Surfaced in the
    /// work-queue response so the agent immediately sees whether their
    /// last plan was approved, rejected, or still pending.</summary>
    public Task<AgentPlan?> LatestForTaskAsync(string taskId, CancellationToken ct = default) =>
        _ctx.AgentPlans
            .Find(p => p.TaskId == taskId)
            .SortByDescending(p => p.CreatedAt)
            .FirstOrDefaultAsync(ct)!;

    public async Task<AgentPlan> InsertAsync(AgentPlan plan, CancellationToken ct = default)
    {
        var now = DateTime.UtcNow;
        plan.Id = ObjectId.GenerateNewId().ToString();
        plan.CreatedAt = now;
        plan.UpdatedAt = now;
        await _ctx.AgentPlans.InsertOneAsync(plan, cancellationToken: ct);
        return plan;
    }

    /// <summary>Replace the plan in place. Used by approve/reject to record
    /// reviewer fields. Caller is responsible for setting Status,
    /// ReviewerComment, ReviewedByResourceId, ReviewedAt before calling.</summary>
    public async Task<AgentPlan?> ReplaceAsync(string id, AgentPlan incoming, CancellationToken ct = default)
    {
        var existing = await GetAsync(id, ct);
        if (existing is null) return null;
        incoming.Id = id;
        incoming.CreatedAt = existing.CreatedAt;
        incoming.UpdatedAt = DateTime.UtcNow;
        await _ctx.AgentPlans.ReplaceOneAsync(p => p.Id == id, incoming, cancellationToken: ct);
        return incoming;
    }
}
