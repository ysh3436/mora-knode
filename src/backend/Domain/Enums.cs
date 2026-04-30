namespace MoraKnode.Domain;

public enum ProjectStatus
{
    Planning,
    Active,
    OnHold,
    Done,
    Archived
}

public enum TaskStatus
{
    NotStarted,
    InProgress,
    Blocked,
    Done
}

public enum MilestoneStatus
{
    Upcoming,
    Reached,
    Missed
}

public enum ChangeEntityType
{
    Project,
    Task,
    Milestone
}

// ADR-004 / ADR-009: Resources distinguish humans from agents and carry an
// RBAC preset that gates UI affordances and the data scope returned to a
// given caller.

public enum ResourceKind
{
    Human,
    Agent
}

public enum RbacPreset
{
    Manager,
    Reviewer,
    Developer,
    QA,
    Human
}

[Flags]
public enum WorkDayMask
{
    None = 0,
    Mon = 1 << 0,
    Tue = 1 << 1,
    Wed = 1 << 2,
    Thu = 1 << 3,
    Fri = 1 << 4,
    Sat = 1 << 5,
    Sun = 1 << 6,
    MonToFri = Mon | Tue | Wed | Thu | Fri,
    All = MonToFri | Sat | Sun
}
