import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../l10n/app_localizations.dart';
import '../l10n/labels.dart';
import '../models/assignment.dart';
import '../models/resource.dart';
import '../models/task_hierarchy.dart';
import '../models/task_item.dart';
import '../state/providers.dart';

/// Entry-view per wireframes §4.1: "what does the current user have on
/// their plate." Filters strictly to the active dev-mode user (or
/// shows everyone when anonymous, since that's the only way an admin
/// without a chosen identity can see something useful here).
class MyWorkSection extends ConsumerWidget {
  const MyWorkSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final agg = ref.watch(allHierarchyByProjectProvider);
    final assignments = ref.watch(allAssignmentsProvider);
    final resources = ref.watch(resourcesProvider);
    final currentUser = ref.watch(currentUserProvider);
    final selected = ref.watch(inspectionProvider);

    if (agg.isLoading || assignments.isLoading || resources.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (agg.hasError) return Center(child: Text(l.errorPrefix(agg.error.toString())));

    final groups = agg.value ?? const <ProjectHierarchy>[];
    final allAssigns = assignments.value ?? const <Assignment>[];
    final allResources = resources.value ?? const <Resource>[];
    final resourceById = {for (final r in allResources) r.id!: r};

    final nodeById = <String, ({TaskHierarchyNode node, String projectName})>{};
    for (final g in groups) {
      for (final n in g.nodes) {
        nodeById[n.id] = (node: n, projectName: g.project.name);
      }
    }

    // Local-time week boundaries so "this week" matches the user's clock.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - DateTime.monday));
    final nextMonday = monday.add(const Duration(days: 7));
    final weekAfter = nextMonday.add(const Duration(days: 7));

    final thisWeek = <_AssignmentRow>[];
    final nextWeek = <_AssignmentRow>[];
    final overdue = <_AssignmentRow>[];

    for (final a in allAssigns) {
      // Filter to the current user (when one is selected). Anonymous shows
      // everyone — admins without a chosen identity still get a usable view.
      if (currentUser != null && a.resourceId != currentUser.id) continue;

      final lookup = nodeById[a.taskId];
      if (lookup == null) continue;
      final node = lookup.node;
      if (node.hasChildren) continue;

      final l2 = node.currentTimeline;
      if (l2.isEmpty || l2.start == null || l2.end == null) continue;

      final row = _AssignmentRow(
        node: node,
        projectName: lookup.projectName,
        assignee: resourceById[a.resourceId],
        allocation: a.allocationPercent,
      );

      if (node.status == TaskStatus.InProgress && l2.end!.isBefore(today)) {
        overdue.add(row);
        continue;
      }

      // Bucket by week using all-day-aware date math: an all-day task's UTC
      // y/m/d is the displayed date, so compare against y/m/d directly.
      final startKey = l2.isAllDay
          ? DateTime(l2.start!.year, l2.start!.month, l2.start!.day)
          : DateTime(l2.start!.toLocal().year, l2.start!.toLocal().month, l2.start!.toLocal().day);
      final endKey = l2.isAllDay
          ? DateTime(l2.end!.year, l2.end!.month, l2.end!.day)
          : DateTime(l2.end!.toLocal().year, l2.end!.toLocal().month, l2.end!.toLocal().day);

      if (startKey.isBefore(nextMonday) && !endKey.isBefore(monday)) {
        thisWeek.add(row);
      } else if (startKey.isBefore(weekAfter) && !endKey.isBefore(nextMonday)) {
        nextWeek.add(row);
      }
    }

    final df = DateFormat.yMMMd(dateLocale(context));
    String rangeLabel(DateTime from, DateTime to) =>
        '${df.format(from)} — ${df.format(to.subtract(const Duration(days: 1)))}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (currentUser == null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: theme.colorScheme.outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.myWorkBannerNoUser,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        Text(
          '${l.myWorkLaneThisWeek}  ·  ${rangeLabel(monday, nextMonday)}',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (thisWeek.isEmpty)
          _emptyLane(theme, l.myWorkEmptyThisWeek)
        else
          _Lane(
            title: '',
            rows: thisWeek,
            selected: selected,
            onTap: (id) => _open(ref, id),
          ),
        const SizedBox(height: 24),
        Text(
          '${l.myWorkLaneNextWeek}  ·  ${rangeLabel(nextMonday, weekAfter)}',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (nextWeek.isEmpty)
          _emptyLane(theme, l.myWorkEmptyNextWeek)
        else
          _Lane(
            title: '',
            rows: nextWeek,
            selected: selected,
            onTap: (id) => _open(ref, id),
          ),
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 16, color: theme.colorScheme.error),
            const SizedBox(width: 6),
            Text(
              l.myWorkLaneOverdue(overdue.length),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (overdue.isEmpty)
          _emptyLane(theme, l.myWorkEmptyOverdue)
        else
          _Lane(
            title: '',
            rows: overdue,
            selected: selected,
            onTap: (id) => _open(ref, id),
            isOverdue: true,
          ),
      ],
    );
  }

  void _open(WidgetRef ref, String id) {
    ref.read(inspectionProvider.notifier).state = TaskInspection(id);
    ref.read(inspectorOpenProvider.notifier).state = true;
  }

  Widget _emptyLane(ThemeData theme, String text) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
      );
}

