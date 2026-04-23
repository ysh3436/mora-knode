using MoraKnode.Domain;
using MoraKnode.Infrastructure;

namespace MoraKnode.Endpoints;

public static class ProjectEndpoints
{
    public static IEndpointRouteBuilder MapProjectEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/projects").WithTags("Projects");

        group.MapGet("/", async (ProjectRepository repo, CancellationToken ct) =>
            Results.Ok(await repo.ListAsync(ct)));

        group.MapGet("/{id}", async (string id, ProjectRepository repo, CancellationToken ct) =>
        {
            var project = await repo.GetAsync(id, ct);
            return project is null ? Results.NotFound() : Results.Ok(project);
        });

        group.MapPost("/", async (Project project, ProjectRepository repo, CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(project.Name))
                return Results.BadRequest(new { error = "Name is required" });

            var created = await repo.CreateAsync(project, ct);
            return Results.Created($"/api/projects/{created.Id}", created);
        });

        group.MapPut("/{id}", async (string id, Project project, ProjectRepository repo, CancellationToken ct) =>
        {
            var updated = await repo.ReplaceAsync(id, project, ct);
            return updated is null ? Results.NotFound() : Results.Ok(updated);
        });

        group.MapDelete("/{id}", async (
            string id,
            ProjectRepository projectRepo,
            TaskRepository taskRepo,
            CancellationToken ct) =>
        {
            var deleted = await projectRepo.DeleteAsync(id, ct);
            if (!deleted) return Results.NotFound();

            await taskRepo.DeleteByProjectAsync(id, ct);
            return Results.NoContent();
        });

        return app;
    }
}
