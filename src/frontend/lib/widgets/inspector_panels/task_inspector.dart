import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../models/assignment.dart';
import '../../models/resource.dart';
import '../../models/task_hierarchy.dart';
import '../../models/task_item.dart';
import '../../models/timeline.dart';
import '../../state/providers.dart';

/// Detail panel for a TaskInspection. Pulls from already-cached aggregated
/// providers so opening the inspector does not trigger extra fetches.
class TaskInspectorPanel extends ConsumerWidget {
  final String taskId;
  const TaskInspectorPanel({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agg = ref.watch(allHierarchyByProjectProvider);
    final assignments = ref.watch(assignmentsByTaskProvider(taskId));
    final resources = ref.watch(resourcesProvider);
    final theme = Theme.of(context);

    return agg.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Error('$e'),
      data: (groups) {
        TaskHierarchyNode? node;
        String? projectName;
        for (final g in groups) {
          final found = g.nodes.where((n) => n.id == taskId).cast<TaskHierarchyNode?>().firstOrNull;
          if (found != null) {
            node = found;
            projectName = g.project.name;
            break;
          }
        }
        if (node == null) return _Error('Task not found (or hidden by view scope).');

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    node.hasChildren ? Icons.folder_open_outlined : Icons.task_alt_outlined,
                    size: 18,
                    color: node.hasChildren ? theme.colorScheme.primary : theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      node.title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: [
                _Pill(label: projectName ?? '?', icon: Icons.folder_outlined),
                _StatusPill(node: node),
              ]),
              const SizedBox(height: 16),
              if ((node.description ?? '').isNotEmpty) ...[
                Text(node.description!, style: theme.textTheme.bodySmall),
                const SizedBox(height: 16),
              ],
              _SectionHeader('Timelines'),
              _TimelineRow(label: 'L1 Origin', timeline: _resolveOrigin(node)),
              _TimelineRow(label: 'L2 Current', timeline: _resolveCurrent(node)),
              _TimelineRow(label: 'L3 Real', timeline: _resolveReal(node), highlightTimed: true),
              const SizedBox(height: 16),
              _SectionHeader('Assignees'),
              _AssigneeList(assignments: assignments, resources: resources),
              const SizedBox(height: 16),
              if (node.hasChildren) ...[
                _SectionHeader('Children'),
                _ChildrenList(parentId: node.id, allGroups: groups),
                const SizedBox(height: 16),
              ],
              _SectionHeader('Recent changes'),
              _ChangeLogList(taskId: taskId),
            ],
          ),
        );
      },
    );
  }

  Timeline _resolveOrigin(TaskHierarchyNode n) =>
      n.hasChildren ? n.computedOriginTimeline : n.originTimeline;
  Timeline _resolveCurrent(TaskHierarchyNode n) =>
      n.hasChildren ? n.computedCurrentTimeline : n.currentTimeline;
  Timeline _resolveReal(TaskHierarchyNode n) =>
      n.hasChildren ? n.computedRealTimeline : n.realTimeline;
}

class _Error extends StatelessWidget {
  final String msg;
  const _Error(this.msg);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(msg, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  const _Pill({required this.label, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = color ?? theme.colorScheme.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final TaskHierarchyNode node;
  const _StatusPill({required this.node});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = node.hasChildren ? node.computedStatus : node.status;
    final color = switch (s) {
      TaskStatus.NotStarted => theme.colorScheme.surfaceContainerHighest,
      TaskStatus.InProgress => theme.colorScheme.primaryContainer,
      TaskStatus.Blocked => theme.colorScheme.errorContainer,
      TaskStatus.Done => theme.colorScheme.tertiaryContainer,
    };
    return _Pill(
      label: node.hasChildren ? '${s.name} (agg.)' : s.name,
      icon: Icons.circle,
      color: color,
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final String label;
  final Timeline timeline;
  final bool highlightTimed;
  const _TimelineRow({required this.label, required this.timeline, this.highlightTimed = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dfDate = DateFormat.yMMMd();
    final dfTime = DateFormat.Hm();

    String fmt(DateTime? t) {
      if (t == null) return '?';
      final local = t.toLocal();
      if (timeline.isAllDay) return dfDate.format(local);
      return '${dfDate.format(local)} ${dfTime.format(local)}';
    }

    final body = timeline.isEmpty ? '—' : '${fmt(timeline.start)}  →  ${fmt(timeline.end)}';
    final tag = timeline.isEmpty ? null : (timeline.isAllDay ? 'all-day' : 'timed');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(body, style: theme.textTheme.bodySmall),
                if (tag != null)
                  Text(
                    tag,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: highlightTimed && tag == 'timed'
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssigneeList extends StatelessWidget {
  final AsyncValue<List<Assignment>> assignments;
  final AsyncValue<List<Resource>> resources;
  const _AssigneeList({required this.assignments, required this.resources});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aList = assignments.asData?.value ?? const [];
    final rList = resources.asData?.value ?? const [];
    final byId = {for (final r in rList) r.id!: r};

    if (aList.isEmpty) {
      return Text('—', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline));
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: aList.map((a) {
        final r = byId[a.resourceId];
        final isAgent = r?.kind == ResourceKindFE.agent;
        final name = r?.name ?? '?';
        return Chip(
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          avatar: Icon(isAgent ? Icons.smart_toy_outlined : Icons.person, size: 14),
          label: Text('$name · ${a.allocationPercent}%', style: theme.textTheme.bodySmall),
        );
      }).toList(),
    );
  }
}

class _ChildrenList extends StatelessWidget {
  final String parentId;
  final List<ProjectHierarchy> allGroups;
  const _ChildrenList({required this.parentId, required this.allGroups});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <TaskHierarchyNode>[];
    for (final g in allGroups) {
      children.addAll(g.nodes.where((n) => n.parentTaskId == parentId));
    }
    if (children.isEmpty) return Text('—', style: theme.textTheme.bodySmall);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children
          .map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  children: [
                    Icon(Icons.subdirectory_arrow_right, size: 12, color: theme.colorScheme.outline),
                    const SizedBox(width: 6),
                    Expanded(child: Text(c.title, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
                    Text(
                      (c.hasChildren ? c.computedStatus : c.status).name,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _ChangeLogList extends ConsumerWidget {
  final String taskId;
  const _ChangeLogList({required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final logs = ref.watch(taskChangeLogsProvider(taskId));
    final df = DateFormat('M/d HH:mm');
    return logs.when(
      loading: () => const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Text('$e', style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
      data: (list) {
        if (list.isEmpty) return Text('No changes yet.', style: theme.textTheme.bodySmall);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: list.take(8).map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '· ${c.field}  ${c.beforeValue ?? "—"} → ${c.afterValue ?? "—"}'
                  '  ${c.changedBy ?? ""}  ${df.format(c.changedAt.toLocal())}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              )).toList(),
        );
      },
    );
  }
}
