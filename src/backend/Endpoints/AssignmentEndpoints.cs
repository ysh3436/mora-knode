using MoraKnode.Domain;
using MoraKnode.Infrastructure;

namespace MoraKnode.Endpoints;

public static class AssignmentEndpoints
{
    public static IEndpointRouteBuilder MapAssignmentEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/assignments").WithTags("Assignments");

        group.MapGet("/", async (
            string? resourceId,
            string? taskId,
            AssignmentRepository repo,
            CancellationToken ct) =>
            Results.Ok(await repo.ListAsync(resourceId, taskId, ct)));

        group.MapGet("/{id}", async (string id, AssignmentRepository repo, CancellationToken ct) =>
        {
            var assignment = await repo.GetAsync(id, ct);
            return assignment is null ? Results.NotFound() : Results.Ok(assignment);
        });

        group.MapPost("/", async (
            Assignment assignment,
            ResourceRepository resources,
            TaskRepository tasks,
            AssignmentRepository repo,
            CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(assignment.ResourceId))
                return Results.BadRequest(new { error = "ResourceId is required" });
            if (string.IsNullOrWhiteSpace(assignment.TaskId))
                return Results.BadRequest(new { error = "TaskId is required" });
            if (assignment.End <= assignment.Start)
                return Results.BadRequest(new { error = "End must be after Start" });
            if (assignment.AllocationPercent < 0)
                return Results.BadRequest(new { error = "AllocationPercent must be >= 0" });

            if (await resources.GetAsync(assignment.ResourceId, ct) is null)
                return Results.BadRequest(new { error = "Resource not found" });
            if (await tasks.GetAsync(assignment.TaskId, ct) is null)
                return Results.BadRequest(new { error = "Task not found" });

            var created = await repo.CreateAsync(assignment, ct);
            return Results.Created($"/api/assignments/{created.Id}", created);
        });

        group.MapPut("/{id}", async (string id, Assignment assignment, AssignmentRepository repo, CancellationToken ct) =>
        {
            var updated = await repo.ReplaceAsync(id, assignment, ct);
            return updated is null ? Results.NotFound() : Results.Ok(updated);
        });

        group.MapDelete("/{id}", async (string id, AssignmentRepository repo, CancellationToken ct) =>
        {
            var deleted = await repo.DeleteAsync(id, ct);
            return deleted ? Results.NoContent() : Results.NotFound();
        });

        return app;
    }
}
