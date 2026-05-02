import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/labels.dart';
import '../../models/project.dart';
import '../../models/task_hierarchy.dart';
import '../../models/task_item.dart';
import '../../models/timeline.dart';
import '../../state/providers.dart';
import '../inline_date_range_popover.dart';
import '../task_timeline_pickers.dart' show pickTimedTimeline;

/// Inspector panel for creating a new task. Replaces the prior modal
/// `showTaskEditor(... existing: null)` — the right pane stays a single
/// surface for both viewing / editing existing tasks (TaskInspectorPanel)
/// and drafting a new one. On Save, switches the inspection to the freshly
/// created task so the user can immediately continue editing inline.
class TaskDraftPanel extends ConsumerStatefulWidget {
  final String? projectId;
  final String? parentTaskId;
  const TaskDraftPanel({super.key, this.projectId, this.parentTaskId});

  @override
  ConsumerState<TaskDraftPanel> createState() => _TaskDraftPanelState();
}

class _TaskDraftPanelState extends ConsumerState<TaskDraftPanel> {
  final _titleC = TextEditingController();
  final _descC = TextEditingController();
  String? _projectId;
  String? _parentTaskId;
  TaskStatus _status = TaskStatus.Created;
  Timeline _origin = const Timeline();
  Timeline _current = const Timeline();
  Timeline _real = const Timeline();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _projectId = widget.projectId;
    _parentTaskId = widget.parentTaskId;
  }

  @override
  void dispose() {
    _titleC.dispose();
    _descC.dispose();
    super.dispose();
  }

  bool get _canSave => _titleC.text.trim().isNotEmpty && _projectId != null;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final created = await api.createTask(
        _projectId!,
        TaskItem(
          projectId: _projectId!,
          parentTaskId: _parentTaskId,
          title: _titleC.text.trim(),
          description: _descC.text.trim().isEmpty ? null : _descC.text.trim(),
          status: _status,
          originTimeline: _origin,
          currentTimeline: _current,
          realTimeline: _real,
        ),
      );
      ref.invalidate(allHierarchyByProjectProvider);
      ref.invalidate(taskHierarchyProvider(_projectId!));
      ref.invalidate(tasksProvider(_projectId!));
      ref.invalidate(allAssignmentsProvider);
      // Hand off to the regular TaskInspectorPanel so further edits happen
      // inline on the same surface.
      if (created.id != null) {
        ref.read(inspectionProvider.notifier).state = TaskInspection(created.id!);
      } else {
        ref.read(inspectionProvider.notifier).state = null;
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _cancel() {
    ref.read(inspectionProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final projects = ref.watch(projectsProvider).asData?.value ?? const <Project>[];
    final allGroups = ref.watch(allHierarchyByProjectProvider).asData?.value ?? const [];

    final siblings = _projectId == null
        ? const <TaskHierarchyNode>[]
        : (allGroups.firstWhere(
              (g) => g.project.id == _projectId,
              orElse: () => (project: Project(id: _projectId, name: ''), nodes: const <TaskHierarchyNode>[]),
            )).nodes;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.add_task, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                l.taskEditorTitleNew,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: _projectId,
            decoration: InputDecoration(
              labelText: l.taskEditorFieldProject,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            items: projects
                .where((p) => p.id != null)
                .map((p) => DropdownMenuItem<String?>(value: p.id, child: Text(p.name)))
                .toList(),
            onChanged: _saving
                ? null
                : (id) => setState(() {
                      _projectId = id;
                      _parentTaskId = null;
                    }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleC,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l.taskEditorFieldTitle,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descC,
            decoration: InputDecoration(
              labelText: l.taskEditorFieldDescription,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
            minLines: 2,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<TaskStatus>(
            initialValue: _status,
            decoration: InputDecoration(
              labelText: l.taskEditorFieldStatus,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            items: TaskStatus.values
                .map((s) => DropdownMenuItem(value: s, child: Text(taskStatusLabel(context, s))))
                .toList(),
            onChanged: _saving ? null : (v) => setState(() => _status = v ?? _status),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _parentTaskId,
            decoration: InputDecoration(
              labelText: l.taskEditorFieldParent,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem<String?>(value: null, child: Text(l.taskEditorParentTopLevel)),
              ...siblings.map((n) => DropdownMenuItem<String?>(
                    value: n.id,
                    child: Text(n.title, overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: _saving ? null : (v) => setState(() => _parentTaskId = v),
          ),
          const SizedBox(height: 16),
          _DraftTimelineRow(
            label: l.timelineL1Origin,
            timeline: _origin,
            onChanged: (t) => setState(() => _origin = t),
          ),
          _DraftTimelineRow(
            label: l.timelineL2Current,
            timeline: _current,
            onChanged: (t) => setState(() => _current = t),
          ),
          _DraftTimelineRow(
            label: l.timelineL3Real,
            timeline: _real,
            onChanged: (t) => setState(() => _real = t),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              FilledButton.icon(
                icon: _saving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check, size: 16),
                label: Text(l.actionCreate),
                onPressed: !_canSave || _saving ? null : _save,
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _saving ? null : _cancel,
                child: Text(l.actionCancel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Local timeline row for the draft panel — shows current value, lets the
/// user toggle all-day / timed and pick / clear via the shared compact
/// pickers. Reused for all three timeline slots.
class _DraftTimelineRow extends StatelessWidget {
  final String label;
  final Timeline timeline;
  final ValueChanged<Timeline> onChanged;
  const _DraftTimelineRow({required this.label, required this.timeline, required this.onChanged});

  String _format(BuildContext context) {
    if (timeline.isEmpty) return '—';
    final s = timeline.start?.toLocal();
    final e = timeline.end?.toLocal();
    if (s == null || e == null) return '?';
    String d(DateTime t) => '${t.year}-${t.month.toString().padLeft(2, "0")}-${t.day.toString().padLeft(2, "0")}';
    if (timeline.isAllDay) return '${d(s)} → ${d(e)}';
    String hm(DateTime t) => '${t.hour.toString().padLeft(2, "0")}:${t.minute.toString().padLeft(2, "0")}';
    return '${d(s)} ${hm(s)} → ${d(e)} ${hm(e)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 76,
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () async {
                  final picked = timeline.isAllDay
                      // ignore: use_build_context_synchronously
                      ? await showInlineDateRangePopover(context, timeline)
                      // ignore: use_build_context_synchronously
                      : await pickTimedTimeline(context, timeline);
                  if (picked != null) onChanged(picked);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(_format(context), style: theme.textTheme.bodySmall),
                ),
              ),
            ),
            SegmentedButton<bool>(
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: [
                ButtonSegment(value: true, label: Text(l.taskEditorAllDay)),
                ButtonSegment(value: false, label: Text(l.taskEditorTimed)),
              ],
              selected: {timeline.isAllDay},
              onSelectionChanged: (s) => onChanged(timeline.copyWith(isAllDay: s.first)),
            ),
            if (!timeline.isEmpty)
              IconButton(
                tooltip: l.actionClear,
                iconSize: 16,
                icon: const Icon(Icons.close),
                onPressed: () => onChanged(const Timeline()),
              ),
          ],
        ),
      ),
    );
  }
}
