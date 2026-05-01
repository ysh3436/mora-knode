import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../data/korean_holidays.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/labels.dart';
import '../../models/assignment.dart';
import '../../models/milestone.dart';
import '../../models/resource.dart';
import '../../models/task_item.dart';
import '../../models/work_calendar.dart';
import '../../state/providers.dart';

/// Shared Korean weekday/holiday day-text color rule. Holiday wins over
/// weekday so a holiday-on-Saturday still reads red.
Color? _koreanDayColor(BuildContext context, DateTime date) {
  if (KoreanHolidays.forDate(date) != null) return const Color(0xFFE53935);
  if (date.weekday == DateTime.sunday) return const Color(0xFFE53935);
  if (date.weekday == DateTime.saturday) return const Color(0xFF1976D2);
  return null;
}

/// Bumped by the "Today" button in [TasksCalendar] so the week view's hour
/// grid scrolls to the current time even when the displayed week was already
/// "today" (in which case the anchor wouldn't change and a watcher on the
/// anchor alone would miss the press).
final _weekScrollNowTickerProvider = StateProvider<int>((_) => 0);

/// Calendar view (wireframes §4.4). Two modes:
/// - Month: 6×7 grid, all-day tasks render as full-day chips, timed tasks
///   show with a clock icon.
/// - Week: 7-column grid with an all-day band on top + an hourly time-slot
///   grid below (option b from §8.1). Hour range follows WorkCalendar
///   ±1 hour, with weekend columns dimmed.
///
/// When [scopeProjectId] is set, events are filtered to that project (the
/// project filter chip is hidden in TasksFilters in this mode).
class TasksCalendar extends ConsumerWidget {
  final String? scopeProjectId;
  const TasksCalendar({super.key, this.scopeProjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final mode = ref.watch(calendarModeProvider);
    final anchor = ref.watch(calendarAnchorProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              SegmentedButton<CalendarMode>(
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: [
                  ButtonSegment(value: CalendarMode.month, label: Text(l.calendarMonth)),
                  ButtonSegment(value: CalendarMode.week, label: Text(l.calendarWeek)),
                ],
                selected: {mode},
                onSelectionChanged: (s) => ref.read(calendarModeProvider.notifier).state = s.first,
              ),
              const SizedBox(width: 16),
              IconButton(
                tooltip: l.navPrevious,
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shift(ref, mode, -1),
              ),
              TextButton(
                onPressed: () {
                  final now = DateTime.now();
                  ref.read(calendarAnchorProvider.notifier).state =
                      DateTime(now.year, now.month, now.day);
                  // Tell the week view to scroll its hour grid to "now".
                  // Anchor alone wouldn't fire if the user is already on
                  // today's week, so we bump an explicit ticker.
                  ref.read(_weekScrollNowTickerProvider.notifier).update((v) => v + 1);
                },
                child: Text(l.actionToday),
              ),
              IconButton(
                tooltip: l.navNext,
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _shift(ref, mode, 1),
              ),
              const SizedBox(width: 12),
              Text(
                mode == CalendarMode.month
                    ? DateFormat.yMMMM(dateLocale(context)).format(anchor)
                    : l.calendarWeekOf(DateFormat.yMMMd(dateLocale(context)).format(_mondayOf(anchor))),
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
        ),
        Divider(height: 1, color: theme.dividerColor),
        Expanded(
          child: mode == CalendarMode.month
              ? _MonthView(scopeProjectId: scopeProjectId)
              : _WeekView(scopeProjectId: scopeProjectId),
        ),
      ],
    );
  }

  void _shift(WidgetRef ref, CalendarMode mode, int direction) {
    final cur = ref.read(calendarAnchorProvider);
    DateTime next;
    if (mode == CalendarMode.month) {
      next = DateTime(cur.year, cur.month + direction, 1);
    } else {
      next = cur.add(Duration(days: 7 * direction));
    }
    ref.read(calendarAnchorProvider.notifier).state = next;
  }

