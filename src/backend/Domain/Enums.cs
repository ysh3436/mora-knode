namespace MoraKnode.Domain;

public enum ProjectStatus
{
    Planning,
    Active,
    OnHold,
    Done,
    Archived
}

// 9-step lifecycle for matrix PM + agent collaboration. Sparse integer
// values keep room for future intermediate states. Order reflects the
// happy-path flow Created → Planning → PlanReview → InProgress →
// WorkReview → Done, with OnHold (sidelined) / Cancelled (calendar-stage
// kill) / Dropped (post-effort kill — kept for audit/learning) as
// alternative endings.
//
// Picker exposes 7 of 9: Planning and PlanReview are bot-driven entry
// points (set when the bot starts planning / submits an AgentPlan), so
// surfacing them in the user picker would invite meaningless manual
// transitions. The remaining 7 are the user-facing knobs.
//
// All transitions are actor-driven (user or bot via API). The backend
// never moves a task forward on its own (ADR-005).
//
// TaskItem.Status is persisted as a string (BsonRepresentation.String) so
// these integer values are *only* a sort/order signal — changing them
// later won't break existing data.
public enum TaskStatus
{
    Created     = 10,
    Planning    = 20,
    PlanReview  = 30,
    InProgress  = 40,
    WorkReview  = 50,
    OnHold      = 60,
    Done        = 70,
    Cancelled   = 71,
    Dropped     = 72
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
