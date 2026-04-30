using MoraKnode.Domain;
using MoraKnode.Infrastructure;

namespace MoraKnode.Endpoints;

public static class ChangeLogEndpoints
{
    public static IEndpointRouteBuilder MapChangeLogEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/change-logs").WithTags("ChangeLogs");

        group.MapGet("/", async (
            ChangeEntityType? entityType,
            string? entityId,
            int? limit,
            ChangeLogRepository repo,
            CancellationToken ct) =>
        {
            var capped = Math.Clamp(limit ?? 100, 1, 500);
            var logs = await repo.ListAsync(entityType, entityId, capped, ct);
            return Results.Ok(logs);
        });

        return app;
    }
}