class _AssignmentRow {
  final TaskHierarchyNode node;
  final String projectName;
  final Resource? assignee;
  final int allocation;
  _AssignmentRow({
    required this.node,
    required this.projectName,
    required this.assignee,
    required this.allocation,
  });
}

class _Lane extends StatelessWidget {
  final String title;
  final List<_AssignmentRow> rows;
  final Inspection? selected;
  final void Function(String taskId) onTap;
  final bool isOverdue;

  const _Lane({
    required this.title,
    required this.rows,
    required this.selected,
    required this.onTap,
    this.isOverdue = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isOverdue
              ? theme.colorScheme.error.withValues(alpha: 0.4)
              : theme.dividerColor,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  Icon(
                    rows.first.assignee?.kind == ResourceKindFE.agent
                        ? Icons.smart_toy_outlined
                        : Icons.person,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  if (rows.first.assignee?.rbac != null)
                    Text(
                      rows.first.assignee!.rbac.label,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                  const Spacer(),
                  Text('${rows.length}', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ...rows.map((r) {
            final isSelected = selected is TaskInspection && (selected as TaskInspection).taskId == r.node.id;
            return InkWell(
              onTap: () => onTap(r.node.id),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                color: isSelected ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.5) : null,
                child: Row(
                  children: [
                    Icon(_statusIcon(r.node.status), size: 14, color: _statusColor(theme, r.node.status)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(r.node.title, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      r.projectName,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                    const SizedBox(width: 12),
                    Text(_l2Range(context, r.node), style: theme.textTheme.bodySmall),
                    const SizedBox(width: 8),
                    Text(
                      '${r.allocation}%',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  IconData _statusIcon(TaskStatus s) => switch (s) {
        TaskStatus.Created => Icons.radio_button_unchecked,
        TaskStatus.Planning => Icons.edit_note,
        TaskStatus.PlanReview => Icons.fact_check_outlined,
        TaskStatus.InProgress => Icons.timelapse,
        TaskStatus.WorkReview => Icons.rate_review_outlined,
        TaskStatus.OnHold => Icons.pause_circle_outline,
        TaskStatus.Done => Icons.check_circle,
        TaskStatus.Cancelled => Icons.cancel_outlined,
        TaskStatus.Dropped => Icons.do_not_disturb_on_outlined,
      };

  Color _statusColor(ThemeData theme, TaskStatus s) => switch (s) {
        TaskStatus.Created => theme.colorScheme.outline,
        TaskStatus.Planning => theme.colorScheme.outlineVariant,
        TaskStatus.PlanReview => theme.colorScheme.tertiary,
        TaskStatus.InProgress => theme.colorScheme.primary,
        TaskStatus.WorkReview => theme.colorScheme.secondary,
        TaskStatus.OnHold => theme.colorScheme.error,
        TaskStatus.Done => theme.colorScheme.tertiary,
        TaskStatus.Cancelled => theme.colorScheme.outline,
        TaskStatus.Dropped => theme.colorScheme.outlineVariant,
      };

  String _l2Range(BuildContext context, TaskHierarchyNode n) {
    final df = DateFormat('M/d', dateLocale(context));
    final s = n.currentTimeline.start != null ? df.format(n.currentTimeline.start!.toLocal()) : '?';
    final e = n.currentTimeline.end != null ? df.format(n.currentTimeline.end!.toLocal()) : '?';
    return 'L2 $s → $e';
  }
}
