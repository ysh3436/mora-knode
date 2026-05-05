using MoraKnode.Auth;
using MoraKnode.Domain;
using MoraKnode.Infrastructure;

namespace MoraKnode.Endpoints;

public static class AgentEndpoints
{
    public static IEndpointRouteBuilder MapAgentEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/agents").WithTags("Agents");

        // List every Resource of Kind=Agent. Tokens are not joined here —
        // surfacing per-agent token info goes through GET /:id/tokens so
        // the list endpoint stays cheap.
        group.MapGet("/", async (ResourceRepository resources, CancellationToken ct) =>
        {
            var all = await resources.ListAsync(ct);
            return Results.Ok(all.Where(r => r.Kind == ResourceKind.Agent));
        });

        // Issue a new agent identity in one shot: a Resource (Kind=Agent) +
        // its first AgentToken. The raw token string is returned exactly
        // once in the response — losing it means the caller has to rotate.
        group.MapPost("/", async (
            CreateAgentRequest req,
            ResourceRepository resources,
            AgentTokenRepository tokens,
            CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(req.Name))
                return Results.BadRequest(new { error = "Name is required" });
            if (await resources.GetByNameAsync(req.Name.Trim(), ct) is not null)
                return Results.Conflict(new { error = $"Resource name '{req.Name}' is already in use" });

            var resource = await resources.CreateAsync(new Resource
            {
                Name = req.Name.Trim(),
                Role = req.Role,
                Kind = ResourceKind.Agent,
                Rbac = req.Rbac ?? RbacPreset.Developer,
                AgentDescription = req.Description,
                CapacityPercent = req.CapacityPercent ?? 100,
            }, ct);

            var issued = TokenGenerator.Issue();
            await tokens.InsertAsync(new AgentToken
            {
                ResourceId = resource.Id,
                TokenHashSha256 = issued.Hash,
                LastFourChars = issued.LastFour,
                CreatedAt = DateTime.UtcNow,
            }, ct);

            return Results.Created($"/api/agents/{resource.Id}", new CreateAgentResponse(
                Agent: resource,
                RawToken: issued.Raw,
                LastFour: issued.LastFour));
        });

        // Token history for one agent. Active = RevokedAt is null. The raw
        // token is never returned here (we only stored the hash); rotate
        // is the only path to see a usable raw token again.
        group.MapGet("/{id}/tokens", async (
            string id,
            AgentTokenRepository tokens,
            CancellationToken ct) =>
        {
            var rows = await tokens.ListByResourceAsync(id, ct);
            return Results.Ok(rows.Select(t => new TokenSummary(
                Id: t.Id,
                LastFour: t.LastFourChars,
                CreatedAt: t.CreatedAt,
                RevokedAt: t.RevokedAt,
                LastSeenAt: t.LastSeenAt,
                IsActive: t.RevokedAt is null)));
        });

        // Atomic rotate: revoke any active token row(s) for this agent,
        // then issue a fresh one. The new raw token is returned exactly
        // once. Audit-friendly: the prior row stays in the collection
        // with RevokedAt set, so "who has historically used what" is
        // still answerable.
        group.MapPost("/{id}/rotate", async (
            string id,
            ResourceRepository resources,
            AgentTokenRepository tokens,
            CancellationToken ct) =>
        {
            var resource = await resources.GetAsync(id, ct);
            if (resource is null || resource.Kind != ResourceKind.Agent)
                return Results.NotFound();

            await tokens.RevokeAllForResourceAsync(id, ct);
            var issued = TokenGenerator.Issue();
            await tokens.InsertAsync(new AgentToken
            {
                ResourceId = id,
                TokenHashSha256 = issued.Hash,
                LastFourChars = issued.LastFour,
                CreatedAt = DateTime.UtcNow,
            }, ct);
            return Results.Ok(new RotateTokenResponse(RawToken: issued.Raw, LastFour: issued.LastFour));
        });

        // Revoke without re-issuing. After this, every Bearer auth attempt
        // for this agent fails 401. The Resource itself stays in place so
        // historical assignments / change logs remain readable.
        group.MapPost("/{id}/revoke", async (
            string id,
            ResourceRepository resources,
            AgentTokenRepository tokens,
            CancellationToken ct) =>
        {
            var resource = await resources.GetAsync(id, ct);
            if (resource is null || resource.Kind != ResourceKind.Agent)
                return Results.NotFound();
            var n = await tokens.RevokeAllForResourceAsync(id, ct);
            return Results.Ok(new { revoked = n });
        });

        return app;
    }
}

public record CreateAgentRequest(
    string Name,
    string? Role,
    string? Description,
    RbacPreset? Rbac,
    int? CapacityPercent);

public record CreateAgentResponse(
    Resource Agent,
    string RawToken,
    string LastFour);

public record RotateTokenResponse(
    string RawToken,
    string LastFour);

public record TokenSummary(
    string Id,
    string LastFour,
    DateTime CreatedAt,
    DateTime? RevokedAt,
    DateTime? LastSeenAt,
    bool IsActive);
