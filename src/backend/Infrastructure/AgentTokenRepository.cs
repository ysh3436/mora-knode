using MongoDB.Bson;
using MongoDB.Driver;
using MoraKnode.Domain;

namespace MoraKnode.Infrastructure;

public class AgentTokenRepository
{
    private readonly MongoContext _ctx;

    public AgentTokenRepository(MongoContext ctx) => _ctx = ctx;

    /// <summary>Find the active (non-revoked) token row matching this hash, if any.
    /// Used by the auth middleware on every Bearer-authenticated request.</summary>
    public Task<AgentToken?> FindActiveByHashAsync(string hash, CancellationToken ct = default) =>
        _ctx.AgentTokens
            .Find(t => t.TokenHashSha256 == hash && t.RevokedAt == null)
            .FirstOrDefaultAsync(ct)!;

    /// <summary>All tokens for an agent (active + historical), newest first.
    /// Surfaces in the agent management UI as "what keys exist".</summary>
    public Task<List<AgentToken>> ListByResourceAsync(string resourceId, CancellationToken ct = default) =>
        _ctx.AgentTokens
            .Find(t => t.ResourceId == resourceId)
            .SortByDescending(t => t.CreatedAt)
            .ToListAsync(ct);

    public async Task<AgentToken> InsertAsync(AgentToken token, CancellationToken ct = default)
    {
        token.Id = ObjectId.GenerateNewId().ToString();
        if (token.CreatedAt == default) token.CreatedAt = DateTime.UtcNow;
        await _ctx.AgentTokens.InsertOneAsync(token, cancellationToken: ct);
        return token;
    }

    /// <summary>Mark every active token for the given agent as revoked. Used both
    /// when explicitly revoking and as the first half of a rotate.</summary>
    public async Task<long> RevokeAllForResourceAsync(string resourceId, CancellationToken ct = default)
    {
        var now = DateTime.UtcNow;
        var update = Builders<AgentToken>.Update.Set(t => t.RevokedAt, now);
        var result = await _ctx.AgentTokens.UpdateManyAsync(
            t => t.ResourceId == resourceId && t.RevokedAt == null,
            update,
            cancellationToken: ct);
        return result.ModifiedCount;
    }
}
