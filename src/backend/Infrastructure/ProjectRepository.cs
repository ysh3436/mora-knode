using MongoDB.Bson;
using MongoDB.Driver;
using MoraKnode.Domain;

namespace MoraKnode.Infrastructure;

public class ProjectRepository
{
    private readonly MongoContext _ctx;
    private readonly ChangeLogRepository _changeLogs;

    public ProjectRepository(MongoContext ctx, ChangeLogRepository changeLogs)
    {
        _ctx = ctx;
        _changeLogs = changeLogs;
    }

    public Task<List<Project>> ListAsync(CancellationToken ct = default) =>
        _ctx.Projects.Find(FilterDefinition<Project>.Empty).ToListAsync(ct);

    public Task<Project?> GetAsync(string id, CancellationToken ct = default) =>
        _ctx.Projects.Find(p => p.Id == id).FirstOrDefaultAsync(ct)!;

    public async Task<Project> CreateAsync(Project project, CancellationToken ct = default)
    {
        var now = DateTime.UtcNow;
        project.Id = ObjectId.GenerateNewId().ToString();
        project.CreatedAt = now;
        project.UpdatedAt = now;
        await _ctx.Projects.InsertOneAsync(project, cancellationToken: ct);
        return project;
    }

    public async Task<Project?> ReplaceAsync(string id, Project incoming, CancellationToken ct = default)
    {
        var existing = await GetAsync(id, ct);
        if (existing is null) return null;

        var reason = incoming.ChangeReason;
        var changedBy = incoming.ChangedBy;

        incoming.Id = id;
        incoming.CreatedAt = existing.CreatedAt;
        incoming.UpdatedAt = DateTime.UtcNow;

        // Diff the human-meaningful fields. We skip MemberResourceIds for
        // now — those have a dedicated POST/DELETE pair on the members
        // sub-route which would be the better place to log membership
        // movements (Phase 2).
        var logs = new List<ScheduleChangeLog>();
        if (existing.Name != incoming.Name)
            logs.Add(BuildLog(id, "Name", existing.Name, incoming.Name, reason, changedBy));
        if ((existing.Description ?? "") != (incoming.Description ?? ""))
            logs.Add(BuildLog(id, "Description", existing.Description, incoming.Description, reason, changedBy));
        if (existing.Status != incoming.Status)
            logs.Add(BuildLog(id, "Status", existing.Status.ToString(), incoming.Status.ToString(), reason, changedBy));

        await _ctx.Projects.ReplaceOneAsync(p => p.Id == id, incoming, cancellationToken: ct);
        await _changeLogs.InsertManyAsync(logs, ct);
        return incoming;
    }

    public async Task<bool> DeleteAsync(string id, CancellationToken ct = default)
    {
        var result = await _ctx.Projects.DeleteOneAsync(p => p.Id == id, ct);
        return result.DeletedCount > 0;
    }

    private static ScheduleChangeLog BuildLog(
        string projectId, string field, string? before, string? after, string? reason, string? changedBy) =>
        new()
        {
            EntityType = ChangeEntityType.Project,
            EntityId = projectId,
            Field = field,
            BeforeValue = before,
            AfterValue = after,
            Reason = reason,
            ChangedBy = changedBy,
        };
}
