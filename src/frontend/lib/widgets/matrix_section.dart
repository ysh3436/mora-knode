import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

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
    final anchor = ref.watch(matrixAnchorProvider);
    final monday = anchor.subtract(Duration(days: anchor.weekday - DateTime.monday));
    final range = MatrixRange(monday, monday.add(const Duration(days: 7)));
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
        Expanded(
          child: matrix.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (resp) {
              if (resp.rows.isEmpty) {
                return Center(
                  child: Text(
                    'No resources visible.',
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
    final df = DateFormat('MMM d');
    final sunday = monday.add(const Duration(days: 6));
    final calLabel = isFallback || calendar == null
        ? '24/7 fallback'
        : '${calendar!.workDays} · '
            '${_hhmm(calendar!.dailyStartMinutes)}–${_hhmm(calendar!.dailyEndMinutes)}'
            ' · ${calendar!.timezone}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          IconButton(tooltip: 'Previous week', icon: const Icon(Icons.chevron_left), onPressed: onPrev),
          TextButton(onPressed: onToday, child: const Text('today')),
          IconButton(tooltip: 'Next week', icon: const Icon(Icons.chevron_right), onPressed: onNext),
          const SizedBox(width: 12),
          Text(
            'Week of ${df.format(monday.toLocal())} — ${df.format(sunday.toLocal())}',
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
              'WorkCalendar: $calLabel',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Edit calendar',
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
              const _HeaderCell(label: 'Resource', alignLeft: true),
              for (var i = 0; i < 7; i++)
                _HeaderCell(label: DateFormat('E\nM/d').format(monday.add(Duration(days: i)).toLocal())),
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
