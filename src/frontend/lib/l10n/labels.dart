import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../models/task_item.dart';
import 'app_localizations.dart';

/// Localized display label for a [TaskStatus]. Use this anywhere we previously
/// printed `status.name`, so the stored enum stays English (= API contract,
/// ADR-009) while the UI honors the active locale.
String taskStatusLabel(BuildContext context, TaskStatus status) {
  final l = AppL10n.of(context);
  return switch (status) {
    TaskStatus.Created => l.taskStatusCreated,
    TaskStatus.Planning => l.taskStatusPlanning,
    TaskStatus.PlanReview => l.taskStatusPlanReview,
    TaskStatus.InProgress => l.taskStatusInProgress,
    TaskStatus.WorkReview => l.taskStatusWorkReview,
    TaskStatus.OnHold => l.taskStatusOnHold,
    TaskStatus.Done => l.taskStatusDone,
    TaskStatus.Cancelled => l.taskStatusCancelled,
    TaskStatus.Dropped => l.taskStatusDropped,
  };
}

/// Background tint for status pills / chips. Centralized so the inspector,
/// task list, and my-work view can't drift apart.
/// Reviews use distinctive containers (PlanReview tertiary, WorkReview
/// secondary) so manager-action-needed rows pop. OnHold uses the error
/// tint as a strong "sidelined" cue. Cancelled / Dropped fall to the
/// lowest neutral surfaces so out-of-flight rows recede.
Color taskStatusBg(ThemeData theme, TaskStatus status) => switch (status) {
      TaskStatus.Created => theme.colorScheme.surfaceContainerHighest,
      TaskStatus.Planning => theme.colorScheme.surfaceContainerHigh,
      TaskStatus.PlanReview => theme.colorScheme.tertiaryContainer,
      TaskStatus.InProgress => theme.colorScheme.primaryContainer,
      TaskStatus.WorkReview => theme.colorScheme.secondaryContainer,
      TaskStatus.OnHold => theme.colorScheme.errorContainer,
      TaskStatus.Done => theme.colorScheme.tertiaryContainer,
      TaskStatus.Cancelled => theme.colorScheme.surfaceContainerLow,
      TaskStatus.Dropped => theme.colorScheme.surfaceContainerLowest,
    };

/// Localized display label for a [TaskPriority]. Same pattern as
/// [taskStatusLabel] — keeps the API enum stable while letting the UI
/// follow the active locale.
String taskPriorityLabel(BuildContext context, TaskPriority priority) {
  final l = AppL10n.of(context);
  return switch (priority) {
    TaskPriority.Unset => l.taskPriorityUnset,
    TaskPriority.Low => l.taskPriorityLow,
    TaskPriority.Normal => l.taskPriorityNormal,
    TaskPriority.High => l.taskPriorityHigh,
    TaskPriority.Urgent => l.taskPriorityUrgent,
  };
}

/// Background tint for priority pills. Centralized alongside the status
/// helpers so the inspector and tasks list can't drift apart. Urgent
/// borrows the error tint to read as a strong "do this first" cue;
/// Unset falls to the lowest neutral so unranked rows recede.
Color taskPriorityBg(ThemeData theme, TaskPriority priority) => switch (priority) {
      TaskPriority.Unset => theme.colorScheme.surfaceContainerLowest,
      TaskPriority.Low => theme.colorScheme.surfaceContainerLow,
      TaskPriority.Normal => theme.colorScheme.secondaryContainer,
      TaskPriority.High => theme.colorScheme.tertiaryContainer,
      TaskPriority.Urgent => theme.colorScheme.errorContainer,
    };

/// Direction-arrow icon set so urgency reads at a glance even before the
/// label is parsed.
IconData taskPriorityIcon(TaskPriority priority) => switch (priority) {
      TaskPriority.Unset => Icons.remove,
      TaskPriority.Low => Icons.keyboard_double_arrow_down,
      TaskPriority.Normal => Icons.drag_handle,
      TaskPriority.High => Icons.keyboard_double_arrow_up,
      TaskPriority.Urgent => Icons.priority_high,
    };

/// Same as [taskPriorityLabel] but with the same "computed from children"
/// marker the status display uses, so parent rows visually distinguish an
/// aggregated priority from a directly-set one.
String taskPriorityDisplay(
  BuildContext context,
  TaskPriority priority, {
  required bool aggregated,
}) {
  final base = taskPriorityLabel(context, priority);
  return aggregated ? AppL10n.of(context).taskStatusAggregatedSuffix(base) : base;
}

/// Same as [taskStatusLabel] but with the "computed from children" marker
/// when [aggregated] is true.
String taskStatusDisplay(
  BuildContext context,
  TaskStatus status, {
  required bool aggregated,
}) {
  final base = taskStatusLabel(context, status);
  return aggregated ? AppL10n.of(context).taskStatusAggregatedSuffix(base) : base;
}

/// IETF tag (e.g. `ko`, `en`) for the active locale. Pass into [DateFormat]
/// constructors so month/day labels follow the user's language.
String dateLocale(BuildContext context) =>
    Localizations.localeOf(context).toLanguageTag();

/// Localized short label for a day-of-week stored as the English code used
/// in [WorkDays.ordered] (`Mon`, `Tue`, ...). Resolves via [DateFormat.E] so
/// the label tracks the active locale.
String workDayLabel(BuildContext context, String mondayCode) {
  // Reference dates: Jan 1 2024 was a Monday, so we walk forward by index.
  const order = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final idx = order.indexOf(mondayCode);
  if (idx < 0) return mondayCode;
  return DateFormat.E(dateLocale(context)).format(DateTime(2024, 1, 1 + idx));
}
