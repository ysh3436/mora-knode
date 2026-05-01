using MongoDB.Driver;
using MoraKnode.Domain;
using MoraKnode.Infrastructure;
using MoraKnode.Seeders;

namespace MoraKnode.Endpoints;

/// <summary>
/// Dev-only routes. Caller registers these only when env=Development.
/// </summary>
public static class DevEndpoints
{
    public static IEndpointRouteBuilder MapDevEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/dev").WithTags("Dev");

        group.MapPost("/seed", async (bool? wipe, Seeder seeder, CancellationToken ct) =>
        {
            var summary = await seeder.RunAsync(wipe ?? false, ct);
            return Results.Ok(summary);
        });

        // One-shot for the MK-N backfill: reads max(Number) from Tasks and
        // sets AppMeta.NextTaskNumber to it so the next CreateAsync allocation
        // (post-increment) returns max+1. Idempotent.
        group.MapPost("/sync-task-counter", async (
            MongoContext ctx,
            AppMetaRepository metaRepo,
            CancellationToken ct) =>
        {
            var maxNum = await ctx.Tasks
                .Find(FilterDefinition<TaskItem>.Empty)
                .Sort(Builders<TaskItem>.Sort.Descending(t => t.Number))
                .Limit(1)
                .Project(t => (int?)t.Number)
                .FirstOrDefaultAsync(ct) ?? 0;
            var meta = await metaRepo.GetAsync(ct);
            meta.NextTaskNumber = maxNum;
            await metaRepo.UpsertAsync(meta, ct);
            return Results.Ok(new { nextTaskNumber = maxNum, nextAllocated = maxNum + 1 });
        });

        return app;
    }
}
