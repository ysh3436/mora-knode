namespace MoraKnode.Domain;

public enum ProjectStatus
{
    Planning,
    Active,
    OnHold,
    Done,
    Archived
}

// Lifecycle is represented by sparse integer values so future intermediate
// states can slot in without renumbering existing rows. Anchors at 10 / 30
// / 50 (NotStarted / InProgress / Done); intermediate beats (InReview at
// 20, Blocked at 40) sit between them. Terminal-but-not-Done states (51
// Cancelled, 52 Dropped) sit just above Done to read as "alternative
// endings" — Cancelled is an explicit decision to stop, Dropped is passive
// abandonment / deprioritization.
//
// TaskItem.Status is persisted as a string (BsonRepresentation.String) so
// these integer values are *only* a sort/order signal — changing them
// later won't break existing data.
public enum TaskStatus
{
    NotStarted = 10,
    InReview = 20,
    InProgress = 30,
    Blocked = 40,
    Done = 50,
    Cancelled = 51,
    Dropped = 52
}

// Triage signal — "what to pick next" when a queue contains many
// candidates. Anchored at Normal=0 with negative integers for "more
// urgent" and positive for "less urgent" so a *minimum* across children
// naturally surfaces the most urgent active task on the parent row.
// Unset sits well above any real value (100) so it never wins a Min
// comparison unless every child is Unset — no special filter needed in
// the aggregation. Persisted as the enum name (BsonRepresentation.String
// on TaskItem.Priority) so these integers can be reshuffled freely.
public enum TaskPriority
{
    Urgent = -20,
    High = -10,
    Normal = 0,
    Low = 10,
    Unset = 100
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
