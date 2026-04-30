using MoraKnode.Domain;
using MoraKnode.Infrastructure;

namespace MoraKnode.Endpoints;

public static class MilestoneEndpoints
{
    public static IEndpointRouteBuilder MapMilestoneEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/projects/{projectId}/milestones", async (
            string projectId,
            MilestoneRepository repo,
            CancellationToken ct) =>
            Results.Ok(await repo.ListByProjectAsync(projectId, ct)))
            .WithTags("Milestones");

        app.MapPost("/api/projects/{projectId}/milestones", async (
            string projectId,
            Milestone milestone,
            ProjectRepository projectRepo,
            MilestoneRepository repo,
            CancellationToken ct) =>
        {
            if (await projectRepo.GetAsync(projectId, ct) is null)
                return Results.NotFound(new { error = "Project not found" });
            if (string.IsNullOrWhiteSpace(milestone.Title))
                return Results.BadRequest(new { error = "Title is required" });

            milestone.ProjectId = projectId;
            var created = await repo.CreateAsync(milestone, ct);
            return Results.Created($"/api/milestones/{created.Id}", created);
        }).WithTags("Milestones");

        var group = app.MapGroup("/api/milestones").WithTags("Milestones");

        group.MapGet("/{id}", async (string id, MilestoneRepository repo, CancellationToken ct) =>
        {
            var milestone = await repo.GetAsync(id, ct);
            return milestone is null ? Results.NotFound() : Results.Ok(milestone);
        });

        group.MapPut("/{id}", async (string id, Milestone milestone, MilestoneRepository repo, CancellationToken ct) =>
        {
            var updated = await repo.ReplaceAsync(id, milestone, ct);
            return updated is null ? Results.NotFound() : Results.Ok(updated);
        });

        group.MapDelete("/{id}", async (string id, MilestoneRepository repo, CancellationToken ct) =>
        {
            var deleted = await repo.DeleteAsync(id, ct);
            return deleted ? Results.NoContent() : Results.NotFound();
        });

        return app;
    }
}
