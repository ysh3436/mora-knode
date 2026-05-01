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
    /// Rules in priority order:
    ///   1. All terminal (Done/Cancelled/Dropped) → Done
    ///   2. Any OnHold child → OnHold (sidelined dominates)
    ///   3. Any review-waiting (PlanReview/WorkReview) → that value
    ///      (surfaces "manager action needed" up the tree)
    ///   4. Any active (Planning/InProgress) or Done (mixed) → InProgress
    ///   5. All Created → Created
    ///   6. Default → Created (defensive, also covers empty)
    /// IsWaiting is orthogonal and not aggregated here.
    /// </summary>
    public static TaskStatus Aggregate(IReadOnlyList<TaskStatus> statuses)
    {
        if (statuses.Count == 0) return TaskStatus.Created;
        if (statuses.All(s => s == TaskStatus.Done
                           || s == TaskStatus.Cancelled
                           || s == TaskStatus.Dropped))
            return TaskStatus.Done;
        if (statuses.Any(s => s == TaskStatus.OnHold)) return TaskStatus.OnHold;
        if (statuses.Any(s => s == TaskStatus.PlanReview)) return TaskStatus.PlanReview;
        if (statuses.Any(s => s == TaskStatus.WorkReview)) return TaskStatus.WorkReview;
        if (statuses.Any(s => s == TaskStatus.Planning
                           || s == TaskStatus.InProgress
                           || s == TaskStatus.Done))
            return TaskStatus.InProgress;
        return TaskStatus.Created;
    }
}
