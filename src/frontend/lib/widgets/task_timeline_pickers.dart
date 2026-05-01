import 'package:flutter/material.dart';

import '../models/timeline.dart';

// Material's date / range pickers default to full-screen on web, which
// dwarfs the rest of the inspector. These wrappers constrain them to a
// compact dialog footprint that fits beside other UI without covering it.
const _kCompactPickerMaxWidth = 420.0;
const _kCompactPickerMaxHeight = 560.0;
const _kCompactRangeMaxWidth = 720.0;
const _kCompactRangeMaxHeight = 600.0;

TransitionBuilder _compactPickerBuilder({double? maxWidth, double? maxHeight}) {
  return (BuildContext _, Widget? child) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth ?? _kCompactPickerMaxWidth,
            maxHeight: maxHeight ?? _kCompactPickerMaxHeight,
          ),
          child: child,
        ),
      );
}

/// All-day range picker. Returns a [Timeline] with isAllDay=true normalized
/// to UTC midnight, or null if the user cancels. Used by both the inspector
/// inline edit (existing tasks) and the draft panel (new tasks).
Future<Timeline?> pickAllDayTimeline(BuildContext context, Timeline current) async {
  final now = DateTime.now();
  final picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(now.year - 1),
    lastDate: DateTime(now.year + 3),
    initialDateRange: (current.start != null && current.end != null)
        ? DateTimeRange(start: current.start!.toLocal(), end: current.end!.toLocal())
        : null,
    builder: _compactPickerBuilder(
      maxWidth: _kCompactRangeMaxWidth,
      maxHeight: _kCompactRangeMaxHeight,
    ),
  );
  if (picked == null) return null;
  return Timeline(
    start: DateTime.utc(picked.start.year, picked.start.month, picked.start.day),
    end: DateTime.utc(picked.end.year, picked.end.month, picked.end.day),
    isAllDay: true,
  );
}

/// Timed range picker — sequential start-date / start-time / end-date /
/// end-time prompts. Each is wrapped in the compact dialog so none covers
/// the surrounding UI.
Future<Timeline?> pickTimedTimeline(BuildContext context, Timeline current) async {
  final initStart = current.start?.toLocal() ?? DateTime.now();
  final initEnd = current.end?.toLocal() ?? initStart.add(const Duration(hours: 1));
  final compactBuilder = _compactPickerBuilder();

  if (!context.mounted) return null;
  final startDate = await showDatePicker(
    context: context,
    firstDate: DateTime(initStart.year - 1),
    lastDate: DateTime(initStart.year + 3),
    initialDate: initStart,
    helpText: 'Start date',
    builder: compactBuilder,
  );
  if (startDate == null) return null;

  if (!context.mounted) return null;
  final startTime = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initStart),
    helpText: 'Start time',
    initialEntryMode: TimePickerEntryMode.input,
  );
  if (startTime == null) return null;

  if (!context.mounted) return null;
  final endDate = await showDatePicker(
    context: context,
    firstDate: startDate,
    lastDate: DateTime(startDate.year + 3),
    initialDate: initEnd.isBefore(startDate) ? startDate : initEnd,
    helpText: 'End date',
    builder: compactBuilder,
  );
  if (endDate == null) return null;

  if (!context.mounted) return null;
  final endTime = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initEnd),
    helpText: 'End time',
    initialEntryMode: TimePickerEntryMode.input,
  );
  if (endTime == null) return null;

  final start = DateTime(startDate.year, startDate.month, startDate.day, startTime.hour, startTime.minute).toUtc();
  final end = DateTime(endDate.year, endDate.month, endDate.day, endTime.hour, endTime.minute).toUtc();
  if (!end.isAfter(start)) return null;
  return Timeline(start: start, end: end, isAllDay: false);
}
