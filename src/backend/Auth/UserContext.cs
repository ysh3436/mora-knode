using MoraKnode.Domain;

namespace MoraKnode.Auth;

/// <summary>
/// Per-request snapshot of "who is calling". Populated by
/// <see cref="UserContextMiddleware"/> from the X-Dev-User-Id header
/// (dev-only convention until token auth lands in M2).
/// </summary>
public class UserContext
{
    public Resource? CurrentUser { get; set; }

    /// <summary>
    /// True when the current user has full visibility (no scoping). Per
    /// ADR-004 §3 / seed-scenarios.md §3.4, Manager + Reviewer + Human all
    /// see everything; Developer + QA see only what they're assigned to.
    /// Anonymous callers (no header) also default to full visibility — the
    /// scoping is opt-in for now.
    /// </summary>
    public bool IsAdmin =>
        CurrentUser is null
        || CurrentUser.Rbac is RbacPreset.Manager or RbacPreset.Reviewer or RbacPreset.Human;
}
