import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../l10n/app_localizations.dart';
import '../l10n/labels.dart';
import '../models/department.dart';
import '../models/project.dart';
import '../models/resource_load.dart';
import '../state/providers.dart';

/// Resource matrix heatmap (wireframes §4.5). Rows are resources, columns are
/// days of the selected week. Cell color tracks load% relative to the
/// resource capacity (green / yellow / red). Non-work days fall back to
/// "—" gray. Header shows the active WorkCalendar (or "24/7" fallback).
class MatrixSection extends ConsumerWidget {
  const MatrixSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final anchor = ref.watch(matrixAnchorProvider);
    final monday = anchor.subtract(Duration(days: anchor.weekday - DateTime.monday));
    final departmentId = ref.watch(matrixDepartmentFilterProvider);
    final projectId = ref.watch(matrixProjectFilterProvider);
    final range = MatrixRange(
      monday,
      monday.add(const Duration(days: 7)),
      departmentId: departmentId,
      projectId: projectId,
    );
    final matrix = ref.watch(matrixLoadProvider(range));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          monday: monday,
          calendar: matrix.asData?.value.workCalendar,
          isFallback: matrix.asData?.value.isFallbackCalendar ?? false,
          onPrev: () => ref.read(matrixAnchorProvider.notifier).state =
              monday.subtract(const Duration(days: 7)),
          onNext: () => ref.read(matrixAnchorProvider.notifier).state =
              monday.add(const Duration(days: 7)),
          onToday: () {
            final n = DateTime.now().toUtc();
            final today = DateTime.utc(n.year, n.month, n.day);
            ref.read(matrixAnchorProvider.notifier).state =
                today.subtract(Duration(days: today.weekday - DateTime.monday));
          },
          onSettings: () => ref.read(appSectionProvider.notifier).state = AppSection.settings,
        ),
        Divider(height: 1, color: theme.dividerColor),
        const _FilterBar(),
        Divider(height: 1, color: theme.dividerColor),
        Expanded(
          child: matrix.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(l.errorPrefix(e.toString()))),
            data: (resp) {
              if (resp.rows.isEmpty) {
                final hasFilter = departmentId != null || projectId != null;
                return Center(
                  child: Text(
                    hasFilter ? l.matrixEmptyFiltered : l.matrixEmpty,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                  ),
                );
              }
              return _Grid(monday: monday, response: resp);
            },
          ),
        ),
      ],
    );
  }
}

/// Department + project narrow-down dropdowns. Lives just under the
/// week navigator so the active scope is always visible without a
/// separate sidebar.
class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final departments = ref.watch(departmentsProvider).asData?.value ?? const <Department>[];
    final projects = ref.watch(projectsProvider).asData?.value ?? const <Project>[];
    final deptId = ref.watch(matrixDepartmentFilterProvider);
    final projId = ref.watch(matrixProjectFilterProvider);
    final hasFilter = deptId != null || projId != null;
    // Guard against the brief window where the providers are still
    // loading (departments/projects = empty) but the filter state is
    // already set from a prior session: feeding initialValue = id with
    // no matching item trips Flutter's DropdownButton assertion. Pass
    // null in that case; the real value re-binds once the list lands.
    final deptInitial = deptId != null && departments.any((d) => d.id == deptId) ? deptId : null;
    final projInitial = projId != null && projects.any((p) => p.id == projId) ? projId : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String?>(
              initialValue: deptInitial,
              isDense: true,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l.matrixFilterDepartment,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(l.matrixFilterAll)),
                for (final d in _sortedDepartments(departments))
                  if (d.id != null)
                    DropdownMenuItem<String?>(
                      value: d.id,
                      child: Text(_departmentDisplay(d, departments), overflow: TextOverflow.ellipsis),
                    ),
              ],
              onChanged: (v) =>
                  ref.read(matrixDepartmentFilterProvider.notifier).state = v,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String?>(
              initialValue: projInitial,
              isDense: true,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l.matrixFilterProject,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(l.matrixFilterAll)),
                for (final p in projects)
                  if (p.id != null)
                    DropdownMenuItem<String?>(
                      value: p.id,
                      child: Text(p.name, overflow: TextOverflow.ellipsis),
                    ),
              ],
              onChanged: (v) =>
                  ref.read(matrixProjectFilterProvider.notifier).state = v,
            ),
          ),
          if (hasFilter) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              icon: const Icon(Icons.clear, size: 16),
              onPressed: () {
                ref.read(matrixDepartmentFilterProvider.notifier).state = null;
                ref.read(matrixProjectFilterProvider.notifier).state = null;
              },
              label: Text(l.matrixFilterClear),
            ),
          ],
          const Spacer(),
          if (hasFilter)
            Text(
              l.matrixFilterActiveHint,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
        ],
      ),
    );
  }

  /// Sort by parent-path so children sit immediately under their parents
  /// in the dropdown, mimicking a tree without giving up the simple flat
  /// menu widget. Stable for cycles-prevented department graphs.
  List<Department> _sortedDepartments(List<Department> all) {
    final byId = {for (final d in all) d.id ?? '': d};
    String pathFor(Department d) {
      final segments = <String>[];
      var current = d;
      // 6-deep guard so a malformed graph can't loop forever (cycles
      // are blocked by the backend repository, but defence in depth).
      for (var i = 0; i < 6; i++) {
        segments.insert(0, current.name);
        final pid = current.parentDepartmentId;
        if (pid == null) break;
        final p = byId[pid];
        if (p == null) break;
        current = p;
      }
      return segments.join(' / ');
    }

    final sorted = [...all]..sort((a, b) => pathFor(a).compareTo(pathFor(b)));
    return sorted;
  }

  String _departmentDisplay(Department d, List<Department> all) {
    final byId = {for (final dd in all) dd.id ?? '': dd};
    final segments = <String>[];
    var current = d;
    for (var i = 0; i < 6; i++) {
      segments.insert(0, current.name);
      final pid = current.parentDepartmentId;
      if (pid == null) break;
      final p = byId[pid];
      if (p == null) break;
      current = p;
    }
    return segments.join(' / ');
  }
}

