using MoraKnode.Auth;
using MoraKnode.Domain;
using MoraKnode.Infrastructure;

namespace MoraKnode.Endpoints;

public static class TaskEndpoints
{
    public static IEndpointRouteBuilder MapTaskEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/projects/{projectId}/tasks", async (
            string projectId,
            TaskRepository repo,
            ScopeService scope,
            CancellationToken ct) =>
        {
            if (!await scope.CanSeeProjectAsync(projectId, ct)) return Results.NotFound();
            var all = await repo.ListByProjectAsync(projectId, ct);
            var allowed = await scope.AccessibleTaskIdsAsync(ct);
            return Results.Ok(allowed is null ? all : all.Where(t => allowed.Contains(t.Id)).ToList());
        }).WithTags("Tasks");

        app.MapPost("/api/projects/{projectId}/tasks", async (
            string projectId,
            TaskItem task,
            ProjectRepository projectRepo,
            TaskRepository taskRepo,
            CancellationToken ct) =>
        {
            var project = await projectRepo.GetAsync(projectId, ct);
            if (project is null) return Results.NotFound(new { error = "Project not found" });
            if (string.IsNullOrWhiteSpace(task.Title))
                return Results.BadRequest(new { error = "Title is required" });

            task.ProjectId = projectId;
            var created = await taskRepo.CreateAsync(task, ct);
            return Results.Created($"/api/tasks/{created.Id}", created);
        }).WithTags("Tasks");

        var item = app.MapGroup("/api/tasks").WithTags("Tasks");

        item.MapGet("/{id}", async (string id, TaskRepository repo, CancellationToken ct) =>
        {
            var task = await repo.GetAsync(id, ct);
            return task is null ? Results.NotFound() : Results.Ok(task);
        });

        item.MapPut("/{id}", async (string id, TaskItem task, TaskRepository repo, CancellationToken ct) =>
        {
            var updated = await repo.ReplaceAsync(id, task, ct);
            return updated is null ? Results.NotFound() : Results.Ok(updated);
        });

        item.MapDelete("/{id}", async (string id, TaskRepository repo, CancellationToken ct) =>
        {
            var deleted = await repo.DeleteAsync(id, ct);
            return deleted ? Results.NoContent() : Results.NotFound();
        });

        return app;
    }
}
