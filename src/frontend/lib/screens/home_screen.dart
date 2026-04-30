import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../models/assignment.dart';
import '../models/project.dart';
import '../models/resource.dart';
import '../models/task_hierarchy.dart';
import '../models/timeline.dart';
import '../state/providers.dart';
import '../widgets/gantt_chart.dart';
import '../widgets/task_editor.dart';
import 'matrix_screen.dart';
import 'project_screen.dart';
import 'resources_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mora Knode'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'All Tasks', icon: Icon(Icons.list_alt_outlined)),
              Tab(text: 'All Gantt', icon: Icon(Icons.view_timeline_outlined)),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Matrix load',
              icon: const Icon(Icons.grid_view),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MatrixScreen()),
              ),
            ),
            IconButton(
              tooltip: 'Resources',
              icon: const Icon(Icons.people_alt_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ResourcesScreen()),
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(projectsProvider);
                ref.invalidate(allHierarchyByProjectProvider);
                ref.invalidate(allAssignmentsProvider);
                ref.invalidate(resourcesProvider);
              },
            ),
          ],
        ),
        body: const Column(
          children: [
            _FilterBar(),
            Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: [
                  _AllTasksTab(),
                  _AllGanttTab(),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('New project'),
          onPressed: () => _openCreateProjectDialog(context, ref),
        ),
      ),
    );
  }

  Future<void> _openCreateProjectDialog(BuildContext context, WidgetRef ref) async {
    final nameC = TextEditingController();
    final descC = TextEditingController();
    var status = ProjectStatus.Planning;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('New project'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameC,
                  decoration: const InputDecoration(labelText: 'Name *'),
                  autofocus: true,
                ),
                TextField(
                  controller: descC,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ProjectStatus>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: ProjectStatus.values
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) => setState(() => status = v ?? status),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (nameC.text.trim().isEmpty) return;
                await ref.read(apiClientProvider).createProject(Project(
                      name: nameC.text.trim(),
                      description: descC.text.trim().isEmpty ? null : descC.text.trim(),
                      status: status,
                    ));
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (created == true) {
      ref.invalidate(projectsProvider);
      ref.invalidate(allHierarchyByProjectProvider);
    }
  }
}

