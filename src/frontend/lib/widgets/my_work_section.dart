import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../models/assignment.dart';
import '../models/resource.dart';
import '../models/task_hierarchy.dart';
import '../models/task_item.dart';
import '../state/providers.dart';

/// Entry-view per wireframes §4.1: lanes per assignee for the current week,
/// plus an Overdue lane. Compact cards lead to the inspector. Plans / Done
/// lanes will land alongside M2.
class MyWorkSection extends ConsumerWidget {
  const MyWorkSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final agg = ref.watch(allHierarchyByProjectProvider);
    final assignments = ref.watch(allAssignmentsProvider);
    final resources = ref.watch(resourcesProvider);
    final selected = ref.watch(inspectionProvider);

    if (agg.isLoading || assignments.isLoading || resources.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (agg.hasError) return Center(child: Text('Error: ${agg.error}'));

    final groups = agg.value ?? const <ProjectHierarchy>[];
    final allAssigns = assignments.value ?? const <Assignment>[];
    final allResources = resources.value ?? const <Resource>[];
    final resourceById = {for (final r in allResources) r.id!: r};

    // Index nodes by id for quick lookup, and gather (resource, task) pairs.
    final nodeById = <String, ({TaskHierarchyNode node, String projectName})>{};
    for (final g in groups) {
      for (final n in g.nodes) {
        nodeById[n.id] = (node: n, projectName: g.project.name);
      }
    }

    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final nextMonday = monday.add(const Duration(days: 7));

    final due = <_AssignmentRow>[];
    final overdue = <_AssignmentRow>[];

    for (final a in allAssigns) {
      final lookup = nodeById[a.taskId];
      if (lookup == null) continue;
      final node = lookup.node;

      // Skip parent rollups (matrix excludes them too).
      if (node.hasChildren) continue;

      final l2 = node.currentTimeline;
      if (l2.isEmpty) continue;

      final row = _AssignmentRow(
        node: node,
        projectName: lookup.projectName,
        assignee: resourceById[a.resourceId],
        allocation: a.allocationPercent,
      );

      if (node.status == TaskStatus.InProgress &&
          l2.end != null &&
          l2.end!.isBefore(today)) {
        overdue.add(row);
        continue;
      }

      // Within current week (Mon..nextMon, exclusive end)?
      if (l2.start != null && l2.end != null) {
        final overlaps = l2.start!.isBefore(nextMonday) && l2.end!.isAfter(monday);
        if (overlaps) due.add(row);
      }
    }

    final df = DateFormat.yMMMd();
    final weekLabel =
        '${df.format(monday.toLocal())} — ${df.format(nextMonday.subtract(const Duration(days: 1)).toLocal())}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          'Due this week  ·  $weekLabel',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (due.isEmpty)
          _emptyLane(theme, 'Nothing scheduled this week.')
        else
          ..._byAssignee(due).entries.map((e) => _Lane(
                title: e.key,
                rows: e.value,
                selected: selected,
                onTap: (id) {
                  ref.read(inspectionProvider.notifier).state = TaskInspection(id);
                  ref.read(inspectorOpenProvider.notifier).state = true;
                },
              )),
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 16, color: theme.colorScheme.error),
            const SizedBox(width: 6),
            Text(
              'Overdue (${overdue.length})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (overdue.isEmpty)
          _emptyLane(theme, 'No overdue tasks.')
        else
          _Lane(
            title: '',
            rows: overdue,
            selected: selected,
            onTap: (id) {
              ref.read(inspectionProvider.notifier).state = TaskInspection(id);
              ref.read(inspectorOpenProvider.notifier).state = true;
            },
            isOverdue: true,
          ),
      ],
    );
  }

  Widget _emptyLane(ThemeData theme, String text) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
      );

  Map<String, List<_AssignmentRow>> _byAssignee(List<_AssignmentRow> rows) {
    final groups = <String, List<_AssignmentRow>>{};
    for (final r in rows) {
      final key = r.assignee?.name ?? '(unassigned)';
      groups.putIfAbsent(key, () => []).add(r);
    }
    final keys = groups.keys.toList()..sort();
    return {for (final k in keys) k: groups[k]!};
  }
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
                    Text(_l2Range(r.node), style: theme.textTheme.bodySmall),
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
        TaskStatus.NotStarted => Icons.radio_button_unchecked,
        TaskStatus.InProgress => Icons.timelapse,
        TaskStatus.Blocked => Icons.block,
        TaskStatus.Done => Icons.check_circle,
      };

  Color _statusColor(ThemeData theme, TaskStatus s) => switch (s) {
        TaskStatus.NotStarted => theme.colorScheme.outline,
        TaskStatus.InProgress => theme.colorScheme.primary,
        TaskStatus.Blocked => theme.colorScheme.error,
        TaskStatus.Done => theme.colorScheme.tertiary,
      };

  String _l2Range(TaskHierarchyNode n) {
    final df = DateFormat('M/d');
    final s = n.currentTimeline.start != null ? df.format(n.currentTimeline.start!.toLocal()) : '?';
    final e = n.currentTimeline.end != null ? df.format(n.currentTimeline.end!.toLocal()) : '?';
    return 'L2 $s → $e';
  }
}
