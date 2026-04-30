using MongoDB.Bson;
using MongoDB.Driver;
using MoraKnode.Domain;
using MoraKnode.Infrastructure;
using TaskStatus = MoraKnode.Domain.TaskStatus;

namespace MoraKnode.Seeders;

/// <summary>
/// Dev-only fixture loader. Implements docs/design/seed-scenarios.md §3.
/// Today is taken at run time and all dates are computed as offsets from it,
/// so the seeded state is meaningful regardless of when seed is run.
/// </summary>
public class Seeder
{
    private readonly MongoContext _ctx;
    private readonly ProjectRepository _projects;
    private readonly TaskRepository _tasks;
    private readonly ResourceRepository _resources;
    private readonly AssignmentRepository _assignments;
    private readonly MilestoneRepository _milestones;
    private readonly WorkCalendarRepository _calendar;

    public Seeder(
        MongoContext ctx,
        ProjectRepository projects,
        TaskRepository tasks,
        ResourceRepository resources,
        AssignmentRepository assignments,
        MilestoneRepository milestones,
        WorkCalendarRepository calendar)
    {
        _ctx = ctx;
        _projects = projects;
        _tasks = tasks;
        _resources = resources;
        _assignments = assignments;
        _milestones = milestones;
        _calendar = calendar;
    }

    public record SeedSummary(
        int Resources,
        int Projects,
        int Tasks,
        int Assignments,
        int Milestones,
        int ChangeLogs,
        bool Wiped);

