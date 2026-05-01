namespace MoraKnode.Domain;

/// <summary>
/// Pure domain rule for rolling up a parent task's status from its
/// children. Used both by the read path (TaskHierarchyEndpoints fills
/// ComputedStatus) and the write path (TaskRepository persists it on
/// the parent so DB and UI stay in sync).
/// </summary>
public static class StatusAggregator
{
    /// <summary>
    /// All-terminal → Done. Any Blocked → Blocked. Any active or Done
    /// (mixed-progress) → InProgress. All NotStarted → NotStarted. Any
    /// awaiting review → InReview. Empty → NotStarted (defensive).
    /// </summary>
    public static TaskStatus Aggregate(IReadOnlyList<TaskStatus> statuses)
    {
        if (statuses.Count == 0) return TaskStatus.NotStarted;
        if (statuses.All(s => s == TaskStatus.Done
                           || s == TaskStatus.Cancelled
                           || s == TaskStatus.Dropped))
            return TaskStatus.Done;
        if (statuses.Any(s => s == TaskStatus.Blocked)) return TaskStatus.Blocked;
        if (statuses.Any(s => s == TaskStatus.InProgress || s == TaskStatus.Done))
            return TaskStatus.InProgress;
        if (statuses.Any(s => s == TaskStatus.InReview)) return TaskStatus.InReview;
        return TaskStatus.NotStarted;
    }
}
