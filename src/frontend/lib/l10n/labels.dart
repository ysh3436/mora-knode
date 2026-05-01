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
    TaskStatus.NotStarted => l.taskStatusNotStarted,
    TaskStatus.InProgress => l.taskStatusInProgress,
    TaskStatus.Blocked => l.taskStatusBlocked,
    TaskStatus.Done => l.taskStatusDone,
    TaskStatus.InReview => l.taskStatusInReview,
  };
}

/// Background tint for status pills / chips. Centralized so the inspector,
/// task list, and my-work view can't drift apart. InReview uses the
/// secondary container to draw the eye — the user has a pending decision.
Color taskStatusBg(ThemeData theme, TaskStatus status) => switch (status) {
      TaskStatus.NotStarted => theme.colorScheme.surfaceContainerHighest,
      TaskStatus.InProgress => theme.colorScheme.primaryContainer,
      TaskStatus.Blocked => theme.colorScheme.errorContainer,
      TaskStatus.Done => theme.colorScheme.tertiaryContainer,
      TaskStatus.InReview => theme.colorScheme.secondaryContainer,
    };

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
