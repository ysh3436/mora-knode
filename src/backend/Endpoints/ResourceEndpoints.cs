using MoraKnode.Domain;
using MoraKnode.Infrastructure;

namespace MoraKnode.Endpoints;

public static class ResourceEndpoints
{
    public static IEndpointRouteBuilder MapResourceEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/resources").WithTags("Resources");

        group.MapGet("/", async (ResourceRepository repo, CancellationToken ct) =>
            Results.Ok(await repo.ListAsync(ct)));

        group.MapGet("/{id}", async (string id, ResourceRepository repo, CancellationToken ct) =>
        {
            var resource = await repo.GetAsync(id, ct);
            return resource is null ? Results.NotFound() : Results.Ok(resource);
        });

        group.MapPost("/", async (Resource resource, ResourceRepository repo, CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(resource.Name))
                return Results.BadRequest(new { error = "Name is required" });
            if (resource.CapacityPercent < 0)
                return Results.BadRequest(new { error = "CapacityPercent must be >= 0" });

            resource.Name = resource.Name.Trim();
            if (await repo.GetByNameAsync(resource.Name, ct) is not null)
                return Results.Conflict(new { error = $"Resource name '{resource.Name}' is already in use" });

            var created = await repo.CreateAsync(resource, ct);
            return Results.Created($"/api/resources/{created.Id}", created);
        });

        group.MapPut("/{id}", async (string id, Resource resource, ResourceRepository repo, CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(resource.Name))
                return Results.BadRequest(new { error = "Name is required" });

            resource.Name = resource.Name.Trim();
            var existingByName = await repo.GetByNameAsync(resource.Name, ct);
            if (existingByName is not null && existingByName.Id != id)
                return Results.Conflict(new { error = $"Resource name '{resource.Name}' is already in use" });

            var updated = await repo.ReplaceAsync(id, resource, ct);
            return updated is null ? Results.NotFound() : Results.Ok(updated);
        });

        group.MapDelete("/{id}", async (string id, ResourceRepository repo, CancellationToken ct) =>
        {
            var deleted = await repo.DeleteAsync(id, ct);
            return deleted ? Results.NoContent() : Results.NotFound();
        });

        return app;
    }
}
