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
    }
}