// ============================================================================
// Filter bar — shared across both tabs via projectFilterProvider /
// assigneeFilterProvider state. Empty selection means "show all".
// ============================================================================

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider).asData?.value ?? const <Project>[];
    final resources = ref.watch(resourcesProvider).asData?.value ?? const <Resource>[];
    final projectFilter = ref.watch(projectFilterProvider);
    final assigneeFilter = ref.watch(assigneeFilterProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          _MultiSelectChip(
            icon: Icons.folder_outlined,
            label: 'Projects',
            allEmpty: projectFilter.isEmpty,
            selectedCount: projectFilter.length,
            options: projects
                .where((p) => p.id != null)
                .map((p) => (id: p.id!, label: p.name))
                .toList(),
            selected: projectFilter,
            onChanged: (s) => ref.read(projectFilterProvider.notifier).state = s,
          ),
          const SizedBox(width: 8),
          _MultiSelectChip(
            icon: Icons.person_outline,
            label: 'Assignees',
            allEmpty: assigneeFilter.isEmpty,
            selectedCount: assigneeFilter.length,
            // Group resources by name as a safety net: even if duplicates slipped
            // past the backend uniqueness guard, surface each name once. The
            // filter is keyed by name (not id) so semantically equivalent
            // duplicates collapse together.
            options: _dedupeResourcesByName(resources),
            selected: assigneeFilter,
            onChanged: (s) => ref.read(assigneeFilterProvider.notifier).state = s,
          ),
          const SizedBox(width: 8),
          if (projectFilter.isNotEmpty || assigneeFilter.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Clear'),
              onPressed: () {
                ref.read(projectFilterProvider.notifier).state = <String>{};
                ref.read(assigneeFilterProvider.notifier).state = <String>{};
              },
            ),
          const Spacer(),
          Text(
            '${projects.length} projects · ${resources.length} resources',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Build filter options for assignees: one entry per distinct trimmed name.
/// If multiple Resource records share the same name, append a "×N" suffix so
/// the duplication is visible to the user. The option id is the name itself —
/// downstream filter checks key on resource.name, not resource.id.
List<({String id, String label})> _dedupeResourcesByName(List<Resource> resources) {
  final counts = <String, int>{};
  for (final r in resources) {
    final name = r.name.trim();
    if (name.isEmpty) continue;
    counts[name] = (counts[name] ?? 0) + 1;
  }
  final names = counts.keys.toList()..sort();
  return names
      .map((n) => (id: n, label: counts[n]! > 1 ? '$n  ×${counts[n]}' : n))
      .toList();
}

class _MultiSelectChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool allEmpty;
  final int selectedCount;
  final List<({String id, String label})> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const _MultiSelectChip({
    required this.icon,
    required this.label,
    required this.allEmpty,
    required this.selectedCount,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Filter by $label',
      itemBuilder: (ctx) => options
          .map((o) => CheckedPopupMenuItem<String>(
                value: o.id,
                checked: selected.contains(o.id),
                child: Text(o.label, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onSelected: (id) {
        final next = Set<String>.from(selected);
        if (next.contains(id)) {
          next.remove(id);
        } else {
          next.add(id);
        }
        onChanged(next);
      },
      child: InputChip(
        avatar: Icon(icon, size: 18),
        label: Text(allEmpty ? '$label: all' : '$label ($selectedCount)'),
        onDeleted: allEmpty ? null : () => onChanged(<String>{}),
      ),
    );
  }
}

// ============================================================================
// All Tasks tab — projects as collapsible groups, tasks as expandable rows.
// Inline expansion shows three timeline rows + assignee chips + edit/delete.
// ============================================================================

class _AllTasksTab extends ConsumerWidget {
  const _AllTasksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agg = ref.watch(allHierarchyByProjectProvider);
    final assignments = ref.watch(allAssignmentsProvider);
    final resources = ref.watch(resourcesProvider);
    final projectFilter = ref.watch(projectFilterProvider);
    final assigneeFilter = ref.watch(assigneeFilterProvider);

    if (agg.isLoading || assignments.isLoading || resources.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (agg.hasError) return Center(child: Text('Error: ${agg.error}'));
    if (assignments.hasError) return Center(child: Text('Error: ${assignments.error}'));
    if (resources.hasError) return Center(child: Text('Error: ${resources.error}'));

    final groups = agg.value ?? const <ProjectHierarchy>[];
    final assignmentList = assignments.value ?? const <Assignment>[];
    final resourceList = resources.value ?? const <Resource>[];

    if (groups.isEmpty) {
      return const Center(child: Text('No projects yet. Tap + to create one.'));
    }

    final assignmentsByTask = <String, List<Assignment>>{};
    for (final a in assignmentList) {
      assignmentsByTask.putIfAbsent(a.taskId, () => []).add(a);
    }
    final resourceById = {for (final r in resourceList) r.id!: r};

    final visible = _applyFilters(
      groups: groups,
      projectFilter: projectFilter,
      assigneeFilter: assigneeFilter,
      assignmentsByTask: assignmentsByTask,
      resourceById: resourceById,
    );

    if (visible.isEmpty) {
      return const Center(child: Text('No tasks match the current filters.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: visible.length,
      itemBuilder: (context, i) {
        final group = visible[i];
        return _ProjectGroup(
          project: group.project,
          visibleNodes: group.nodes,
          allNodes: groups
              .firstWhere((g) => g.project.id == group.project.id)
              .nodes,
          assignmentsByTask: assignmentsByTask,
          resourceById: resourceById,
        );
      },
    );
  }

  List<ProjectHierarchy> _applyFilters({
    required List<ProjectHierarchy> groups,
    required Set<String> projectFilter,
    required Set<String> assigneeFilter,
    required Map<String, List<Assignment>> assignmentsByTask,
    required Map<String, Resource> resourceById,
  }) {
    final out = <ProjectHierarchy>[];
    for (final g in groups) {
      if (projectFilter.isNotEmpty && !projectFilter.contains(g.project.id)) {
        continue;
      }
      List<TaskHierarchyNode> nodes = g.nodes;
      if (assigneeFilter.isNotEmpty) {
        // Keep nodes whose own assignments OR any descendant's assignments
        // intersect the assignee filter (matched by resource name, so any
        // duplicate Resource rows sharing a name collapse together).
        final matching = <String>{};
        for (final n in g.nodes) {
          final assigns = assignmentsByTask[n.id] ?? const <Assignment>[];
          if (assigns.any((a) {
            final name = resourceById[a.resourceId]?.name.trim();
            return name != null && assigneeFilter.contains(name);
          })) {
            matching.add(n.id);
          }
        }
        final byId = {for (final n in g.nodes) n.id: n};
        final keep = <String>{};
        for (final id in matching) {
          var cur = byId[id];
          while (cur != null) {
            if (!keep.add(cur.id)) break;
            cur = cur.parentTaskId == null ? null : byId[cur.parentTaskId];
          }
        }
        nodes = g.nodes.where((n) => keep.contains(n.id)).toList();
      }
      if (nodes.isEmpty) continue;
      out.add((project: g.project, nodes: nodes));
    }
    return out;
  }
}

class _ProjectGroup extends ConsumerStatefulWidget {
  final Project project;
  final List<TaskHierarchyNode> visibleNodes;
  final List<TaskHierarchyNode> allNodes;
  final Map<String, List<Assignment>> assignmentsByTask;
  final Map<String, Resource> resourceById;

  const _ProjectGroup({
    required this.project,
    required this.visibleNodes,
    required this.allNodes,
    required this.assignmentsByTask,
    required this.resourceById,
  });

  @override
  ConsumerState<_ProjectGroup> createState() => _ProjectGroupState();
}

class _ProjectGroupState extends ConsumerState<_ProjectGroup> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flat = flattenHierarchy(widget.visibleNodes);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  Icon(_expanded ? Icons.expand_more : Icons.chevron_right, size: 20),
                  const SizedBox(width: 4),
                  Icon(Icons.folder_outlined, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.project.name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusChip(label: widget.project.status.name),
                  const SizedBox(width: 8),
                  Text(
                    '${flat.length} task${flat.length == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall,
                  ),
                  IconButton(
                    tooltip: 'Open project',
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProjectScreen(
                          projectId: widget.project.id!,
                          projectName: widget.project.name,
                        ),
                      ));
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            if (flat.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No tasks.', textAlign: TextAlign.center),
              )
            else
              ...flat.map((entry) => _TaskTile(
                    node: entry.$1,
                    depth: entry.$2,
                    projectId: widget.project.id!,
                    siblings: widget.allNodes,
                    assignments: widget.assignmentsByTask[entry.$1.id] ?? const [],
                    resourceById: widget.resourceById,
                  )),
          ],
        ],
      ),
    );
  }
}

