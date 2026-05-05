using MoraKnode.Domain;
using MoraKnode.Infrastructure;

namespace MoraKnode.Endpoints;

public static class DepartmentEndpoints
{
    public static IEndpointRouteBuilder MapDepartmentEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/departments").WithTags("Departments");

        group.MapGet("/", async (DepartmentRepository repo, CancellationToken ct) =>
            Results.Ok(await repo.ListAsync(ct)));

        group.MapGet("/{id}", async (string id, DepartmentRepository repo, CancellationToken ct) =>
        {
            var d = await repo.GetAsync(id, ct);
            return d is null ? Results.NotFound() : Results.Ok(d);
        });

        group.MapPost("/", async (Department dept, DepartmentRepository repo, CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(dept.Name))
                return Results.BadRequest(new { error = "Name is required" });
            try
            {
                var created = await repo.CreateAsync(dept, ct);
                return Results.Created($"/api/departments/{created.Id}", created);
            }
            catch (InvalidParentDepartmentException ex)
            {
                return Results.BadRequest(new { error = ex.Message });
            }
        });

        group.MapPut("/{id}", async (string id, Department dept, DepartmentRepository repo, CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(dept.Name))
                return Results.BadRequest(new { error = "Name is required" });
            try
            {
                var updated = await repo.ReplaceAsync(id, dept, ct);
                return updated is null ? Results.NotFound() : Results.Ok(updated);
            }
            catch (CycleDepartmentException ex)
            {
                return Results.BadRequest(new { error = ex.Message });
            }
            catch (InvalidParentDepartmentException ex)
            {
                return Results.BadRequest(new { error = ex.Message });
            }
        });

        group.MapDelete("/{id}", async (string id, DepartmentRepository repo, CancellationToken ct) =>
        {
            var ok = await repo.DeleteAsync(id, ct);
            return ok ? Results.NoContent() : Results.NotFound();
        });

        return app;
    }
}
