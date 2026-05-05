using Microsoft.Extensions.Options;
using MongoDB.Driver;
using MoraKnode.Domain;

namespace MoraKnode.Infrastructure;

public class MongoContext
{
    private readonly IMongoDatabase _db;

    public MongoContext(IOptions<MongoOptions> options)
    {
        var settings = MongoClientSettings.FromConnectionString(options.Value.ConnectionString);
        var client = new MongoClient(settings);
        _db = client.GetDatabase(options.Value.Database);
    }

    public IMongoCollection<Project> Projects => _db.GetCollection<Project>("projects");
    public IMongoCollection<TaskItem> Tasks => _db.GetCollection<TaskItem>("tasks");
    public IMongoCollection<Milestone> Milestones => _db.GetCollection<Milestone>("milestones");
    public IMongoCollection<Resource> Resources => _db.GetCollection<Resource>("resources");
    public IMongoCollection<Assignment> Assignments => _db.GetCollection<Assignment>("assignments");
    public IMongoCollection<ScheduleChangeLog> ChangeLogs => _db.GetCollection<ScheduleChangeLog>("change_logs");
    public IMongoCollection<WorkCalendar> WorkCalendars => _db.GetCollection<WorkCalendar>("work_calendar");
    public IMongoCollection<HolidaySource> HolidaySources => _db.GetCollection<HolidaySource>("holiday_sources");
    public IMongoCollection<HolidayCacheEntry> HolidayCache => _db.GetCollection<HolidayCacheEntry>("holiday_cache");
    public IMongoCollection<AppMeta> AppMeta => _db.GetCollection<AppMeta>("app_meta");
    public IMongoCollection<AgentToken> AgentTokens => _db.GetCollection<AgentToken>("agent_tokens");
    public IMongoCollection<Department> Departments => _db.GetCollection<Department>("departments");
    public IMongoCollection<AgentPlan> AgentPlans => _db.GetCollection<AgentPlan>("agent_plans");
    public IMongoCollection<TaskComment> TaskComments => _db.GetCollection<TaskComment>("task_comments");

