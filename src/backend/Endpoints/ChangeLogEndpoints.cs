using MoraKnode.Auth;
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
            ScopeService scope,
            CancellationToken ct) =>
        {
            var capped = Math.Clamp(limit ?? 100, 1, 500);
            var logs = await repo.ListAsync(entityType, entityId, capped, ct);

            // Filter to the caller's accessible scope. Skipped when admin.
            var accessibleTasks = await scope.AccessibleTaskIdsAsync(ct);
            var accessibleProjects = await scope.AccessibleProjectIdsAsync(ct);
            if (accessibleTasks is not null && accessibleProjects is not null)
            {
                logs = logs.Where(l => l.EntityType switch
                {
                    ChangeEntityType.Task => accessibleTasks.Contains(l.EntityId),
                    ChangeEntityType.Project => accessibleProjects.Contains(l.EntityId),
                    ChangeEntityType.Milestone => true,   // milestone scope = its project; resolve later
                    _ => false
                }).ToList();
            }

            return Results.Ok(logs);
        });

        return app;
    }
}