    public async Task<SeedSummary> RunAsync(bool wipe, CancellationToken ct = default)
    {
        if (wipe)
        {
            await _ctx.Tasks.DeleteManyAsync(FilterDefinition<TaskItem>.Empty, ct);
            await _ctx.Assignments.DeleteManyAsync(FilterDefinition<Assignment>.Empty, ct);
            await _ctx.Milestones.DeleteManyAsync(FilterDefinition<Milestone>.Empty, ct);
            await _ctx.Resources.DeleteManyAsync(FilterDefinition<Resource>.Empty, ct);
            await _ctx.Projects.DeleteManyAsync(FilterDefinition<Project>.Empty, ct);
            await _ctx.ChangeLogs.DeleteManyAsync(FilterDefinition<ScheduleChangeLog>.Empty, ct);
            await _ctx.WorkCalendars.DeleteManyAsync(FilterDefinition<WorkCalendar>.Empty, ct);
        }
        else
        {
            // Idempotent: if anything is already seeded, no-op.
            var existing = await _ctx.Projects.CountDocumentsAsync(FilterDefinition<Project>.Empty, cancellationToken: ct);
            if (existing > 0) return new SeedSummary(0, 0, 0, 0, 0, 0, false);
        }

        var today = DateTime.UtcNow.Date;
        DateTime dayUtc(int offset) => DateTime.SpecifyKind(today.AddDays(offset), DateTimeKind.Utc);
        DateTime atUtc(int offset, int hour, int minute) =>
            DateTime.SpecifyKind(today.AddDays(offset).AddHours(hour).AddMinutes(minute), DateTimeKind.Utc);

        // 1. WorkCalendar
        await _calendar.UpsertAsync(new WorkCalendar
        {
            WorkDays = WorkDayMask.MonToFri,
            DailyStartMinutes = 9 * 60,
            DailyEndMinutes = 18 * 60,
            Timezone = "Asia/Seoul"
        }, ct);

        // 2. Resources
        var ysh = await _resources.CreateAsync(new Resource
        {
            Name = "ysh", Role = "Owner", CapacityPercent = 100,
            Kind = ResourceKind.Human, Rbac = RbacPreset.Manager
        }, ct);
        var dohyun = await _resources.CreateAsync(new Resource
        {
            Name = "dohyun", Role = "Contributor", CapacityPercent = 100,
            Kind = ResourceKind.Human, Rbac = RbacPreset.Developer
        }, ct);
        var mira = await _resources.CreateAsync(new Resource
        {
            Name = "mira", Role = "QA Lead", CapacityPercent = 80,
            Kind = ResourceKind.Human, Rbac = RbacPreset.Reviewer
        }, ct);
        var junho = await _resources.CreateAsync(new Resource
        {
            Name = "junho", Role = "Tester", CapacityPercent = 60,
            Kind = ResourceKind.Human, Rbac = RbacPreset.QA
        }, ct);
        var dev01 = await _resources.CreateAsync(new Resource
        {
            Name = "dev-01", Role = "implementer", CapacityPercent = 100,
            Kind = ResourceKind.Agent, Rbac = RbacPreset.Developer,
            AgentDescription = "Claude Code based code-writing agent"
        }, ct);
        var researcher01 = await _resources.CreateAsync(new Resource
        {
            Name = "researcher-01", Role = "planner", CapacityPercent = 100,
            Kind = ResourceKind.Agent, Rbac = RbacPreset.Manager,
            AgentDescription = "External research + plan submission agent"
        }, ct);
        var qa01 = await _resources.CreateAsync(new Resource
        {
            Name = "qa-01", Role = "tester", CapacityPercent = 80,
            Kind = ResourceKind.Agent, Rbac = RbacPreset.QA,
            AgentDescription = "Automated regression scenario runner"
        }, ct);

        // 3. Projects
        var pMora = await _projects.CreateAsync(new Project { Name = "mora-knode itself", Description = "dogfooding meta project — M1 redesign", Status = ProjectStatus.Active }, ct);
        var pInternal = await _projects.CreateAsync(new Project { Name = "NilPop internal tools", Description = "small in-house utilities", Status = ProjectStatus.Active }, ct);
        var pAcme = await _projects.CreateAsync(new Project { Name = "ACME consulting", Description = "external client engagement", Status = ProjectStatus.Active }, ct);
        var pSpike = await _projects.CreateAsync(new Project { Name = "Spike: MCP scaffolding", Description = "P0-1 spike, mostly empty", Status = ProjectStatus.Planning }, ct);
        var pLegacy = await _projects.CreateAsync(new Project { Name = "Archived: legacy gantt prototype", Description = "old, kept for archived filter check", Status = ProjectStatus.Archived }, ct);

        // 4. Milestones
        await _milestones.CreateAsync(new Milestone { ProjectId = pMora.Id, Title = "M1 MVP ready", Date = dayUtc(7), Status = MilestoneStatus.Upcoming }, ct);
        await _milestones.CreateAsync(new Milestone { ProjectId = pMora.Id, Title = "M2 Agent host", Date = dayUtc(45), Status = MilestoneStatus.Upcoming }, ct);
        await _milestones.CreateAsync(new Milestone { ProjectId = pInternal.Id, Title = "Slack hook live", Date = dayUtc(3), Status = MilestoneStatus.Upcoming }, ct);
        await _milestones.CreateAsync(new Milestone { ProjectId = pInternal.Id, Title = "Quarterly cleanup", Date = dayUtc(-2), Status = MilestoneStatus.Missed }, ct);
        await _milestones.CreateAsync(new Milestone { ProjectId = pAcme.Id, Title = "Phase 1 delivery", Date = dayUtc(14), Status = MilestoneStatus.Upcoming }, ct);
        await _milestones.CreateAsync(new Milestone { ProjectId = pAcme.Id, Title = "Phase 2 kickoff", Date = dayUtc(30), Status = MilestoneStatus.Upcoming }, ct);
        await _milestones.CreateAsync(new Milestone { ProjectId = pLegacy.Id, Title = "Sunset", Date = dayUtc(-90), Status = MilestoneStatus.Reached }, ct);

        // 5. Tasks — local helper closures
        var changeLogCount = 0;

        async Task<TaskItem> NewTask(
            Project project,
            string title,
            TaskStatus status,
            (int from, int to)? l2 = null,
            (int from, int to)? l3 = null,
            bool l3Timed = false,
            string? parentId = null,
            string? description = null)
        {
            var task = new TaskItem
            {
                ProjectId = project.Id,
                ParentTaskId = parentId,
                Title = title,
                Description = description,
                Status = status
            };
            if (l2 is { } cur)
            {
                task.CurrentTimeline = new Timeline { Start = dayUtc(cur.from), End = dayUtc(cur.to), IsAllDay = true };
            }
            if (l3 is { } real)
            {
                if (l3Timed)
                {
                    task.RealTimeline = new Timeline { Start = atUtc(real.from, 9, 30), End = atUtc(real.to, 17, 30), IsAllDay = false };
                }
                else
                {
                    task.RealTimeline = new Timeline { Start = dayUtc(real.from), End = dayUtc(real.to), IsAllDay = true };
                }
            }
            return await _tasks.CreateAsync(task, ct);
        }

        // mora-knode (8 top + 3 children = 11)
        var t1 = await NewTask(pMora, "Domain model design", TaskStatus.Done, l2: (-7, -2), l3: (-7, -3), l3Timed: true);
        var t2 = await NewTask(pMora, "Backend CRUD endpoints", TaskStatus.Done, l2: (-5, 1), l3: (-5, 0));
        var t3 = await NewTask(pMora, "Frontend foundation", TaskStatus.InProgress, l2: (-3, 5));
        await NewTask(pMora, "Riverpod state setup", TaskStatus.InProgress, l2: (-3, 0), parentId: t3.Id);
        await NewTask(pMora, "Gantt widget v0", TaskStatus.Done, l2: (-3, -1), l3: (-3, -1), parentId: t3.Id);
        await NewTask(pMora, "Calendar week grid", TaskStatus.NotStarted, l2: (2, 5), parentId: t3.Id);
        await NewTask(pMora, "Resource dedupe migration", TaskStatus.Done, l2: (0, 1), l3: (0, 0));
        await NewTask(pMora, "Agent identity + RBAC API", TaskStatus.NotStarted, l2: (5, 15));
        await NewTask(pMora, "Plan gate API", TaskStatus.NotStarted, l2: (10, 20));
        await NewTask(pMora, "Work-queue API", TaskStatus.NotStarted, l2: (10, 25));
        var t8 = await NewTask(pMora, "MCP scaffolding spike", TaskStatus.Blocked, l2: (3, 8),
            description: "Blocked on P0-1 decision");

        // internal-tools (5 top + 2 children + extras = 9)
        var t9 = await NewTask(pInternal, "Slack hook design", TaskStatus.InProgress, l2: (-1, 2));
        // Calendar Week view needs timed L2 to actually exercise the hour grid:
        // these inserts make sure the user sees boxes in the current week.
        await _tasks.CreateAsync(new TaskItem
        {
            ProjectId = pInternal.Id,
            Title = "Daily standup",
            Status = TaskStatus.InProgress,
            CurrentTimeline = new Timeline { Start = atUtc(0, 9, 30), End = atUtc(0, 10, 0), IsAllDay = false }
        }, ct);
        await _tasks.CreateAsync(new TaskItem
        {
            ProjectId = pInternal.Id,
            Title = "Pairing on rollout",
            Status = TaskStatus.NotStarted,
            CurrentTimeline = new Timeline { Start = atUtc(1, 14, 0), End = atUtc(1, 16, 30), IsAllDay = false }
        }, ct);
        await _tasks.CreateAsync(new TaskItem
        {
            ProjectId = pInternal.Id,
            Title = "Customer demo",
            Status = TaskStatus.NotStarted,
            CurrentTimeline = new Timeline { Start = atUtc(2, 11, 0), End = atUtc(2, 12, 0), IsAllDay = false }
        }, ct);
        await NewTask(pInternal, "CSV import script", TaskStatus.Done, l2: (-3, -1), l3: (-3, -1), l3Timed: true);
        await NewTask(pInternal, "Cron job migration", TaskStatus.Done, l2: (-10, -5), l3: (-10, -5));
        var t12 = await NewTask(pInternal, "Cron job rollback", TaskStatus.Done, l2: (-2, 0), l3: (-2, 0));
        var t13 = await NewTask(pInternal, "Quarterly cleanup", TaskStatus.InProgress, l2: (-7, -2));
        await NewTask(pInternal, "Cleanup checklist 1", TaskStatus.Done, l2: (-7, -5), l3: (-7, -5), parentId: t13.Id);
        await NewTask(pInternal, "Cleanup checklist 2", TaskStatus.NotStarted, l2: (-4, -2), parentId: t13.Id);

        // client-acme (6 top + 2 + 1 children = 9)
        await NewTask(pAcme, "Phase 1: Discovery", TaskStatus.Done, l2: (-12, -7), l3: (-12, -7), l3Timed: true);
        var t15 = await NewTask(pAcme, "Phase 1: Design review", TaskStatus.InProgress, l2: (-3, 2));
        var t16 = await NewTask(pAcme, "Phase 1: Implementation", TaskStatus.NotStarted, l2: (5, 13));
        await NewTask(pAcme, "API stubs", TaskStatus.NotStarted, l2: (5, 9), parentId: t16.Id);
        await NewTask(pAcme, "UI components", TaskStatus.NotStarted, l2: (8, 13), parentId: t16.Id);
        var t17 = await NewTask(pAcme, "Phase 1: QA pass", TaskStatus.NotStarted, l2: (13, 14));
        var t18 = await NewTask(pAcme, "Phase 2: Architecture", TaskStatus.NotStarted, l2: (15, 30));
        await NewTask(pAcme, "Spec draft", TaskStatus.NotStarted, l2: (15, 22), parentId: t18.Id);
        await NewTask(pAcme, "Phase 2: Demo", TaskStatus.NotStarted, l2: (30, 30));

        // spike-mcp (1)
        var tSpike = await NewTask(pSpike, "Initial RFC", TaskStatus.NotStarted, l2: (5, 12));

        // archived-legacy (4, all done in distant past)
        await NewTask(pLegacy, "Legacy schema design", TaskStatus.Done, l2: (-120, -100), l3: (-120, -100));
        await NewTask(pLegacy, "Legacy gantt prototype", TaskStatus.Done, l2: (-100, -80), l3: (-100, -80));
        await NewTask(pLegacy, "Legacy retire planning", TaskStatus.Done, l2: (-95, -90), l3: (-95, -90));
        await NewTask(pLegacy, "Legacy sunset", TaskStatus.Done, l2: (-92, -90), l3: (-92, -90));

        // 6. Generate accumulated change logs by replaying updates on selected tasks.
        // Task #12 (Cron rollback) gets 5 timeline tweaks to populate the change log.
        async Task BumpTimeline(TaskItem t, int newEndOffset, string reason, string changedBy)
        {
            var updated = new TaskItem
            {
                Id = t.Id,
                ProjectId = t.ProjectId,
                ParentTaskId = t.ParentTaskId,
                Title = t.Title,
                Description = t.Description,
                Status = t.Status,
                OriginTimeline = t.OriginTimeline,
                CurrentTimeline = new Timeline { Start = t.CurrentTimeline.Start, End = dayUtc(newEndOffset), IsAllDay = true },
                RealTimeline = t.RealTimeline,
                ChangeReason = reason,
                ChangedBy = changedBy
            };
            var saved = await _tasks.ReplaceAsync(t.Id, updated, ct);
            if (saved is not null)
            {
                t.CurrentTimeline = saved.CurrentTimeline;   // mutate caller's copy for chained calls
                changeLogCount += 2;                         // start + end → 2 logs typical, conservative count
            }
        }

        await BumpTimeline(t12, 1, "Rollback hit unexpected lock", "ysh");
        await BumpTimeline(t12, 2, "Re-running on clean replica", "ysh");
        await BumpTimeline(t12, 3, "Verifying parity", "ysh");
        await BumpTimeline(t12, 2, "Done after retest", "ysh");
        await BumpTimeline(t12, 0, "Final sign-off, real same as plan", "ysh");

        // Frontend foundation: 3 revisions
        await BumpTimeline(t3, 6, "Riverpod scope expanded", "ysh");
        await BumpTimeline(t3, 7, "Calendar grid added late", "dohyun");
        await BumpTimeline(t3, 8, "Hot reload friction in week grid", "dohyun");

        // 7. Assignments
        var assigns = new List<Assignment>();
        Assignment A(Resource r, TaskItem t, int alloc, int from, int to) => new()
        {
            ResourceId = r.Id,
            TaskId = t.Id,
            AllocationPercent = alloc,
            Start = dayUtc(from),
            End = dayUtc(to)
        };

        // ysh — overload around today (~today..+3) at >100% across multiple
        // leaf tasks. t3 is a parent (excluded by leaf-only matrix rule), so
        // overload comes from t9, t12, t15, t17 stacking on the same days.
        assigns.Add(A(ysh, t1, 100, -7, -3));
        assigns.Add(A(ysh, t2, 60, -5, 1));
        assigns.Add(A(ysh, t9, 70, -1, 3));          // pushes today/+1/+2 up
        assigns.Add(A(ysh, t12, 40, -2, 1));
        assigns.Add(A(ysh, t15, 50, -3, 3));         // overlaps with t9
        assigns.Add(A(ysh, t17, 30, 13, 14));        // future commitment
        assigns.Add(A(ysh, t8, 50, 3, 8));           // bleeds into next week

        // dohyun — moderate, no overlap on assigned dates
        assigns.Add(A(dohyun, t9, 60, -1, 2));
        assigns.Add(A(dohyun, t13, 50, -7, -2));
        assigns.Add(A(dohyun, t15, 40, -3, 2));
        assigns.Add(A(dohyun, t16, 50, 5, 13));      // future block
        assigns.Add(A(dohyun, t3, 40, 0, 5));        // shares with ysh

        // mira — light review work
        assigns.Add(A(mira, t15, 20, -1, 2));
        assigns.Add(A(mira, t18, 30, 15, 22));

        // junho (QA, 60% capacity)
        assigns.Add(A(junho, t13, 30, -4, -2));
        assigns.Add(A(junho, t17, 60, 13, 14));

        // dev-01 (agent, 100%)
        assigns.Add(A(dev01, t2, 50, -5, 1));
        assigns.Add(A(dev01, t3, 60, -3, 5));
        assigns.Add(A(dev01, t16, 70, 5, 13));

        // researcher-01 (agent, planner)
        assigns.Add(A(researcher01, t8, 80, 3, 8));
        assigns.Add(A(researcher01, tSpike, 100, 5, 12));

        // qa-01
        assigns.Add(A(qa01, t17, 80, 13, 14));

        foreach (var a in assigns)
        {
            await _assignments.CreateAsync(a, ct);
        }

        var assignmentCount = assigns.Count;
        var taskCount = await _ctx.Tasks.CountDocumentsAsync(FilterDefinition<TaskItem>.Empty, cancellationToken: ct);
        var milestoneCount = await _ctx.Milestones.CountDocumentsAsync(FilterDefinition<Milestone>.Empty, cancellationToken: ct);
        var resourceCount = await _ctx.Resources.CountDocumentsAsync(FilterDefinition<Resource>.Empty, cancellationToken: ct);
        var projectCount = await _ctx.Projects.CountDocumentsAsync(FilterDefinition<Project>.Empty, cancellationToken: ct);
        var changeLogActual = await _ctx.ChangeLogs.CountDocumentsAsync(FilterDefinition<ScheduleChangeLog>.Empty, cancellationToken: ct);

        _ = changeLogCount; // placeholder — actual count from DB is more accurate

        return new SeedSummary(
            (int)resourceCount,
            (int)projectCount,
            (int)taskCount,
            assignmentCount,
            (int)milestoneCount,
            (int)changeLogActual,
            wipe);
    }
}