    public async Task EnsureIndexesAsync(CancellationToken ct = default)
    {
        await HolidayCache.Indexes.CreateOneAsync(
            new CreateIndexModel<HolidayCacheEntry>(Builders<HolidayCacheEntry>.IndexKeys.Ascending(x => x.Date)),
            cancellationToken: ct);
        await HolidayCache.Indexes.CreateOneAsync(
            new CreateIndexModel<HolidayCacheEntry>(Builders<HolidayCacheEntry>.IndexKeys.Ascending(x => x.SourceId)),
            cancellationToken: ct);

        await Tasks.Indexes.CreateOneAsync(
            new CreateIndexModel<TaskItem>(Builders<TaskItem>.IndexKeys.Ascending(x => x.ProjectId)),
            cancellationToken: ct);

        await Milestones.Indexes.CreateOneAsync(
            new CreateIndexModel<Milestone>(Builders<Milestone>.IndexKeys.Ascending(x => x.ProjectId)),
            cancellationToken: ct);

        await Assignments.Indexes.CreateOneAsync(
            new CreateIndexModel<Assignment>(Builders<Assignment>.IndexKeys.Ascending(x => x.ResourceId)),
            cancellationToken: ct);

        await Assignments.Indexes.CreateOneAsync(
            new CreateIndexModel<Assignment>(Builders<Assignment>.IndexKeys.Ascending(x => x.TaskId)),
            cancellationToken: ct);

        await ChangeLogs.Indexes.CreateOneAsync(
            new CreateIndexModel<ScheduleChangeLog>(
                Builders<ScheduleChangeLog>.IndexKeys
                    .Ascending(x => x.EntityType)
                    .Ascending(x => x.EntityId)
                    .Descending(x => x.ChangedAt)),
            cancellationToken: ct);

        // Resource.Name uniqueness. Merge any existing duplicates (oldest wins,
        // assignments are reassigned to the canonical id) before installing the
        // unique index so legacy data does not block index creation.
        await DedupeResourcesByNameAsync(ct);
        await Resources.Indexes.CreateOneAsync(
            new CreateIndexModel<Resource>(
                Builders<Resource>.IndexKeys.Ascending(x => x.Name),
                new CreateIndexOptions { Unique = true, Name = "uniq_resource_name" }),
            cancellationToken: ct);

        // AgentToken.TokenHashSha256 — unique on hash so a duplicate raw token
        // (vanishingly unlikely with 32 random bytes, but cheap insurance)
        // would surface as a write error rather than a silent collision.
        await AgentTokens.Indexes.CreateOneAsync(
            new CreateIndexModel<AgentToken>(
                Builders<AgentToken>.IndexKeys.Ascending(x => x.TokenHashSha256),
                new CreateIndexOptions { Unique = true, Name = "uniq_agent_token_hash" }),
            cancellationToken: ct);
        await AgentTokens.Indexes.CreateOneAsync(
            new CreateIndexModel<AgentToken>(
                Builders<AgentToken>.IndexKeys.Ascending(x => x.ResourceId),
                new CreateIndexOptions { Name = "agent_token_resource" }),
            cancellationToken: ct);

        // Departments — parent lookup is the hot read path (build tree).
        await Departments.Indexes.CreateOneAsync(
            new CreateIndexModel<Department>(
                Builders<Department>.IndexKeys.Ascending(x => x.ParentDepartmentId),
                new CreateIndexOptions { Name = "department_parent" }),
            cancellationToken: ct);

        // AgentPlans — the two hot reads are "all plans for this task"
        // (work-queue, history) and "review queue" (status filter), so
        // index both. SubmittedBy lookup is rare enough to skip.
        await AgentPlans.Indexes.CreateOneAsync(
            new CreateIndexModel<AgentPlan>(
                Builders<AgentPlan>.IndexKeys.Ascending(x => x.TaskId),
                new CreateIndexOptions { Name = "agent_plan_task" }),
            cancellationToken: ct);
        await AgentPlans.Indexes.CreateOneAsync(
            new CreateIndexModel<AgentPlan>(
                Builders<AgentPlan>.IndexKeys.Ascending(x => x.Status),
                new CreateIndexOptions { Name = "agent_plan_status" }),
            cancellationToken: ct);

        // TaskComments — single hot read path is "all comments for this
        // task, ordered by time", so a compound index on (taskId, createdAt)
        // covers both filter and sort in one B-tree walk.
        await TaskComments.Indexes.CreateOneAsync(
            new CreateIndexModel<TaskComment>(
                Builders<TaskComment>.IndexKeys
                    .Ascending(x => x.TaskId)
                    .Ascending(x => x.CreatedAt),
                new CreateIndexOptions { Name = "task_comment_task_time" }),
            cancellationToken: ct);
    }

    private async Task DedupeResourcesByNameAsync(CancellationToken ct)
    {
        var all = await Resources.Find(FilterDefinition<Resource>.Empty).ToListAsync(ct);
        var groups = all
            .GroupBy(r => r.Name)
            .Where(g => g.Count() > 1)
            .ToList();
        foreach (var group in groups)
        {
            var canonical = group.OrderBy(r => r.CreatedAt).First();
            var dupIds = group.Where(r => r.Id != canonical.Id).Select(r => r.Id).ToList();
            if (dupIds.Count == 0) continue;

            var filter = Builders<Assignment>.Filter.In(a => a.ResourceId, dupIds);
            var update = Builders<Assignment>.Update.Set(a => a.ResourceId, canonical.Id);
            await Assignments.UpdateManyAsync(filter, update, cancellationToken: ct);

            await Resources.DeleteManyAsync(r => dupIds.Contains(r.Id), ct);
        }
    }
}
