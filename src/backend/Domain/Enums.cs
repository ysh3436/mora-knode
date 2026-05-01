namespace MoraKnode.Domain;

public enum ProjectStatus
{
    Planning,
    Active,
    OnHold,
    Done,
    Archived
}

// First four values keep their original integer mapping (0-3) so existing
// persisted tasks deserialize without migration. InReview is the only
// agent-host addition — generic enough to cover any "human review pending"
// situation (ADR-002 agent plan gate, code review, QA, manager approval).
// Other agent lifecycle moments collapse into the existing four:
//   - drafting / approved → reuse NotStarted (no work yet) and InProgress
//     (work begun) respectively; the agent's internal drafting state lives
//     outside mora-knode (ADR-005).
//   - failed → Blocked (both demand human intervention).
//   - cancelled → Done (both are terminal; cancellation reason goes in the
//     task description / change log).
public enum TaskStatus
{
    NotStarted,
    InProgress,
    Blocked,
    Done,
    InReview
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
