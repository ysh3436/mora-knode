using MoraKnode.Auth;
using MoraKnode.Domain;
using MoraKnode.Infrastructure;
using MongoDB.Driver;

namespace MoraKnode.Endpoints;

public static class MatrixEndpoints
{
    public static IEndpointRouteBuilder MapMatrixEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/matrix").WithTags("Matrix");

        // Integrated load view: for each resource, the daily load across all tasks
        // within the requested [from, to) date window. Daily load is computed against
        // the configured WorkCalendar (ADR-009): non-work days return load=0, and
        // each assignment's contribution scales with how much of its [Start, End]
        // window overlaps the day's work-hours band. Marks buckets as overloaded
        // when the resulting load exceeds the resource's CapacityPercent.
        // For non-admin callers, only the caller's own row is returned
        // (seed-scenarios.md §3.4 #3).
        group.MapGet("/load", async (
            DateTime from,
            DateTime to,
            string? departmentId,
            string? projectId,
            ResourceRepository resources,
            AssignmentRepository assignments,
            TaskRepository taskRepo,
            WorkCalendarRepository calendarRepo,
            DepartmentRepository departments,
            ProjectRepository projects,
            UserContext userContext,
            CancellationToken ct) =>
        {
            if (to <= from)
                return Results.BadRequest(new { error = "'to' must be after 'from'" });
            if ((to - from).TotalDays > 366)
                return Results.BadRequest(new { error = "Range must be <= 366 days" });

            var fromDate = DateTime.SpecifyKind(from.Date, DateTimeKind.Utc);
            var toDate = DateTime.SpecifyKind(to.Date, DateTimeKind.Utc);

            var (calendar, isFallback) = await calendarRepo.GetOrFallbackAsync(ct);
            var resourceList = await resources.ListAsync(ct);

            // Matrix axis filters. departmentId picks up the whole subtree
            // so filtering by an org root narrows to "everyone in that
            // org chunk". projectId narrows to the project's explicit
            // member list. Both filters compose (intersect) when both are
            // present — e.g. "engineering people on project X".
            if (!string.IsNullOrEmpty(departmentId))
            {
                var subtreeMembers = await departments.ResourceIdsInSubtreeAsync(departmentId, ct);
                resourceList = resourceList.Where(r => subtreeMembers.Contains(r.Id)).ToList();
            }
            if (!string.IsNullOrEmpty(projectId))
            {
                var project = await projects.GetAsync(projectId, ct);
                if (project is null)
                    return Results.BadRequest(new { error = $"Project {projectId} does not exist" });
                var memberSet = project.MemberResourceIds.ToHashSet();
                resourceList = resourceList.Where(r => memberSet.Contains(r.Id)).ToList();
            }

            // Non-admin → only the caller's own row. Applied AFTER the
            // department/project narrow so a developer asking for
            // "department X" still gets just their own row even if their
            // colleagues are in the same department.
            if (!userContext.IsAdmin && userContext.CurrentUser is not null)
            {
                var meId = userContext.CurrentUser.Id;
                resourceList = resourceList.Where(r => r.Id == meId).ToList();
            }

            var overlapping = await assignments.ListOverlappingAsync(fromDate, toDate, ct);

            // Leaf-only rule: skip assignments whose owning task has any child.
            if (overlapping.Count > 0)
            {
                var affectedTaskIds = overlapping.Select(a => a.TaskId).Distinct();
                var nonLeafIds = await taskRepo.NonLeafIdsAsync(affectedTaskIds, ct);
                if (nonLeafIds.Count > 0)
                    overlapping = overlapping.Where(a => !nonLeafIds.Contains(a.TaskId)).ToList();
            }

            // Pre-bucket per resource and per day, summing fractional contributions.
            var buckets = new Dictionary<string, Dictionary<DateTime, double>>();
            var dailyWork = Math.Max(1, calendar.DailyWorkMinutes); // guard div-by-zero on misconfig

            foreach (var a in overlapping)
            {
                if (!buckets.TryGetValue(a.ResourceId, out var perDay))
                {
                    perDay = new Dictionary<DateTime, double>();
                    buckets[a.ResourceId] = perDay;
                }

                var segStart = a.Start < fromDate ? fromDate : a.Start;
                var segEnd = a.End > toDate.AddDays(1) ? toDate.AddDays(1) : a.End;

                // Walk each calendar day the assignment touches.
                for (var day = DateTime.SpecifyKind(segStart.Date, DateTimeKind.Utc);
                     day < segEnd && day < toDate;
                     day = day.AddDays(1))
                {
                    if (!calendar.IsWorkDay(day.DayOfWeek)) continue;

                    var workStart = day.AddMinutes(calendar.DailyStartMinutes);
                    var workEnd = day.AddMinutes(calendar.DailyEndMinutes);

                    var aDayStart = a.Start > workStart ? a.Start : workStart;
                    var aDayEnd = a.End < workEnd ? a.End : workEnd;

                    var overlapMin = (aDayEnd - aDayStart).TotalMinutes;
                    if (overlapMin <= 0) continue;

                    var contribution = (overlapMin / dailyWork) * a.AllocationPercent;
                    perDay.TryGetValue(day, out var cur);
                    perDay[day] = cur + contribution;
                }
            }

            var result = resourceList.Select(r =>
            {
                buckets.TryGetValue(r.Id, out var perDay);
                var days = new List<ResourceLoadBucket>();
                for (var day = fromDate; day < toDate; day = day.AddDays(1))
                {
                    var isWork = calendar.IsWorkDay(day.DayOfWeek);
                    var load = isWork && perDay is not null && perDay.TryGetValue(day, out var v)
                        ? (int)Math.Round(v)
                        : 0;
                    days.Add(new ResourceLoadBucket(day, load, isWork && load > r.CapacityPercent, isWork));
                }
                return new ResourceLoad(r.Id, r.Name, r.Role, r.DepartmentId, r.CapacityPercent, days);
            }).ToList();

            return Results.Ok(new
            {
                isFallbackCalendar = isFallback,
                workCalendar = new
                {
                    calendar.WorkDays,
                    calendar.DailyStartMinutes,
                    calendar.DailyEndMinutes,
                    calendar.Timezone
                },
                rows = result
            });
        });

        return app;
    }
}

public record ResourceLoadBucket(DateTime Date, int LoadPercent, bool Overloaded, bool IsWorkDay);
public record ResourceLoad(
    string ResourceId,
    string ResourceName,
    string? ResourceRole,
    string? DepartmentId,
    int CapacityPercent,
    List<ResourceLoadBucket> Days);
