import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../models/assignment.dart';
import '../../models/resource.dart';
import '../../models/task_hierarchy.dart';
import '../../models/task_item.dart';
import '../../models/timeline.dart';
import '../../state/providers.dart';

/// Flat tabular list of tasks across all projects, applying the shared
/// filters. Click a row → set TaskInspection + open inspector.
class AllWorkList extends ConsumerWidget {
  const AllWorkList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final agg = ref.watch(allHierarchyByProjectProvider);
    final assignments = ref.watch(allAssignmentsProvider);
    final resources = ref.watch(resourcesProvider);
    final projectFilter = ref.watch(projectFilterProvider);
    final assigneeFilter = ref.watch(assigneeFilterProvider);
    final statusFilter = ref.watch(statusFilterProvider);
    final search = ref.watch(searchQueryProvider).toLowerCase().trim();
    final selected = ref.watch(inspectionProvider);

    if (agg.isLoading || assignments.isLoading || resources.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (agg.hasError) return Center(child: Text('Error: ${agg.error}'));

    final groups = agg.value ?? const <ProjectHierarchy>[];
    final assignmentsByTask = <String, List<Assignment>>{};
    for (final a in assignments.value ?? const <Assignment>[]) {
      assignmentsByTask.putIfAbsent(a.taskId, () => []).add(a);
    }
    final resourceById = {for (final r in (resources.value ?? const <Resource>[])) r.id!: r};

    final rows = _buildRows(
      groups: groups,
      assignmentsByTask: assignmentsByTask,
      resourceById: resourceById,
      projectFilter: projectFilter,
      assigneeFilter: assigneeFilter,
      statusFilter: statusFilter,
      search: search,
    );

    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Text(
            'No tasks match the current filters.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.3)),
      itemBuilder: (ctx, i) {
        final r = rows[i];
        final isSelected = selected is TaskInspection && selected.taskId == r.node.id;
        return _TaskRow(
          row: r,
          isSelected: isSelected,
          onTap: () {
            ref.read(inspectionProvider.notifier).state = TaskInspection(r.node.id);
            ref.read(inspectorOpenProvider.notifier).state = true;
          },
        );
      },
    );
  }

  List<_FlatRow> _buildRows({
    required List<ProjectHierarchy> groups,
    required Map<String, List<Assignment>> assignmentsByTask,
    required Map<String, Resource> resourceById,
    required Set<String> projectFilter,
    required Set<String> assigneeFilter,
    required Set<TaskStatus> statusFilter,
    required String search,
  }) {
    final out = <_FlatRow>[];
    for (final g in groups) {
      if (projectFilter.isNotEmpty && !projectFilter.contains(g.project.id)) continue;
      for (final entry in flattenHierarchy(g.nodes)) {
        final node = entry.$1;
        final depth = entry.$2;

        if (search.isNotEmpty && !node.title.toLowerCase().contains(search)) continue;

        final effStatus = node.hasChildren ? node.computedStatus : node.status;
        if (statusFilter.isNotEmpty && !statusFilter.contains(effStatus)) continue;

        final assigns = assignmentsByTask[node.id] ?? const <Assignment>[];
        final assigneeNames = <String>{};
        for (final a in assigns) {
          final r = resourceById[a.resourceId];
          if (r != null) assigneeNames.add(r.name.trim());
        }

        if (assigneeFilter.isNotEmpty && assigneeNames.intersection(assigneeFilter).isEmpty) {
          continue;
        }

        out.add(_FlatRow(
          node: node,
          depth: depth,
          projectName: g.project.name,
          assignees: assigns
              .map((a) => resourceById[a.resourceId])
              .whereType<Resource>()
              .toList(),
        ));
      }
    }
    return out;
  }
}

class _FlatRow {
  final TaskHierarchyNode node;
  final int depth;
  final String projectName;
  final List<Resource> assignees;
  _FlatRow({required this.node, required this.depth, required this.projectName, required this.assignees});
}

class _TaskRow extends StatelessWidget {
  final _FlatRow row;
  final bool isSelected;
  final VoidCallback onTap;

  const _TaskRow({required this.row, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final node = row.node;
    final df = DateFormat('M/d');
    final timeline = node.hasChildren ? node.computedCurrentTimeline : node.currentTimeline;
    final status = node.hasChildren ? node.computedStatus : node.status;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.5) : null,
        padding: EdgeInsets.fromLTRB(12 + row.depth * 18.0, 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              node.hasChildren ? Icons.folder_open_outlined : Icons.task_alt_outlined,
              size: 16,
              color: node.hasChildren ? theme.colorScheme.primary : theme.colorScheme.outline,
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: Text(
                node.title,
                style: node.hasChildren
                    ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
                    : theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                row.projectName,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 100,
              child: _statusChip(theme, status, aggregated: node.hasChildren),
            ),
            SizedBox(
              width: 140,
              child: _assigneeStrip(theme, row.assignees),
            ),
            SizedBox(
              width: 110,
              child: _timelineCell(theme, timeline, df),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(ThemeData theme, TaskStatus status, {required bool aggregated}) {
    final color = switch (status) {
      TaskStatus.NotStarted => theme.colorScheme.surfaceContainerHighest,
      TaskStatus.InProgress => theme.colorScheme.primaryContainer,
      TaskStatus.Blocked => theme.colorScheme.errorContainer,
      TaskStatus.Done => theme.colorScheme.tertiaryContainer,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(
        aggregated ? '${status.name}*' : status.name,
        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _assigneeStrip(ThemeData theme, List<Resource> resources) {
    if (resources.isEmpty) {
      return Text('—', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline));
    }
    final shown = resources.take(2).toList();
    final extra = resources.length - shown.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...shown.map((r) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _miniChip(theme, r),
            )),
        if (extra > 0)
          Text('+$extra', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
      ],
    );
  }

  Widget _miniChip(ThemeData theme, Resource r) {
    final isAgent = r.kind == ResourceKindFE.agent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isAgent ? Icons.smart_toy_outlined : Icons.person, size: 11),
          const SizedBox(width: 3),
          Text(r.name, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _timelineCell(ThemeData theme, Timeline t, DateFormat df) {
    if (t.isEmpty) {
      return Text('—', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline));
    }
    final s = t.start != null ? df.format(t.start!.toLocal()) : '?';
    final e = t.end != null ? df.format(t.end!.toLocal()) : '?';
    return Text(
      '$s → $e${t.isAllDay ? '' : ' ⏱'}',
      style: theme.textTheme.bodySmall,
    );
  }
}
