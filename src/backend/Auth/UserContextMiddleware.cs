using MoraKnode.Domain;
using MoraKnode.Infrastructure;

namespace MoraKnode.Auth;

/// <summary>
/// Resolves "who is calling" on every request and populates the scoped
/// <see cref="UserContext"/>. Two paths in priority order:
/// <list type="number">
///   <item>Bearer agent token (<c>Authorization: Bearer mk_…</c> + <c>X-Agent-Id</c>) —
///         the production identity for external AI agents (ADR-004 §2).</item>
///   <item>Dev impersonation header (<c>X-Dev-User-Id</c>) — the convenience
///         path for local development; will be locked behind an env flag
///         once Phase 2 ships.</item>
/// </list>
/// When neither resolves, CurrentUser stays null and downstream code
/// defaults to admin-equivalent visibility (ScopeService treats
/// anonymous as no-scope, matching the current behaviour).
///
/// Bearer auth is strict: a malformed prefix, unknown hash, revoked row,
/// or X-Agent-Id mismatch all short-circuit with 401 so a typo can't
/// silently fall back to anonymous-admin.
/// </summary>
public class UserContextMiddleware
{
    public const string DevUserHeader = "X-Dev-User-Id";
    public const string AgentIdHeader = "X-Agent-Id";

    private readonly RequestDelegate _next;

    public UserContextMiddleware(RequestDelegate next) => _next = next;

    public async Task InvokeAsync(
        HttpContext ctx,
        UserContext userContext,
        ResourceRepository resources,
        AgentTokenRepository agentTokens)
    {
        // Path 1: Bearer agent token. Presence of an Authorization header
        // means the caller intends to authenticate — never silently fall
        // through to dev-header / anonymous, that would be a security hole.
        if (ctx.Request.Headers.TryGetValue("Authorization", out var auth))
        {
            var raw = auth.ToString();
            if (!raw.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
            {
                await Reject(ctx, "Authorization header must use Bearer scheme.");
                return;
            }
            var presented = raw["Bearer ".Length..].Trim();
            var hash = TokenGenerator.HashOf(presented);
            if (hash is null)
            {
                await Reject(ctx, "Token format invalid (expected mk_<base64url>).");
                return;
            }
            var token = await agentTokens.FindActiveByHashAsync(hash, ctx.RequestAborted);
            if (token is null)
            {
                await Reject(ctx, "Token unknown or revoked.");
                return;
            }
            // X-Agent-Id is required as a defence-in-depth: it forces the
            // caller to also know which Resource they claim to be, so a
            // leaked token alone (without paired id) produces an obvious
            // mismatch in logs rather than silent misuse.
            if (!ctx.Request.Headers.TryGetValue(AgentIdHeader, out var claimedAgentId)
                || !string.Equals(claimedAgentId.ToString(), token.ResourceId, StringComparison.Ordinal))
            {
                await Reject(ctx, $"{AgentIdHeader} missing or does not match token owner.");
                return;
            }
            var agent = await resources.GetAsync(token.ResourceId, ctx.RequestAborted);
            if (agent is null || agent.Kind != ResourceKind.Agent)
            {
                await Reject(ctx, "Token owner is not a valid agent resource.");
                return;
            }
            userContext.CurrentUser = agent;
            await _next(ctx);
            return;
        }

        // Path 2: dev-only impersonation header. Kept for local browser /
        // curl convenience. Unknown id silently falls through to anonymous
        // (matches the existing behaviour — no breaking change for the UI).
        if (ctx.Request.Headers.TryGetValue(DevUserHeader, out var devValues))
        {
            var id = devValues.ToString();
            if (!string.IsNullOrWhiteSpace(id))
            {
                userContext.CurrentUser = await resources.GetAsync(id, ctx.RequestAborted);
            }
        }
        await _next(ctx);
    }

    private static async Task Reject(HttpContext ctx, string detail)
    {
        ctx.Response.StatusCode = StatusCodes.Status401Unauthorized;
        await ctx.Response.WriteAsJsonAsync(new { error = "Unauthorized", detail });
    }
}
