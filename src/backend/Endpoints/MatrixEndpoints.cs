using MoraKnode.Domain;
using MoraKnode.Infrastructure;

namespace MoraKnode.Endpoints;

public static class MatrixEndpoints
{
    public static IEndpointRouteBuilder MapMatrixEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/matrix").WithTags("Matrix");

        // Integrated load view: for each resource, the daily total allocation across all tasks
        // within the requested [from, to) date window. Used by the Matrix Resource Manager.
        // Marks buckets as overloaded when daily load > resource CapacityPercent.
        group.MapGet("/load", async (
            DateTime from,
            DateTime to,
            ResourceRepository resources,
            AssignmentRepository assignments,
            TaskRepository taskRepo,
            CancellationToken ct) =>
        {
            if (to <= from)
                return Results.BadRequest(new { error = "'to' must be after 'from'" });
            if ((to - from).TotalDays > 366)
                return Results.BadRequest(new { error = "Range must be <= 366 days" });

            var fromDate = DateTime.SpecifyKind(from.Date, DateTimeKind.Utc);
            var toDate = DateTime.SpecifyKind(to.Date, DateTimeKind.Utc);

            var resourceList = await resources.ListAsync(ct);
            var overlapping = await assignments.ListOverlappingAsync(fromDate, toDate, ct);

            // Leaf-only rule: skip assignments whose owning task has any child (i.e. became a parent).
            if (overlapping.Count > 0)
            {
                var affectedTaskIds = overlapping.Select(a => a.TaskId).Distinct();
                var nonLeafIds = await taskRepo.NonLeafIdsAsync(affectedTaskIds, ct);
                if (nonLeafIds.Count > 0)
                    overlapping = overlapping.Where(a => !nonLeafIds.Contains(a.TaskId)).ToList();
            }

            // Pre-bucket assignments per resource and per day.
            var buckets = new Dictionary<string, Dictionary<DateTime, int>>();
            foreach (var a in overlapping)
            {
                if (!buckets.TryGetValue(a.ResourceId, out var perDay))
                {
                    perDay = new Dictionary<DateTime, int>();
                    buckets[a.ResourceId] = perDay;
                }

                var segStart = a.Start.Date < fromDate ? fromDate : a.Start.Date;
                var segEnd = a.End.Date > toDate ? toDate : a.End.Date;

                for (var day = segStart; day < segEnd; day = day.AddDays(1))
                {
                    perDay.TryGetValue(day, out var cur);
                    perDay[day] = cur + a.AllocationPercent;
                }
            }

            var result = resourceList.Select(r =>
            {
                buckets.TryGetValue(r.Id, out var perDay);
                var days = new List<ResourceLoadBucket>();
                for (var day = fromDate; day < toDate; day = day.AddDays(1))
                {
                    var load = perDay is not null && perDay.TryGetValue(day, out var v) ? v : 0;
                    days.Add(new ResourceLoadBucket(day, load, load > r.CapacityPercent));
                }
                return new ResourceLoad(r.Id, r.Name, r.Role, r.CapacityPercent, days);
            }).ToList();

            return Results.Ok(result);
        });

        return app;
    }
}

public record ResourceLoadBucket(DateTime Date, int LoadPercent, bool Overloaded);
public record ResourceLoad(
    string ResourceId,
    string ResourceName,
    string? ResourceRole,
    int CapacityPercent,
    List<ResourceLoadBucket> Days);
