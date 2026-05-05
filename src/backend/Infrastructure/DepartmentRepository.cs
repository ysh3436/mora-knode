using MongoDB.Bson;
using MongoDB.Driver;
using MoraKnode.Domain;

namespace MoraKnode.Infrastructure;

public class DepartmentRepository
{
    private readonly MongoContext _ctx;

    public DepartmentRepository(MongoContext ctx) => _ctx = ctx;

    public Task<List<Department>> ListAsync(CancellationToken ct = default) =>
        _ctx.Departments.Find(FilterDefinition<Department>.Empty).ToListAsync(ct);

    public Task<Department?> GetAsync(string id, CancellationToken ct = default) =>
        _ctx.Departments.Find(d => d.Id == id).FirstOrDefaultAsync(ct)!;

    public async Task<Department> CreateAsync(Department dept, CancellationToken ct = default)
    {
        var now = DateTime.UtcNow;
        dept.Id = ObjectId.GenerateNewId().ToString();
        dept.CreatedAt = now;
        dept.UpdatedAt = now;

        if (dept.ParentDepartmentId is { } pid)
        {
            // New row → can't be its own ancestor, but the parent must exist.
            var parent = await GetAsync(pid, ct);
            if (parent is null) throw new InvalidParentDepartmentException(pid);
        }

        await _ctx.Departments.InsertOneAsync(dept, cancellationToken: ct);
        return dept;
    }

    public async Task<Department?> ReplaceAsync(string id, Department incoming, CancellationToken ct = default)
    {
        var existing = await GetAsync(id, ct);
        if (existing is null) return null;

        if (incoming.ParentDepartmentId == id)
            throw new CycleDepartmentException(id);
        if (incoming.ParentDepartmentId is { } pid)
        {
            var parent = await GetAsync(pid, ct);
            if (parent is null) throw new InvalidParentDepartmentException(pid);
            // Walk parent chain — if [id] appears anywhere up there, this
            // edit would create a cycle.
            var cur = parent;
            var hops = 0;
            while (cur is not null)
            {
                if (cur.Id == id) throw new CycleDepartmentException(id);
                if (cur.ParentDepartmentId is null) break;
                if (++hops > 100) break; // defensive cap; existing data should never reach this
                cur = await GetAsync(cur.ParentDepartmentId, ct);
            }
        }

        incoming.Id = id;
        incoming.CreatedAt = existing.CreatedAt;
        incoming.UpdatedAt = DateTime.UtcNow;

        await _ctx.Departments.ReplaceOneAsync(d => d.Id == id, incoming, cancellationToken: ct);
        return incoming;
    }

    public async Task<bool> DeleteAsync(string id, CancellationToken ct = default)
    {
        // Reparent direct children up one level so deleting a mid-tree
        // node doesn't orphan its subtree. Deeper descendants follow
        // automatically because their immediate parent (now child of the
        // grandparent) keeps its position.
        var existing = await GetAsync(id, ct);
        if (existing is null) return false;

        var update = Builders<Department>.Update.Set(d => d.ParentDepartmentId, existing.ParentDepartmentId);
        await _ctx.Departments.UpdateManyAsync(d => d.ParentDepartmentId == id, update, cancellationToken: ct);

        // Detach Resource.DepartmentId references — the resource sticks
        // around but lands in "unassigned" until reassigned.
        var detach = Builders<Resource>.Update.Set(r => r.DepartmentId, (string?)null);
        await _ctx.Resources.UpdateManyAsync(r => r.DepartmentId == id, detach, cancellationToken: ct);

        var result = await _ctx.Departments.DeleteOneAsync(d => d.Id == id, ct);
        return result.DeletedCount > 0;
    }

    /// <summary>The set of resource ids in this department or any of its descendants.
    /// Used by matrix endpoint when filtering by departmentId — picks up the
    /// whole subtree, not just direct members.</summary>
    public async Task<HashSet<string>> ResourceIdsInSubtreeAsync(string departmentId, CancellationToken ct = default)
    {
        var allDepts = await _ctx.Departments
            .Find(FilterDefinition<Department>.Empty)
            .ToListAsync(ct);
        var byParent = allDepts
            .Where(d => d.ParentDepartmentId is not null)
            .GroupBy(d => d.ParentDepartmentId!)
            .ToDictionary(g => g.Key, g => g.Select(d => d.Id).ToList());

        var subtree = new HashSet<string> { departmentId };
        var queue = new Queue<string>();
        queue.Enqueue(departmentId);
        while (queue.Count > 0)
        {
            var cur = queue.Dequeue();
            if (!byParent.TryGetValue(cur, out var children)) continue;
            foreach (var c in children)
            {
                if (subtree.Add(c)) queue.Enqueue(c);
            }
        }

        var members = await _ctx.Resources
            .Find(Builders<Resource>.Filter.In(r => r.DepartmentId, subtree))
            .Project(r => r.Id)
            .ToListAsync(ct);
        return members.ToHashSet();
    }
}

public class CycleDepartmentException : Exception
{
    public string DepartmentId { get; }
    public CycleDepartmentException(string id)
        : base($"Department {id} cannot be its own ancestor") => DepartmentId = id;
}

public class InvalidParentDepartmentException : Exception
{
    public string ParentId { get; }
    public InvalidParentDepartmentException(string parentId)
        : base($"Parent department {parentId} does not exist") => ParentId = parentId;
}