class _TaskTile extends ConsumerStatefulWidget {
  final TaskHierarchyNode node;
  final int depth;
  final String projectId;
  final List<TaskHierarchyNode> siblings;
  final List<Assignment> assignments;
  final Map<String, Resource> resourceById;

  const _TaskTile({
    required this.node,
    required this.depth,
    required this.projectId,
    required this.siblings,
    required this.assignments,
    required this.resourceById,
  });

  @override
  ConsumerState<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends ConsumerState<_TaskTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final node = widget.node;
    final df = DateFormat.yMMMd();
    final timeline = node.hasChildren ? node.computedCurrentTimeline : node.currentTimeline;
    final statusLabel = node.hasChildren ? '${node.computedStatus.name} (agg.)' : node.status.name;
    final rangeText = timeline.isEmpty
        ? '—'
        : '${timeline.start != null ? df.format(timeline.start!.toLocal()) : '?'}'
            ' → '
            '${timeline.end != null ? df.format(timeline.end!.toLocal()) : '?'}';

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16 + widget.depth * 18.0, 8, 8, 8),
              child: Row(
                children: [
                  Icon(
                    _expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 18,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    node.hasChildren ? Icons.folder_open_outlined : Icons.task_alt_outlined,
                    size: 16,
                    color: node.hasChildren
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      node.title,
                      style: node.hasChildren
                          ? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)
                          : theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (node.nonLeafAssignmentWarning) ...[
                    Tooltip(
                      message:
                          'This parent has ${node.assignmentCount} assignment(s) excluded from the matrix.',
                      child: Icon(Icons.warning_amber_rounded,
                          size: 16, color: theme.colorScheme.error),
                    ),
                    const SizedBox(width: 6),
                  ],
                  _StatusChip(label: statusLabel, dense: true),
                  const SizedBox(width: 8),
                  Text(rangeText, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: EdgeInsets.fromLTRB(34 + widget.depth * 18.0, 0, 16, 12),
              child: _TaskDetailPanel(
                node: node,
                projectId: widget.projectId,
                siblings: widget.siblings,
                assignments: widget.assignments,
                resourceById: widget.resourceById,
                onAfterEdit: () {
                  ref.invalidate(allHierarchyByProjectProvider);
                  ref.invalidate(allAssignmentsProvider);
                  ref.invalidate(taskHierarchyProvider(widget.projectId));
                  ref.invalidate(tasksProvider(widget.projectId));
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskDetailPanel extends ConsumerWidget {
  final TaskHierarchyNode node;
  final String projectId;
  final List<TaskHierarchyNode> siblings;
  final List<Assignment> assignments;
  final Map<String, Resource> resourceById;
  final VoidCallback onAfterEdit;

  const _TaskDetailPanel({
    required this.node,
    required this.projectId,
    required this.siblings,
    required this.assignments,
    required this.resourceById,
    required this.onAfterEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final df = DateFormat.yMMMd();

    String fmt(Timeline t) {
      if (t.isEmpty) return '—';
      return '${t.start != null ? df.format(t.start!.toLocal()) : '?'}'
          ' → '
          '${t.end != null ? df.format(t.end!.toLocal()) : '?'}';
    }

    final origin = node.hasChildren ? node.computedOriginTimeline : node.originTimeline;
    final current = node.hasChildren ? node.computedCurrentTimeline : node.currentTimeline;
    final real = node.hasChildren ? node.computedRealTimeline : node.realTimeline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (node.description != null && node.description!.isNotEmpty) ...[
          Text(node.description!, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _InlineKv(label: 'L1 Origin', value: fmt(origin)),
            _InlineKv(label: 'L2 Current', value: fmt(current)),
            _InlineKv(label: 'L3 Real', value: fmt(real)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('Assignees:', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Expanded(
              child: assignments.isEmpty
                  ? Text('—', style: theme.textTheme.bodySmall)
                  : Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: assignments.map((a) {
                        final r = resourceById[a.resourceId];
                        final name = r?.name ?? a.resourceId;
                        return Chip(
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          avatar: const Icon(Icons.person, size: 14),
                          label: Text('$name · ${a.allocationPercent}%',
                              style: theme.textTheme.bodySmall),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton.tonalIcon(
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Edit'),
              onPressed: () async {
                final saved = await showTaskEditor(
                  context,
                  ref,
                  projectId: projectId,
                  existing: node.toTaskItem(),
                  siblings: siblings,
                );
                if (saved) onAfterEdit();
              },
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Delete'),
              onPressed: () async {
                await ref.read(apiClientProvider).deleteTask(node.id);
                onAfterEdit();
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _InlineKv extends StatelessWidget {
  final String label;
  final String value;
  const _InlineKv({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ',
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        Text(value, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool dense;
  const _StatusChip({required this.label, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: dense ? 1 : 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: dense ? 11 : 12,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ============================================================================
// All Gantt tab — flatten all visible (filtered) tasks across projects into a
// single GanttChart, inserting one summary row per project as a group header.
// ============================================================================

class _AllGanttTab extends ConsumerWidget {
  const _AllGanttTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agg = ref.watch(allHierarchyByProjectProvider);
    final assignments = ref.watch(allAssignmentsProvider);
    final resources = ref.watch(resourcesProvider);
    final projectFilter = ref.watch(projectFilterProvider);
    final assigneeFilter = ref.watch(assigneeFilterProvider);

    if (agg.isLoading || assignments.isLoading || resources.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (agg.hasError) return Center(child: Text('Error: ${agg.error}'));
    if (assignments.hasError) return Center(child: Text('Error: ${assignments.error}'));
    if (resources.hasError) return Center(child: Text('Error: ${resources.error}'));

    final groups = agg.value ?? const <ProjectHierarchy>[];
    final assignmentList = assignments.value ?? const <Assignment>[];
    final resourceList = resources.value ?? const <Resource>[];
    final assignmentsByTask = <String, List<Assignment>>{};
    for (final a in assignmentList) {
      assignmentsByTask.putIfAbsent(a.taskId, () => []).add(a);
    }
    final resourceById = {for (final r in resourceList) r.id!: r};

    final rows = <GanttRow>[];
    for (final g in groups) {
      if (projectFilter.isNotEmpty && !projectFilter.contains(g.project.id)) continue;

      List<TaskHierarchyNode> nodes = g.nodes;
      if (assigneeFilter.isNotEmpty) {
        final matching = <String>{};
        for (final n in g.nodes) {
          final assigns = assignmentsByTask[n.id] ?? const <Assignment>[];
          if (assigns.any((a) {
            final name = resourceById[a.resourceId]?.name.trim();
            return name != null && assigneeFilter.contains(name);
          })) {
            matching.add(n.id);
          }
        }
        final byId = {for (final n in g.nodes) n.id: n};
        final keep = <String>{};
        for (final id in matching) {
          var cur = byId[id];
          while (cur != null) {
            if (!keep.add(cur.id)) break;
            cur = cur.parentTaskId == null ? null : byId[cur.parentTaskId];
          }
        }
        nodes = g.nodes.where((n) => keep.contains(n.id)).toList();
      }
      if (nodes.isEmpty) continue;

      // Project group header row: span derived from the project's union timeline.
      final projectSpan = _projectSpan(nodes);
      rows.add(GanttRow(
        title: '📁 ${g.project.name}',
        depth: 0,
        hasChildren: true,
        origin: const Timeline(),
        current: projectSpan,
        real: const Timeline(),
      ));
      for (final entry in flattenHierarchy(nodes)) {
        final node = entry.$1;
        rows.add(GanttRow(
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
      return const Center(child: Text('No tasks match the current filters.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _LegendSwatch(label: 'L1 Origin (baseline)', role: _SwatchRole.origin),
              _LegendSwatch(label: 'L2 Current (plan)', role: _SwatchRole.current),
              _LegendSwatch(label: 'L3 Real (actual)', role: _SwatchRole.real),
              _LegendSwatch(label: 'Summary (parent / project)', role: _SwatchRole.summary),
            ],
          ),
        ),
        const Divider(),
        Expanded(child: SingleChildScrollView(child: GanttChart(rows: rows))),
      ],
    );
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
        Container(width: 14, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