  static DateTime _mondayOf(DateTime d) =>
      d.subtract(Duration(days: d.weekday - DateTime.monday));
}

// ============================================================================
// Month view
// ============================================================================

class _MonthView extends ConsumerWidget {
  final String? scopeProjectId;
  const _MonthView({this.scopeProjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final agg = ref.watch(allHierarchyByProjectProvider);
    final assignments = ref.watch(allAssignmentsProvider);
    final resources = ref.watch(resourcesProvider);
    final anchor = ref.watch(calendarAnchorProvider);
    final filters = _Filters.from(ref, scopeProjectId);

    if (agg.isLoading || assignments.isLoading || resources.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (agg.hasError) return Center(child: Text(AppL10n.of(context).errorPrefix(agg.error.toString())));

    final ctx = _CalendarContext.from(
      groups: agg.value ?? const <ProjectHierarchy>[],
      allAssignments: assignments.value ?? const <Assignment>[],
      resources: resources.value ?? const <Resource>[],
      filters: filters,
    );

    final firstOfMonth = DateTime(anchor.year, anchor.month, 1);
    final gridStart = firstOfMonth.subtract(Duration(days: firstOfMonth.weekday - DateTime.monday));
    final today = _todayLocal();

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: List.generate(7, (i) {
              final d = gridStart.add(Duration(days: i));
              // Full weekday name ("월요일", "Monday") per user feedback —
              // short form felt cramped given the cell width.
              final label = DateFormat.EEEE(dateLocale(context)).format(d.toLocal());
              // Sat blue / Sun (or holiday-on-that-Sun-of-grid-start) red —
              // header colors weekday columns so the user reads weekday
              // identity at a glance.
              final headerColor = _koreanDayColor(context, d);
              return Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: headerColor ?? theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          Expanded(
            child: Column(
              children: List.generate(6, (week) {
                return Expanded(
                  child: Row(
                    children: List.generate(7, (dow) {
                      final day = gridStart.add(Duration(days: week * 7 + dow));
                      final inMonth = day.month == anchor.month;
                      return Expanded(
                        child: _MonthCell(
                          day: day,
                          isToday: _sameDay(day, today),
                          inMonth: inMonth,
                          tasks: ctx.tasksOn(day),
                          milestones: ctx.milestonesOn(day),
                          onPick: (taskId) {
                            ref.read(inspectionProvider.notifier).state = TaskInspection(taskId);
                            ref.read(inspectorOpenProvider.notifier).state = true;
                          },
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final bool inMonth;
  final List<_DayTask> tasks;
  final List<Milestone> milestones;
  final void Function(String taskId) onPick;

  const _MonthCell({
    required this.day,
    required this.isToday,
    required this.inMonth,
    required this.tasks,
    required this.milestones,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayLabel = day.day.toString();
    final holiday = KoreanHolidays.forDate(day);
    final koreanColor = _koreanDayColor(context, day);
    const maxRows = 4;
    final shown = tasks.take(maxRows).toList();
    final overflow = tasks.length - shown.length;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
        color: inMonth ? null : theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: isToday
                      ? BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        )
                      : null,
                  child: Text(
                    dayLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      // Today wins (white-on-primary). Otherwise apply
                      // Sat/Sun/holiday Korean color when in-month, dim
                      // grey for out-of-month days.
                      color: isToday
                          ? theme.colorScheme.onPrimary
                          : (inMonth
                              ? (koreanColor ?? theme.colorScheme.onSurface)
                              : theme.colorScheme.outline),
                      fontWeight:
                          (isToday || holiday != null) ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (holiday != null && inMonth) ...[
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      holiday.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: const Color(0xFFE53935),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                ...milestones.take(2).map((m) => Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Tooltip(
                        message: m.title,
                        child: Icon(Icons.flag,
                            size: 11,
                            color: m.status == MilestoneStatus.Missed
                                ? theme.colorScheme.error
                                : theme.colorScheme.tertiary),
                      ),
                    )),
              ],
            ),
            const SizedBox(height: 2),
            ...shown.map((t) => _TaskChip(task: t, onTap: () => onPick(t.id))),
            if (overflow > 0)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  '+$overflow more',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskChip extends StatelessWidget {
  final _DayTask task;
  final VoidCallback onTap;
  const _TaskChip({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = task.isAllDay
        ? theme.colorScheme.primary.withValues(alpha: 0.18)
        : theme.colorScheme.tertiary.withValues(alpha: 0.20);
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            children: [
              if (!task.isAllDay) ...[
                Icon(Icons.access_time, size: 9, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 3),
                Text(
                  task.timeLabel,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: 3),
              ],
              Expanded(
                child: Text(
                  task.title,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Week view — option b: time-slot grid with all-day band on top
// ============================================================================

class _WeekView extends ConsumerStatefulWidget {
  final String? scopeProjectId;
  const _WeekView({this.scopeProjectId});

  static const double _gutterWidth = 64;
  static const double _rowHeight = 36;
  static const double _allDayMaxHeight = 84;

  @override
  ConsumerState<_WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends ConsumerState<_WeekView> {
  final ScrollController _hourScroll = ScrollController();
  bool _initialScrollDone = false;

  @override
  void dispose() {
    _hourScroll.dispose();
    super.dispose();
  }

  /// Center the hour grid on "now" once the layout settles. No-op if the
  /// current minute falls outside the rendered hour band (e.g. user is
  /// browsing at 2 AM but the band is 7–18) — leave the existing scroll
  /// position alone in that case.
  void _scheduleScrollToNow(int startHour, int hourCount) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hourScroll.hasClients) return;
      final now = DateTime.now();
      final minuteInBand = (now.hour - startHour) * 60 + now.minute;
      if (minuteInBand < 0 || minuteInBand > hourCount * 60) return;
      const pixelsPerMinute = _WeekView._rowHeight / 60.0;
      final viewport = _hourScroll.position.viewportDimension;
      if (viewport <= 0) return;
      final target = minuteInBand * pixelsPerMinute - viewport / 2;
      _hourScroll.jumpTo(target.clamp(0.0, _hourScroll.position.maxScrollExtent));
    });
  }

  @override
  Widget build(BuildContext context) {
    final scopeProjectId = widget.scopeProjectId;
    final theme = Theme.of(context);
    final agg = ref.watch(allHierarchyByProjectProvider);
    final assignments = ref.watch(allAssignmentsProvider);
    final resources = ref.watch(resourcesProvider);
    final calendar = ref.watch(workCalendarProvider);
    final anchor = ref.watch(calendarAnchorProvider);
    final filters = _Filters.from(ref, scopeProjectId);

    if (agg.isLoading || assignments.isLoading || resources.isLoading || calendar.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (agg.hasError) return Center(child: Text(AppL10n.of(context).errorPrefix(agg.error.toString())));

    // Anchor → local-Monday-of-that-week (drop UTC kind so it composes with
    // local-keyed task buckets and the user's local "today").
    final localAnchor = DateTime(anchor.year, anchor.month, anchor.day);
    final monday = localAnchor.subtract(Duration(days: localAnchor.weekday - DateTime.monday));
    final today = _todayLocal();

    final ctx = _CalendarContext.from(
      groups: agg.value ?? const <ProjectHierarchy>[],
      allAssignments: assignments.value ?? const <Assignment>[],
      resources: resources.value ?? const <Resource>[],
      filters: filters,
    );

    final cal = calendar.asData?.value.calendar;
    final startHour = cal == null ? 8 : ((cal.dailyStartMinutes - 60) ~/ 60).clamp(0, 22);
    final endHour = cal == null ? 19 : (((cal.dailyEndMinutes + 60) / 60).ceil()).clamp(startHour + 1, 24);
    final hourCount = endHour - startHour;
    final gridHeight = _WeekView._rowHeight * hourCount;
    final pixelsPerMinute = _WeekView._rowHeight / 60.0;

    // First successful build with real layout: center the hour grid on now.
    if (!_initialScrollDone) {
      _initialScrollDone = true;
      _scheduleScrollToNow(startHour, hourCount);
    }
    // "Today" button bumps this ticker — re-center even if anchor was already
    // today (in which case the anchor watcher would never fire).
    ref.listen<int>(_weekScrollNowTickerProvider, (_, _) {
      _scheduleScrollToNow(startHour, hourCount);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row
        _WeekHeaderRow(monday: monday, today: today, gutterWidth: _WeekView._gutterWidth),
        Divider(height: 1, color: theme.dividerColor),
        // All-day band
        _AllDayBand(
          monday: monday,
          today: today,
          ctx: ctx,
          gutterWidth: _WeekView._gutterWidth,
          maxHeight: _WeekView._allDayMaxHeight,
          onPick: (id) => _select(ref, id),
        ),
        Divider(height: 1, color: theme.dividerColor),
        // Hour grid: gutter (time labels) + day stack
        Expanded(
          child: SingleChildScrollView(
            controller: _hourScroll,
            child: SizedBox(
              height: gridHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: _WeekView._gutterWidth,
                    child: _HourGutter(startHour: startHour, hourCount: hourCount, rowHeight: _WeekView._rowHeight),
                  ),
                  Expanded(
                    child: _DayGrid(
                      monday: monday,
                      ctx: ctx,
                      cal: cal,
                      startHour: startHour,
                      hourCount: hourCount,
                      rowHeight: _WeekView._rowHeight,
                      pixelsPerMinute: pixelsPerMinute,
                      onPick: (id) => _select(ref, id),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _select(WidgetRef ref, String id) {
    ref.read(inspectionProvider.notifier).state = TaskInspection(id);
    ref.read(inspectorOpenProvider.notifier).state = true;
  }
}

class _WeekHeaderRow extends StatelessWidget {
  final DateTime monday;
  final DateTime today;
  final double gutterWidth;
  const _WeekHeaderRow({required this.monday, required this.today, required this.gutterWidth});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(width: gutterWidth),
        for (var i = 0; i < 7; i++) ...[
          Expanded(
            child: () {
              final d = monday.add(Duration(days: i));
              final isToday = _sameDay(d, today);
              final isWeekend = d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
              final holiday = KoreanHolidays.forDate(d);
              final dayColor = _koreanDayColor(context, d);
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                decoration: BoxDecoration(
                  // Today wins over weekend tint — the same primary tint
                  // continues through the all-day band and hour grid below
                  // so the column reads as one block.
                  color: isToday
                      ? theme.colorScheme.primary.withValues(alpha: 0.10)
                      : (isWeekend ? theme.colorScheme.surfaceContainerLow : null),
                  border: Border(left: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5))),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Full weekday name to match the month-view header.
                    Text(
                      DateFormat.EEEE(dateLocale(context)).format(d.toLocal()),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: dayColor ?? theme.colorScheme.outline,
                      ),
                    ),
                    // Day number + (optional) holiday name beside it — same
                    // pattern as the month cells.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          d.day.toString(),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                            // Today (primary blue) overrides; otherwise the
                            // Sat/Sun/holiday Korean cue.
                            color: isToday ? theme.colorScheme.primary : dayColor,
                          ),
                        ),
                        if (holiday != null) ...[
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              holiday.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: const Color(0xFFE53935),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            }(),
          ),
        ],
      ],
    );
  }
}

class _AllDayBand extends StatelessWidget {
  final DateTime monday;
  final DateTime today;
  final _CalendarContext ctx;
  final double gutterWidth;
  final double maxHeight;
  final void Function(String id) onPick;
  const _AllDayBand({
    required this.monday,
    required this.today,
    required this.ctx,
    required this.gutterWidth,
    required this.maxHeight,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: gutterWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Text(
                'all-day',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
          ),
          for (var i = 0; i < 7; i++) ...[
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _sameDay(monday.add(Duration(days: i)), today)
                      ? theme.colorScheme.primary.withValues(alpha: 0.10)
                      : null,
                  border: Border(left: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4))),
                ),
                padding: const EdgeInsets.all(2),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: ctx
                        .tasksOn(monday.add(Duration(days: i)))
                        .where((t) => t.isAllDay)
                        .map((t) => _TaskChip(task: t, onTap: () => onPick(t.id)))
                        .toList(),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HourGutter extends StatelessWidget {
  final int startHour;
  final int hourCount;
  final double rowHeight;
  const _HourGutter({required this.startHour, required this.hourCount, required this.rowHeight});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: List.generate(hourCount, (h) {
        return SizedBox(
          height: rowHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 4, 0),
            child: Text(
              _hourLabel(startHour + h),
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        );
      }),
    );
  }

  static String _hourLabel(int h) {
    final hh = h % 24;
    if (hh == 0) return '12 AM';
    if (hh == 12) return '12 PM';
    if (hh < 12) return '$hh AM';
    return '${hh - 12} PM';
  }
}

class _DayGrid extends StatelessWidget {
  final DateTime monday;
  final _CalendarContext ctx;
  final WorkCalendar? cal;
  final int startHour;
  final int hourCount;
  final double rowHeight;
  final double pixelsPerMinute;
  final void Function(String id) onPick;

  const _DayGrid({
    required this.monday,
    required this.ctx,
    required this.cal,
    required this.startHour,
    required this.hourCount,
    required this.rowHeight,
    required this.pixelsPerMinute,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gridHeight = rowHeight * hourCount;

    return LayoutBuilder(
      builder: (ctx2, constraints) {
        final colWidth = constraints.maxWidth / 7;

        // Build positioned timed task widgets.
        final timedBoxes = <Widget>[];
        for (var i = 0; i < 7; i++) {
          final day = monday.add(Duration(days: i));
          for (final t in ctx.tasksOn(day).where((t) => !t.isAllDay)) {
            final start = (t.startMinutesOfDay ?? 0) - startHour * 60;
            final end = (t.endMinutesOfDay ?? hourCount * 60) - startHour * 60;
            // Clamp to visible band, recompute height from clamped values.
            final visibleStart = start.clamp(0, hourCount * 60);
            final visibleEnd = end.clamp(0, hourCount * 60);
            if (visibleEnd - visibleStart < 1) continue;

            timedBoxes.add(Positioned(
              left: i * colWidth + 1,
              top: visibleStart * pixelsPerMinute,
              width: colWidth - 2,
              height: ((visibleEnd - visibleStart) * pixelsPerMinute).clamp(16, gridHeight),
              child: _TimedTaskBox(task: t, onTap: () => onPick(t.id)),
            ));
          }
        }

        // Current-time line: only when "today" lands in the displayed week
        // and the current minute falls inside the rendered hour band.
        Widget? nowLine;
        final now = DateTime.now();
        final todayLocal = DateTime(now.year, now.month, now.day);
        final weekEnd = monday.add(const Duration(days: 7));
        if (!todayLocal.isBefore(monday) && todayLocal.isBefore(weekEnd)) {
          final dayIndex = todayLocal.difference(monday).inDays;
          final minuteInBand = (now.hour - startHour) * 60 + now.minute;
          if (minuteInBand >= 0 && minuteInBand <= hourCount * 60) {
            final y = minuteInBand * pixelsPerMinute;
            nowLine = Positioned(
              top: y - 1,
              left: dayIndex * colWidth,
              width: colWidth,
              height: 2,
              child: Container(color: theme.colorScheme.error.withValues(alpha: 0.7)),
            );
          }
        }

        // Today column tint — drawn under the grid + bars so the timed-task
        // boxes stay readable on top. Continues the same primary tint used
        // by the header and all-day band so the column reads as one block.
        Widget? todayColumn;
        if (!todayLocal.isBefore(monday) && todayLocal.isBefore(weekEnd)) {
          final dayIndex = todayLocal.difference(monday).inDays;
          todayColumn = Positioned(
            top: 0,
            bottom: 0,
            left: dayIndex * colWidth,
            width: colWidth,
            child: Container(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
            ),
          );
        }

        return Stack(
          children: [
            ?todayColumn,
            // background grid: hour rows × 7 day cells
            Column(
              children: List.generate(hourCount, (h) {
                final hour = startHour + h;
                final atWorkBoundary = cal != null &&
                    ((hour * 60) == cal!.dailyStartMinutes || (hour * 60) == cal!.dailyEndMinutes);
                return SizedBox(
                  height: rowHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: List.generate(7, (i) {
                      final d = monday.add(Duration(days: i));
                      final isWeekend = d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
                      return Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            // Skip the weekend tint on today's column so the
                            // primary tint above doesn't get muddied.
                            color: isWeekend && !_sameDay(d, todayLocal)
                                ? theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.3)
                                : null,
                            border: Border(
                              left: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
                              top: BorderSide(
                                color: atWorkBoundary
                                    ? theme.colorScheme.primary.withValues(alpha: 0.4)
                                    : theme.dividerColor.withValues(alpha: 0.2),
                                width: atWorkBoundary ? 1.5 : 1.0,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
            ...timedBoxes,
            ?nowLine,
          ],
        );
      },
    );
  }
}

class _TimedTaskBox extends StatelessWidget {
  final _DayTask task;
  final VoidCallback onTap;
  const _TimedTaskBox({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.timeLabel,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.colorScheme.onTertiaryContainer)),
              Text(
                task.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Shared filtering + per-day task computation
// ============================================================================

class _Filters {
  final Set<String> projectFilter;
  final Set<String> assigneeFilter;
  final Set<TaskStatus> statusFilter;
  final String search;

  _Filters({
    required this.projectFilter,
    required this.assigneeFilter,
    required this.statusFilter,
    required this.search,
  });

  /// Reads the shared filter providers. When [scopeProjectId] is non-null the
  /// project filter is forced to that one project regardless of the global
  /// projectFilterProvider state.
  factory _Filters.from(WidgetRef ref, String? scopeProjectId) => _Filters(
        projectFilter: scopeProjectId != null
            ? <String>{scopeProjectId}
            : ref.watch(projectFilterProvider),
        assigneeFilter: ref.watch(assigneeFilterProvider),
        statusFilter: ref.watch(statusFilterProvider),
        search: ref.watch(searchQueryProvider).toLowerCase().trim(),
      );
}

class _DayTask {
  final String id;
  final String title;
  final bool isAllDay;
  final int? startMinutesOfDay;
  final int? endMinutesOfDay;
  final String timeLabel;

  _DayTask({
    required this.id,
    required this.title,
    required this.isAllDay,
    required this.startMinutesOfDay,
    required this.endMinutesOfDay,
    required this.timeLabel,
  });
}

class _CalendarContext {
  // Keys are local-time DateTime(y, m, d) (kind=Unspecified). Both all-day and
  // timed tasks land here under the *displayed* day in the user's local zone.
  final Map<DateTime, List<_DayTask>> tasksByDay;
  final Map<DateTime, List<Milestone>> milestonesByDay;

  _CalendarContext({required this.tasksByDay, required this.milestonesByDay});

  factory _CalendarContext.from({
    required List<ProjectHierarchy> groups,
    required List<Assignment> allAssignments,
    required List<Resource> resources,
    required _Filters filters,
  }) {
    final assignmentsByTask = <String, List<Assignment>>{};
    for (final a in allAssignments) {
      assignmentsByTask.putIfAbsent(a.taskId, () => []).add(a);
    }
    final resourceById = {for (final r in resources) r.id!: r};

    final tasksByDay = <DateTime, List<_DayTask>>{};

    for (final g in groups) {
      if (filters.projectFilter.isNotEmpty && !filters.projectFilter.contains(g.project.id)) continue;
      for (final node in g.nodes) {
        if (node.hasChildren) continue; // leaf only
        if (filters.search.isNotEmpty && !node.title.toLowerCase().contains(filters.search)) continue;
        if (filters.statusFilter.isNotEmpty && !filters.statusFilter.contains(node.status)) continue;
        if (filters.assigneeFilter.isNotEmpty) {
          final assigns = assignmentsByTask[node.id] ?? const <Assignment>[];
          final names = assigns
              .map((a) => resourceById[a.resourceId]?.name.trim())
              .whereType<String>()
              .toSet();
          if (names.intersection(filters.assigneeFilter).isEmpty) continue;
        }

        final t = node.currentTimeline;
        if (t.isEmpty || t.start == null || t.end == null) continue;
        final isAllDay = t.isAllDay;

        if (isAllDay) {
          // ADR-009: all-day tasks store as 00:00:00..23:59:59.999 UTC of the
          // user-entered date. The UTC y/m/d IS the displayed date (don't
          // convert to local — that would shift by the UTC offset and split
          // the task across two local days).
          final fromKey = DateTime(t.start!.year, t.start!.month, t.start!.day);
          final toKey = DateTime(t.end!.year, t.end!.month, t.end!.day);
          for (var day = fromKey; !day.isAfter(toKey); day = day.add(const Duration(days: 1))) {
            tasksByDay.putIfAbsent(day, () => []).add(_DayTask(
                  id: node.id,
                  title: node.title,
                  isAllDay: true,
                  startMinutesOfDay: null,
                  endMinutesOfDay: null,
                  timeLabel: '',
                ));
          }
        } else {
          // Timed: convert to user's local zone, then bucket and compute
          // minutes-of-day in local time so the hour grid lines up with the
          // user's clock.
          final localStart = t.start!.toLocal();
          final localEnd = t.end!.toLocal();
          final fromKey = DateTime(localStart.year, localStart.month, localStart.day);
          final toKey = DateTime(localEnd.year, localEnd.month, localEnd.day);
          final timeLabel = DateFormat.Hm().format(localStart);

          for (var day = fromKey; !day.isAfter(toKey); day = day.add(const Duration(days: 1))) {
            final dayStart = day;
            final dayEnd = day.add(const Duration(days: 1));
            final s = localStart.isAfter(dayStart) ? localStart : dayStart;
            final e = localEnd.isBefore(dayEnd) ? localEnd : dayEnd;
            final startMin = s.difference(day).inMinutes;
            final endMin = e.difference(day).inMinutes;
            if (endMin <= startMin) continue;

            tasksByDay.putIfAbsent(day, () => []).add(_DayTask(
                  id: node.id,
                  title: node.title,
                  isAllDay: false,
                  startMinutesOfDay: startMin,
                  endMinutesOfDay: endMin,
                  timeLabel: timeLabel,
                ));
          }
        }
      }
    }

    return _CalendarContext(
      tasksByDay: tasksByDay,
      milestonesByDay: const {},
    );
  }

  List<_DayTask> tasksOn(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return tasksByDay[key] ?? const [];
  }

  List<Milestone> milestonesOn(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return milestonesByDay[key] ?? const [];
  }
}

/// Local-time midnight for "today" — used as the anchor for "is today" cells
/// and for week-of-anchor math. Always non-UTC so it composes with task day
/// keys (also local DateTime).
DateTime _todayLocal() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
