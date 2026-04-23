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
