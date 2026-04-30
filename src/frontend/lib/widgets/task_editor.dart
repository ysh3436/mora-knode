import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../models/task_hierarchy.dart';
import '../models/task_item.dart';
import '../models/timeline.dart';
import '../state/providers.dart';

Future<bool> showTaskEditor(
  BuildContext context,
  WidgetRef ref, {
  required String projectId,
  TaskItem? existing,
  List<TaskHierarchyNode> siblings = const [],
}) async {
  final isEdit = existing != null;
  final titleC = TextEditingController(text: existing?.title ?? '');
  final descC = TextEditingController(text: existing?.description ?? '');
  final reasonC = TextEditingController();
  final changedByC = TextEditingController();
  var status = existing?.status ?? TaskStatus.NotStarted;
  var current = existing?.currentTimeline ?? const Timeline();
  var real = existing?.realTimeline ?? const Timeline();
  String? parentId = existing?.parentTaskId;

  // Parent dropdown excludes the task itself and its descendants to prevent cycles.
  final invalidParentIds = <String>{};
  if (isEdit && existing.id != null) {
    invalidParentIds.addAll(_selfAndDescendants(siblings, existing.id!));
  }
  final parentCandidates = siblings.where((n) => !invalidParentIds.contains(n.id)).toList();

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        Future<void> pickRange({required bool forCurrent}) async {
          final initial = forCurrent ? current : real;
          final now = DateTime.now();
          final picked = await showDateRangePicker(
            context: ctx,
            firstDate: DateTime(now.year - 1),
            lastDate: DateTime(now.year + 3),
            initialDateRange: (initial.start != null && initial.end != null)
                ? DateTimeRange(start: initial.start!.toLocal(), end: initial.end!.toLocal())
                : null,
          );
          if (picked != null) {
            final t = Timeline(
              start: DateTime.utc(picked.start.year, picked.start.month, picked.start.day),
              end: DateTime.utc(picked.end.year, picked.end.month, picked.end.day),
            );
            setState(() {
              if (forCurrent) {
                current = t;
              } else {
                real = t;
              }
            });
          }
        }

        return AlertDialog(
          title: Text(isEdit ? 'Edit task' : 'New task'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Title *'), autofocus: !isEdit),
                  TextField(controller: descC, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TaskStatus>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: TaskStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                    onChanged: (v) => setState(() => status = v ?? status),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: parentId,
                    decoration: const InputDecoration(labelText: 'Parent (optional)'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('— Top level —')),
                      ...parentCandidates.map((n) => DropdownMenuItem<String?>(
                            value: n.id,
                            child: Text(n.title, overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) => setState(() => parentId = v),
                  ),
                  const SizedBox(height: 12),
                  _TimelineTile(
                    label: 'Current (L2)',
                    timeline: current,
                    onPick: () => pickRange(forCurrent: true),
                    onClear: () => setState(() => current = const Timeline()),
                  ),
                  _TimelineTile(
                    label: 'Real (L3)',
                    timeline: real,
                    onPick: () => pickRange(forCurrent: false),
                    onClear: () => setState(() => real = const Timeline()),
                  ),
                  const SizedBox(height: 12),
                  if (isEdit) ...[
                    TextField(
                      controller: reasonC,
                      decoration: const InputDecoration(labelText: 'Change reason (logged)'),
                    ),
                    TextField(
                      controller: changedByC,
                      decoration: const InputDecoration(labelText: 'Changed by'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (titleC.text.trim().isEmpty) return;
                final api = ref.read(apiClientProvider);
                if (isEdit) {
                  final updated = TaskItem(
                    id: existing.id,
                    projectId: existing.projectId,
                    parentTaskId: parentId,
                    title: titleC.text.trim(),
                    description: descC.text.trim().isEmpty ? null : descC.text.trim(),
                    status: status,
                    originTimeline: existing.originTimeline,
                    currentTimeline: current,
                    realTimeline: real,
                    createdAt: existing.createdAt,
                    updatedAt: existing.updatedAt,
                    changeReason: reasonC.text.trim().isEmpty ? null : reasonC.text.trim(),
                    changedBy: changedByC.text.trim().isEmpty ? null : changedByC.text.trim(),
                  );
                  await api.updateTask(existing.id!, updated);
                } else {
                  await api.createTask(
                    projectId,
                    TaskItem(
                      projectId: projectId,
                      parentTaskId: parentId,
                      title: titleC.text.trim(),
                      description: descC.text.trim().isEmpty ? null : descC.text.trim(),
                      status: status,
                      currentTimeline: current,
                      realTimeline: real,
                    ),
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: Text(isEdit ? 'Save' : 'Create'),
            ),
          ],
        );
      },
    ),
  );

  return saved ?? false;
}

Set<String> _selfAndDescendants(List<TaskHierarchyNode> nodes, String taskId) {
  final byParent = <String?, List<TaskHierarchyNode>>{};
  for (final n in nodes) {
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

class _TimelineTile extends StatelessWidget {
  final String label;
  final Timeline timeline;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _TimelineTile({
    required this.label,
    required this.timeline,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd();
    final text = timeline.isEmpty
        ? '—'
        : '${timeline.start != null ? df.format(timeline.start!.toLocal()) : '?'}'
            ' → '
            '${timeline.end != null ? df.format(timeline.end!.toLocal()) : '?'}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(text),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.date_range), onPressed: onPick),
          IconButton(icon: const Icon(Icons.close), onPressed: timeline.isEmpty ? null : onClear),
        ],
      ),
    );
  }
}
