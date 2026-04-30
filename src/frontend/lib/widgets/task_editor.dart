import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../models/project.dart';
import '../models/task_hierarchy.dart';
import '../models/task_item.dart';
import '../models/timeline.dart';
import '../state/providers.dart';

/// Modal task editor — handles create and edit. Honours ADR-009: each
/// timeline carries its own IsAllDay toggle that switches between a
/// date-range picker and explicit start/end date+time pickers.
///
/// When [projectId] is null and [existing] is null, the dialog also surfaces
/// a project picker so callers can punch in "+ New task" without first
/// drilling into a project.
Future<bool> showTaskEditor(
  BuildContext context,
  WidgetRef ref, {
  String? projectId,
  TaskItem? existing,
  List<TaskHierarchyNode> siblings = const [],
}) async {
  final isEdit = existing != null;

  // Project picker state for the create-from-anywhere path.
  String? activeProjectId = projectId ?? existing?.projectId;
  List<TaskHierarchyNode> activeSiblings = siblings;

  final titleC = TextEditingController(text: existing?.title ?? '');
  final descC = TextEditingController(text: existing?.description ?? '');
  final reasonC = TextEditingController();
  final changedByC = TextEditingController();
  var status = existing?.status ?? TaskStatus.NotStarted;
  var origin = existing?.originTimeline ?? const Timeline();
  var current = existing?.currentTimeline ?? const Timeline();
  var real = existing?.realTimeline ?? const Timeline();
  String? parentId = existing?.parentTaskId;

  final invalidParentIds = <String>{};
  if (isEdit && existing.id != null) {
    invalidParentIds.addAll(_selfAndDescendants(activeSiblings, existing.id!));
  }

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return Consumer(builder: (ctx, innerRef, _) {
        return StatefulBuilder(builder: (ctx, setState) {
          // Refresh siblings when project changes (new-task path)
          if (!isEdit && activeProjectId != null && activeSiblings.isEmpty) {
            final aggValue =
                innerRef.read(allHierarchyByProjectProvider).asData?.value ?? const [];
            for (final g in aggValue) {
              if (g.project.id == activeProjectId) {
                activeSiblings = g.nodes;
                break;
              }
            }
          }

          final parentCandidates =
              activeSiblings.where((n) => !invalidParentIds.contains(n.id)).toList();

          final canSave = titleC.text.trim().isNotEmpty && activeProjectId != null;

          return AlertDialog(
            title: Text(isEdit ? 'Edit task' : 'New task'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isEdit) _ProjectPicker(
                      ref: innerRef,
                      selected: activeProjectId,
                      onChanged: (id) {
                        setState(() {
                          activeProjectId = id;
                          activeSiblings = const [];
                          parentId = null;
                        });
                      },
                    ),
                    TextField(
                      controller: titleC,
                      decoration: const InputDecoration(labelText: 'Title *'),
                      autofocus: !isEdit,
                      onChanged: (_) => setState(() {}),
                    ),
                    TextField(
                      controller: descC,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<TaskStatus>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: TaskStatus.values
                          .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                          .toList(),
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
                    const SizedBox(height: 16),
                    if (isEdit)
                      _TimelineEditor(
                        label: 'L1 Origin (baseline)',
                        timeline: origin,
                        readOnly: true,
                        onChanged: (t) => setState(() => origin = t),
                      ),
                    _TimelineEditor(
                      label: 'L2 Current (plan)',
                      timeline: current,
                      onChanged: (t) => setState(() => current = t),
                    ),
                    _TimelineEditor(
                      label: 'L3 Real (actual)',
                      timeline: real,
                      onChanged: (t) => setState(() => real = t),
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
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: !canSave
                    ? null
                    : () async {
                        final api = innerRef.read(apiClientProvider);
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
                            activeProjectId!,
                            TaskItem(
                              projectId: activeProjectId!,
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
        });
      });
    },
  );

  if (saved == true) {
    // Invalidate every cache that depends on the task data so subsequent
    // reads refetch. Cheap because we only have a handful of providers.
    ref.invalidate(allHierarchyByProjectProvider);
    ref.invalidate(allAssignmentsProvider);
    if (activeProjectId != null) {
      ref.invalidate(taskHierarchyProvider(activeProjectId!));
      ref.invalidate(tasksProvider(activeProjectId!));
    }
    if (existing?.id != null) {
      ref.invalidate(taskChangeLogsProvider(existing!.id!));
      ref.invalidate(assignmentsByTaskProvider(existing.id!));
    }
  }

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

class _ProjectPicker extends StatelessWidget {
  final WidgetRef ref;
  final String? selected;
  final void Function(String?) onChanged;
  const _ProjectPicker({required this.ref, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider).asData?.value ?? const <Project>[];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String?>(
        initialValue: selected,
        decoration: const InputDecoration(labelText: 'Project *'),
        items: projects
            .where((p) => p.id != null)
            .map((p) => DropdownMenuItem<String?>(value: p.id, child: Text(p.name)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _TimelineEditor extends StatelessWidget {
  final String label;
  final Timeline timeline;
  final ValueChanged<Timeline> onChanged;
  final bool readOnly;

  const _TimelineEditor({
    required this.label,
    required this.timeline,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (!readOnly)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('all-day', style: theme.textTheme.bodySmall),
                      Switch(
                        value: timeline.isAllDay,
                        onChanged: (v) => onChanged(timeline.copyWith(isAllDay: v)),
                      ),
                    ],
                  ),
                if (timeline.isEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add'),
                    onPressed: readOnly
                        ? null
                        : () async {
                            final picked = await _pick(context, timeline);
                            if (picked != null) onChanged(picked);
                          },
                  )
                else if (!readOnly)
                  IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => onChanged(const Timeline()),
                  ),
              ],
            ),
            if (!timeline.isEmpty)
              InkWell(
                onTap: readOnly
                    ? null
                    : () async {
                        final picked = await _pick(context, timeline);
                        if (picked != null) onChanged(picked);
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(_format(timeline), style: theme.textTheme.bodySmall),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _format(Timeline t) {
    if (t.isEmpty) return '—';
    if (t.isAllDay) {
      final df = DateFormat.yMMMd();
      final s = t.start != null ? df.format(t.start!.toLocal()) : '?';
      final e = t.end != null ? df.format(t.end!.toLocal()) : '?';
      return '$s  →  $e   (all-day)';
    }
    final df = DateFormat('yyyy-MM-dd HH:mm');
    final s = t.start != null ? df.format(t.start!.toLocal()) : '?';
    final e = t.end != null ? df.format(t.end!.toLocal()) : '?';
    return '$s  →  $e   (timed)';
  }

  Future<Timeline?> _pick(BuildContext context, Timeline current) async {
    if (current.isAllDay) return _pickAllDay(context, current);
    return _pickTimed(context, current);
  }

  Future<Timeline?> _pickAllDay(BuildContext context, Timeline current) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      initialDateRange: (current.start != null && current.end != null)
          ? DateTimeRange(start: current.start!.toLocal(), end: current.end!.toLocal())
          : null,
    );
    if (picked == null) return null;
    return Timeline(
      start: DateTime.utc(picked.start.year, picked.start.month, picked.start.day),
      end: DateTime.utc(picked.end.year, picked.end.month, picked.end.day),
      isAllDay: true,
    );
  }

  Future<Timeline?> _pickTimed(BuildContext context, Timeline current) async {
    // Pick start (date + time), then end (date + time).
    final initStart = current.start?.toLocal() ?? DateTime.now();
    final initEnd = current.end?.toLocal() ?? initStart.add(const Duration(hours: 1));

    if (!context.mounted) return null;
    final startDate = await showDatePicker(
      context: context,
      firstDate: DateTime(initStart.year - 1),
      lastDate: DateTime(initStart.year + 3),
      initialDate: initStart,
      helpText: 'Start date',
    );
    if (startDate == null) return null;

    if (!context.mounted) return null;
    final startTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initStart),
      helpText: 'Start time',
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (startTime == null) return null;

    if (!context.mounted) return null;
    final endDate = await showDatePicker(
      context: context,
      firstDate: startDate,
      lastDate: DateTime(startDate.year + 3),
      initialDate: initEnd.isBefore(startDate) ? startDate : initEnd,
      helpText: 'End date',
    );
    if (endDate == null) return null;

    if (!context.mounted) return null;
    final endTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initEnd),
      helpText: 'End time',
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (endTime == null) return null;

    final start = DateTime(startDate.year, startDate.month, startDate.day, startTime.hour, startTime.minute).toUtc();
    final end = DateTime(endDate.year, endDate.month, endDate.day, endTime.hour, endTime.minute).toUtc();
    if (!end.isAfter(start)) return null;
    return Timeline(start: start, end: end, isAllDay: false);
  }
}
