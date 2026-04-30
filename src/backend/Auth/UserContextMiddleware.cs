using MoraKnode.Infrastructure;

namespace MoraKnode.Auth;

/// <summary>
/// Reads the dev-only <c>X-Dev-User-Id</c> header on every request and
/// populates the scoped <see cref="UserContext"/>. When the header is
/// missing or the id does not resolve, CurrentUser stays null and
/// downstream code defaults to admin-equivalent visibility.
/// </summary>
public class UserContextMiddleware
{
    public const string HeaderName = "X-Dev-User-Id";

    private readonly RequestDelegate _next;

    public UserContextMiddleware(RequestDelegate next) => _next = next;

    public async Task InvokeAsync(HttpContext ctx, UserContext userContext, ResourceRepository resources)
    {
        if (ctx.Request.Headers.TryGetValue(HeaderName, out var values))
        {
            var id = values.ToString();
            if (!string.IsNullOrWhiteSpace(id))
            {
                userContext.CurrentUser = await resources.GetAsync(id, ctx.RequestAborted);
            }
        }
        await _next(ctx);
    }
}
