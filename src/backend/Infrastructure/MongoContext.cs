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

    public async Task EnsureIndexesAsync(CancellationToken ct = default)
    {
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
