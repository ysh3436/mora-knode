using MoraKnode.Auth;
using MoraKnode.Domain;
using MoraKnode.Infrastructure;

namespace MoraKnode.Endpoints;

public static class ProjectEndpoints
{
    public static IEndpointRouteBuilder MapProjectEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/projects").WithTags("Projects");

        group.MapGet("/", async (ProjectRepository repo, ScopeService scope, CancellationToken ct) =>
        {
            var all = await repo.ListAsync(ct);
            var allowed = await scope.AccessibleProjectIdsAsync(ct);
            return Results.Ok(allowed is null ? all : all.Where(p => allowed.Contains(p.Id)).ToList());
        });

        group.MapGet("/{id}", async (string id, ProjectRepository repo, ScopeService scope, CancellationToken ct) =>
        {
            if (!await scope.CanSeeProjectAsync(id, ct)) return Results.NotFound();
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

        // Project membership ops as separate sub-routes so the caller doesn't
        // have to PUT the full Project body just to add or drop one member.
        // Both endpoints are idempotent: re-adding an existing member is a
        // no-op, removing a non-member returns the unchanged list.
        group.MapPost("/{id}/members/{resourceId}", async (
            string id,
            string resourceId,
            ProjectRepository projectRepo,
            ResourceRepository resourceRepo,
            CancellationToken ct) =>
        {
            var project = await projectRepo.GetAsync(id, ct);
            if (project is null) return Results.NotFound();
            var resource = await resourceRepo.GetAsync(resourceId, ct);
            if (resource is null) return Results.BadRequest(new { error = $"Resource {resourceId} does not exist" });

            if (!project.MemberResourceIds.Contains(resourceId))
            {
                project.MemberResourceIds.Add(resourceId);
                await projectRepo.ReplaceAsync(id, project, ct);
            }
            return Results.Ok(project);
        });

        group.MapDelete("/{id}/members/{resourceId}", async (
            string id,
            string resourceId,
            ProjectRepository projectRepo,
            CancellationToken ct) =>
        {
            var project = await projectRepo.GetAsync(id, ct);
            if (project is null) return Results.NotFound();

            if (project.MemberResourceIds.Remove(resourceId))
            {
                await projectRepo.ReplaceAsync(id, project, ct);
            }
            return Results.Ok(project);
        });

        return app;
    }
}
