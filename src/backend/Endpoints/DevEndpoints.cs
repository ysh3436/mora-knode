using MoraKnode.Seeders;

namespace MoraKnode.Endpoints;

/// <summary>
/// Dev-only routes. Caller registers these only when env=Development.
/// </summary>
public static class DevEndpoints
{
    public static IEndpointRouteBuilder MapDevEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/dev").WithTags("Dev");

        group.MapPost("/seed", async (bool? wipe, Seeder seeder, CancellationToken ct) =>
        {
            var summary = await seeder.RunAsync(wipe ?? false, ct);
            return Results.Ok(summary);
        });

        return app;
    }
}
