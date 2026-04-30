import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/assignment.dart';
import '../../models/resource.dart';
import '../../models/task_hierarchy.dart';
import '../../models/task_item.dart';
import '../../models/timeline.dart';
import '../../state/providers.dart';
import '../gantt_chart.dart';

/// Gantt rendering for All work. Same shared filters as List view, plus a
/// Day / Week / Month zoom toggle (wireframes §4.3.1).
class AllWorkGantt extends ConsumerWidget {
  const AllWorkGantt({super.key});

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
    final zoomIdx = ref.watch(ganttZoomProvider);

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

    final rows = <GanttRow>[];
    for (final g in groups) {
      if (projectFilter.isNotEmpty && !projectFilter.contains(g.project.id)) continue;

      // Filter nodes per assignee/status/search; keep ancestors of any match.
      final filtered = _filterNodes(
        g.nodes,
        assignmentsByTask: assignmentsByTask,
        resourceById: resourceById,
        assigneeFilter: assigneeFilter,
        statusFilter: statusFilter,
        search: search,
      );
      if (filtered.isEmpty) continue;

      // Project group header row spanning the union timeline.
      final span = _projectSpan(filtered);
      rows.add(GanttRow(
        title: '📁 ${g.project.name}',
        depth: 0,
        hasChildren: true,
        origin: const Timeline(),
        current: span,
        real: const Timeline(),
      ));
      for (final entry in flattenHierarchy(filtered)) {
        final node = entry.$1;
        rows.add(GanttRow(
          id: node.id,
          title: node.title,
          depth: entry.$2 + 1,
          hasChildren: node.hasChildren,
          origin: node.hasChildren ? node.computedOriginTimeline : node.originTimeline,
          current: node.hasChildren ? node.computedCurrentTimeline : node.currentTimeline,
          real: node.hasChildren ? node.computedRealTimeline : node.realTimeline,
        ));
      }
    }

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

    final zoom = switch (zoomIdx) { 1 => GanttZoom.week, 2 => GanttZoom.month, _ => GanttZoom.day };
    final selected = ref.watch(inspectionProvider);
    final selectedTaskId = selected is TaskInspection ? selected.taskId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              SegmentedButton<int>(
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: 0, label: Text('Day')),
                  ButtonSegment(value: 1, label: Text('Week')),
                  ButtonSegment(value: 2, label: Text('Month')),
                ],
                selected: {zoomIdx},
                onSelectionChanged: (s) => ref.read(ganttZoomProvider.notifier).state = s.first,
              ),
              const SizedBox(width: 16),
              Wrap(
                spacing: 12,
                children: const [
                  _LegendSwatch(label: 'L1 Origin', role: _SwatchRole.origin),
                  _LegendSwatch(label: 'L2 Current', role: _SwatchRole.current),
                  _LegendSwatch(label: 'L3 Real', role: _SwatchRole.real),
                  _LegendSwatch(label: 'Group', role: _SwatchRole.summary),
                ],
              ),
            ],
          ),
        ),
        Divider(height: 1, color: theme.dividerColor),
        Expanded(
          child: SingleChildScrollView(
            child: GanttChart(
              rows: rows,
              zoom: zoom,
              selectedId: selectedTaskId,
              onRowTap: (id) {
                ref.read(inspectionProvider.notifier).state = TaskInspection(id);
                ref.read(inspectorOpenProvider.notifier).state = true;
              },
            ),
          ),
        ),
      ],
    );
  }

  List<TaskHierarchyNode> _filterNodes(
    List<TaskHierarchyNode> nodes, {
    required Map<String, List<Assignment>> assignmentsByTask,
    required Map<String, Resource> resourceById,
    required Set<String> assigneeFilter,
    required Set<TaskStatus> statusFilter,
    required String search,
  }) {
    if (assigneeFilter.isEmpty && statusFilter.isEmpty && search.isEmpty) return nodes;

    final byId = {for (final n in nodes) n.id: n};
    final matches = <String>{};
    for (final n in nodes) {
      if (search.isNotEmpty && !n.title.toLowerCase().contains(search)) continue;
      if (statusFilter.isNotEmpty &&
          !statusFilter.contains(n.hasChildren ? n.computedStatus : n.status)) {
        continue;
      }
      if (assigneeFilter.isNotEmpty) {
        final assigns = assignmentsByTask[n.id] ?? const <Assignment>[];
        final names = assigns
            .map((a) => resourceById[a.resourceId]?.name.trim())
            .whereType<String>()
            .toSet();
        if (names.intersection(assigneeFilter).isEmpty) continue;
      }
      matches.add(n.id);
    }

    // Add ancestor chain so parents stay visible for context.
    final keep = <String>{};
    for (final id in matches) {
      var cur = byId[id];
      while (cur != null && keep.add(cur.id)) {
        cur = cur.parentTaskId == null ? null : byId[cur.parentTaskId];
      }
    }
    return nodes.where((n) => keep.contains(n.id)).toList();
  }

  Timeline _projectSpan(List<TaskHierarchyNode> nodes) {
    DateTime? min;
    DateTime? max;
    for (final n in nodes) {
      final t = n.hasChildren ? n.computedCurrentTimeline : n.currentTimeline;
      if (t.start != null && (min == null || t.start!.isBefore(min))) min = t.start;
      if (t.end != null && (max == null || t.end!.isAfter(max))) max = t.end;
    }
    return Timeline(start: min, end: max);
  }
}

enum _SwatchRole { origin, current, real, summary }

class _LegendSwatch extends StatelessWidget {
  final String label;
  final _SwatchRole role;
  const _LegendSwatch({required this.label, required this.role});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = switch (role) {
      _SwatchRole.origin => cs.outline.withValues(alpha: 0.45),
      _SwatchRole.current => cs.primary.withValues(alpha: 0.85),
      _SwatchRole.real => cs.tertiary.withValues(alpha: 0.95),
      _SwatchRole.summary => cs.secondary.withValues(alpha: 0.75),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 8, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
