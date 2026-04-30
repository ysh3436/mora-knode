import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../models/milestone.dart';
import '../models/task_hierarchy.dart';
import '../state/providers.dart';
import '../widgets/gantt_chart.dart';
import '../widgets/task_editor.dart';

class ProjectScreen extends ConsumerWidget {
  final String projectId;
  final String projectName;
  const ProjectScreen({super.key, required this.projectId, required this.projectName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(projectName),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Tasks', icon: Icon(Icons.check_box_outlined)),
              Tab(text: 'Gantt', icon: Icon(Icons.view_timeline_outlined)),
              Tab(text: 'Milestones', icon: Icon(Icons.flag_outlined)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(tasksProvider(projectId));
                ref.invalidate(taskHierarchyProvider(projectId));
                ref.invalidate(milestonesProvider(projectId));
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _TasksTab(projectId: projectId),
            _GanttTab(projectId: projectId),
            _MilestonesTab(projectId: projectId),
          ],
        ),
      ),
    );
  }
}

class _TasksTab extends ConsumerWidget {
  final String projectId;
  const _TasksTab({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hierarchy = ref.watch(taskHierarchyProvider(projectId));
    final df = DateFormat.yMMMd();

    return Scaffold(
      body: hierarchy.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No tasks. Tap + to add one.'));
          }
          final flat = flattenHierarchy(items);
          return ListView.separated(
            itemCount: flat.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final (node, depth) = flat[i];
              final timeline = node.hasChildren ? node.computedCurrentTimeline : node.currentTimeline;
              final statusLabel = node.hasChildren ? '${node.computedStatus.name} (aggregated)' : node.status.name;
              final rangeText = timeline.isEmpty
                  ? '—'
                  : '${timeline.start != null ? df.format(timeline.start!.toLocal()) : '?'}'
                      ' → '
                      '${timeline.end != null ? df.format(timeline.end!.toLocal()) : '?'}';
              return _TaskRow(
                node: node,
                depth: depth,
                subtitle: '$statusLabel · $rangeText',
                onTap: () async {
                  final saved = await showTaskEditor(
                    context,
                    ref,
                    projectId: projectId,
                    existing: node.toTaskItem(),
                    siblings: items,
                  );
                  if (saved) {
                    ref.invalidate(tasksProvider(projectId));
                    ref.invalidate(taskHierarchyProvider(projectId));
                  }
                },
                onDelete: () async {
                  await ref.read(apiClientProvider).deleteTask(node.id);
                  ref.invalidate(tasksProvider(projectId));
                  ref.invalidate(taskHierarchyProvider(projectId));
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New task'),
        onPressed: () async {
          final existingForParent = hierarchy.asData?.value ?? const <TaskHierarchyNode>[];
          final saved = await showTaskEditor(
            context,
            ref,
            projectId: projectId,
            siblings: existingForParent,
          );
          if (saved) {
            ref.invalidate(tasksProvider(projectId));
            ref.invalidate(taskHierarchyProvider(projectId));
          }
        },
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final TaskHierarchyNode node;
  final int depth;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TaskRow({
    required this.node,
    required this.depth,
    required this.subtitle,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indent = depth * 20.0;
    return ListTile(
      contentPadding: EdgeInsets.only(left: 16 + indent, right: 4),
      leading: Icon(
        node.hasChildren ? Icons.folder_open_outlined : Icons.chevron_right,
        color: node.hasChildren ? theme.colorScheme.primary : theme.colorScheme.outline,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              node.title,
              style: node.hasChildren
                  ? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)
                  : theme.textTheme.bodyLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (node.nonLeafAssignmentWarning) ...[
            const SizedBox(width: 8),
            Tooltip(
              message:
                  'This parent has ${node.assignmentCount} assignment(s). They are excluded from the matrix because it has children. Move them to a leaf task.',
              child: Icon(Icons.warning_amber_rounded, size: 18, color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
      subtitle: Text(subtitle),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
      onTap: onTap,
    );
  }
}

class _GanttTab extends ConsumerWidget {
  final String projectId;
  const _GanttTab({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hierarchy = ref.watch(taskHierarchyProvider(projectId));
    return hierarchy.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        final rows = flattenHierarchy(items)
            .map((e) => GanttRow(
                  title: e.$1.title,
                  depth: e.$2,
                  hasChildren: e.$1.hasChildren,
                  origin: e.$1.hasChildren ? e.$1.computedOriginTimeline : e.$1.originTimeline,
                  current: e.$1.hasChildren ? e.$1.computedCurrentTimeline : e.$1.currentTimeline,
                  real: e.$1.hasChildren ? e.$1.computedRealTimeline : e.$1.realTimeline,
                ))
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Wrap(
                spacing: 16,
                runSpacing: 4,
                children: const [
                  _LegendSwatch(label: 'L1 Origin (baseline)', colorRole: _Swatch.origin),
                  _LegendSwatch(label: 'L2 Current (plan)', colorRole: _Swatch.current),
                  _LegendSwatch(label: 'L3 Real (actual)', colorRole: _Swatch.real),
                  _LegendSwatch(label: 'Summary (parent)', colorRole: _Swatch.summary),
                ],
              ),
            ),
            const Divider(),
            Expanded(child: SingleChildScrollView(child: GanttChart(rows: rows))),
          ],
        );
      },
    );
  }
}

enum _Swatch { origin, current, real, summary }

class _LegendSwatch extends StatelessWidget {
  final String label;
  final _Swatch colorRole;
  const _LegendSwatch({required this.label, required this.colorRole});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = switch (colorRole) {
      _Swatch.origin => cs.outline.withValues(alpha: 0.45),
      _Swatch.current => cs.primary.withValues(alpha: 0.85),
      _Swatch.real => cs.tertiary.withValues(alpha: 0.95),
      _Swatch.summary => cs.secondary.withValues(alpha: 0.75),
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

class _MilestonesTab extends ConsumerWidget {
  final String projectId;
  const _MilestonesTab({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final milestones = ref.watch(milestonesProvider(projectId));
    final df = DateFormat.yMMMd();

    return Scaffold(
      body: milestones.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No milestones yet.'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final m = items[i];
              return ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(m.title),
                subtitle: Text('${df.format(m.date.toLocal())} · ${m.status.name}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (m.id == null) return;
                    await ref.read(apiClientProvider).deleteMilestone(m.id!);
                    ref.invalidate(milestonesProvider(projectId));
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New milestone'),
        onPressed: () => _openCreate(context, ref),
      ),
    );
  }

  Future<void> _openCreate(BuildContext context, WidgetRef ref) async {
    final titleC = TextEditingController();
    DateTime date = DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('New milestone'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Title *'), autofocus: true),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(DateFormat.yMMMd().format(date)),
                  trailing: IconButton(
                    icon: const Icon(Icons.date_range),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(DateTime.now().year + 5),
                        initialDate: date,
                      );
                      if (picked != null) setState(() => date = picked);
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (titleC.text.trim().isEmpty) return;
                await ref.read(apiClientProvider).createMilestone(
                      projectId,
                      Milestone(
                        projectId: projectId,
                        title: titleC.text.trim(),
                        date: DateTime.utc(date.year, date.month, date.day),
                      ),
                    );
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) ref.invalidate(milestonesProvider(projectId));
  }
}

// Accessors used by other widgets to build the editor dialog.
extension TaskHierarchyNodeListX on List<TaskHierarchyNode> {
  /// Find the set of ids that are [taskId] or descendants of [taskId]. Used to
  /// exclude invalid parent candidates from the parent picker dropdown.
  Set<String> selfAndDescendants(String taskId) {
    final byParent = <String?, List<TaskHierarchyNode>>{};
    for (final n in this) {
      byParent.putIfAbsent(n.parentTaskId, () => []).add(n);
    }
    final out = <String>{taskId};
    final stack = [taskId];
    while (stack.isNotEmpty) {
      final cur = stack.removeLast();
      for (final child in byParent[cur] ?? const []) {
        if (out.add(child.id)) stack.add(child.id);
      }
    }
    return out;
  }
}

