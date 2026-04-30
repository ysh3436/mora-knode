using MongoDB.Driver;
using MoraKnode.Domain;
using MoraKnode.Infrastructure;

namespace MoraKnode.Auth;

/// <summary>
/// Resolves the set of entities the current user is allowed to read.
/// Cached per-request so multiple endpoint handlers can hit it cheaply.
/// </summary>
public class ScopeService
{
    private readonly UserContext _user;
    private readonly MongoContext _ctx;

    private HashSet<string>? _cachedTaskIds;
    private HashSet<string>? _cachedProjectIds;

    public ScopeService(UserContext user, MongoContext ctx)
    {
        _user = user;
        _ctx = ctx;
    }

    /// <summary>
    /// Returns null when the caller is admin-equivalent (no scoping). Otherwise
    /// the set of task ids the user can see: every task they're assigned to,
    /// plus its full ancestor chain (so parents stay visible for context, per
    /// seed-scenarios.md §3.4 #2).
    /// </summary>
    public async Task<HashSet<string>?> AccessibleTaskIdsAsync(CancellationToken ct = default)
    {
        if (_user.IsAdmin || _user.CurrentUser is null) return null;
        if (_cachedTaskIds is not null) return _cachedTaskIds;

        var userId = _user.CurrentUser.Id;
        var assigned = await _ctx.Assignments
            .Find(a => a.ResourceId == userId)
            .Project(a => a.TaskId)
            .ToListAsync(ct);

        var ownedIds = assigned.ToHashSet();
        if (ownedIds.Count == 0)
        {
            _cachedTaskIds = ownedIds;
            return _cachedTaskIds;
        }

        // Pull every task whose project contains an owned task — minimum
        // window we need to walk the parent chain.
        var ownedTasks = await _ctx.Tasks
            .Find(Builders<TaskItem>.Filter.In(t => t.Id, ownedIds))
            .ToListAsync(ct);
        var projectIds = ownedTasks.Select(t => t.ProjectId).ToHashSet();
        var projectTasks = await _ctx.Tasks
            .Find(Builders<TaskItem>.Filter.In(t => t.ProjectId, projectIds))
            .ToListAsync(ct);
        var byId = projectTasks.ToDictionary(t => t.Id);

        var visible = new HashSet<string>();
        foreach (var ownedId in ownedIds)
        {
            if (!byId.TryGetValue(ownedId, out var cur)) continue;
            while (cur is not null && visible.Add(cur.Id))
            {
                if (cur.ParentTaskId is null) break;
                cur = byId.GetValueOrDefault(cur.ParentTaskId);
            }
        }

        _cachedTaskIds = visible;
        return _cachedTaskIds;
    }

    /// <summary>
    /// Returns null when admin-equivalent. Otherwise the set of project ids
    /// the user can see (any project containing at least one accessible task).
    /// </summary>
    public async Task<HashSet<string>?> AccessibleProjectIdsAsync(CancellationToken ct = default)
    {
        if (_user.IsAdmin || _user.CurrentUser is null) return null;
        if (_cachedProjectIds is not null) return _cachedProjectIds;

        var taskIds = await AccessibleTaskIdsAsync(ct);
        if (taskIds is null || taskIds.Count == 0)
        {
            _cachedProjectIds = new HashSet<string>();
            return _cachedProjectIds;
        }

        var tasks = await _ctx.Tasks
            .Find(Builders<TaskItem>.Filter.In(t => t.Id, taskIds))
            .Project(t => t.ProjectId)
            .ToListAsync(ct);
        _cachedProjectIds = tasks.ToHashSet();
        return _cachedProjectIds;
    }

    /// <summary>
    /// True when the caller can see this specific project.
    /// </summary>
    public async Task<bool> CanSeeProjectAsync(string projectId, CancellationToken ct = default)
    {
        var ids = await AccessibleProjectIdsAsync(ct);
        return ids is null || ids.Contains(projectId);
    }
}
