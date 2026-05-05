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
            string? projectId,
            DateTime? from,
            DateTime? to,
            int? offset,
            int? limit,
            ChangeLogRepository repo,
            ScopeService scope,
            CancellationToken ct) =>
        {
            var safeLimit = Math.Clamp(limit ?? 100, 1, 500);
            var safeOffset = Math.Max(offset ?? 0, 0);

            var (logs, total) = await repo.ListAsync(
                entityType: entityType,
                entityId: entityId,
                projectId: projectId,
                from: from,
                to: to,
                offset: safeOffset,
                limit: safeLimit,
                ct: ct);

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
                // Note: total reflects pre-scope-filter count (Mongo can't
                // know what each caller's RBAC scope is). Acceptable for
                // v1 — admins see the same total either way, and in the
                // rare scoped case a small mismatch between rows.length
                // and the total counter is OK ("you see 47 of 53" =
                // "the rest are outside your scope").
            }

            return Results.Ok(new ChangeLogPage(
                Rows: logs,
                Total: total,
                Offset: safeOffset,
                Limit: safeLimit));
        });

        return app;
    }
}

public record ChangeLogPage(
    IReadOnlyList<ScheduleChangeLog> Rows,
    long Total,
    int Offset,
    int Limit);