class _Header extends StatelessWidget {
  final DateTime monday;
  final WorkCalendarSummary? calendar;
  final bool isFallback;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onSettings;

  const _Header({
    required this.monday,
    required this.calendar,
    required this.isFallback,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final df = DateFormat('MMM d', dateLocale(context));
    final sunday = monday.add(const Duration(days: 6));
    final calLabel = isFallback || calendar == null
        ? l.matrixWorkCalendarFallback
        : '${calendar!.workDays} · '
            '${_hhmm(calendar!.dailyStartMinutes)}–${_hhmm(calendar!.dailyEndMinutes)}'
            ' · ${calendar!.timezone}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          IconButton(tooltip: l.navPreviousWeek, icon: const Icon(Icons.chevron_left), onPressed: onPrev),
          TextButton(onPressed: onToday, child: Text(l.actionToday)),
          IconButton(tooltip: l.navNextWeek, icon: const Icon(Icons.chevron_right), onPressed: onNext),
          const SizedBox(width: 12),
          Text(
            l.calendarWeekOf('${df.format(monday.toLocal())} — ${df.format(sunday.toLocal())}'),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isFallback
                  ? theme.colorScheme.surfaceContainerHighest
                  : theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              l.matrixWorkCalendarLabel(calLabel),
              style: theme.textTheme.bodySmall,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: l.matrixEditCalendar,
            icon: const Icon(Icons.settings_outlined, size: 18),
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }

  static String _hhmm(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}

class _Grid extends StatelessWidget {
  final DateTime monday;
  final MatrixLoadResponse response;
  const _Grid({required this.monday, required this.response});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(80),
        columnWidths: const {0: FixedColumnWidth(180)},
        border: TableBorder.all(color: theme.dividerColor.withValues(alpha: 0.5)),
        children: [
          TableRow(
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow),
            children: [
              _HeaderCell(label: AppL10n.of(context).matrixHeaderResource, alignLeft: true),
              for (var i = 0; i < 7; i++)
                _HeaderCell(label: DateFormat('E\nM/d', dateLocale(context)).format(monday.add(Duration(days: i)).toLocal())),
            ],
          ),
          for (final row in response.rows)
            TableRow(children: [
              _ResourceCell(name: row.resourceName, role: row.resourceRole, capacity: row.capacityPercent),
              for (final bucket in row.days) _LoadCell(bucket: bucket, capacity: row.capacityPercent),
            ]),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final bool alignLeft;
  const _HeaderCell({required this.label, this.alignLeft = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(
        label,
        textAlign: alignLeft ? TextAlign.left : TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ResourceCell extends StatelessWidget {
  final String name;
  final String? role;
  final int capacity;
  const _ResourceCell({required this.name, required this.role, required this.capacity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          if (role != null)
            Text(
              '$role · cap $capacity%',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
        ],
      ),
    );
  }
}

class _LoadCell extends StatelessWidget {
  final ResourceLoadBucket bucket;
  final int capacity;
  const _LoadCell({required this.bucket, required this.capacity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!bucket.isWorkDay) {
      return Container(
        height: 44,
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.4),
        alignment: Alignment.center,
        child: Text('—', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
      );
    }

    final ratio = capacity > 0 ? bucket.loadPercent / capacity : 0.0;
    final (Color bg, Color fg) = switch (ratio) {
      < 0.6 => (theme.colorScheme.tertiaryContainer.withValues(alpha: 0.6), theme.colorScheme.onTertiaryContainer),
      < 1.0 => (theme.colorScheme.primaryContainer, theme.colorScheme.onPrimaryContainer),
      _ => (theme.colorScheme.errorContainer, theme.colorScheme.onErrorContainer),
    };

    return Container(
      height: 44,
      color: bg,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${bucket.loadPercent}%',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: bucket.overloaded ? FontWeight.w700 : FontWeight.w500,
              color: fg,
            ),
          ),
          if (bucket.overloaded) ...[
            const SizedBox(width: 4),
            Icon(Icons.warning_amber_rounded, size: 14, color: fg),
          ],
        ],
      ),
    );
  }
}
