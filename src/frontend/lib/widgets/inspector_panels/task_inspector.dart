import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../l10n/app_localizations.dart';
import '../../l10n/labels.dart';
import '../../models/assignment.dart';
import '../../models/resource.dart';
import '../../models/task_hierarchy.dart';
import '../../models/task_item.dart';
import '../../models/timeline.dart';
import '../../state/providers.dart';
import '../inline_date_range_popover.dart';
import '../task_timeline_pickers.dart' show pickTimedTimeline;
import 'task_comments_section.dart';

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
    final l = AppL10n.of(context);

    return agg.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Error('$e'),
      data: (groups) {
        TaskHierarchyNode? node;
        String? projectName;
        List<TaskHierarchyNode> projectNodes = const [];
        for (final g in groups) {
          final found = g.nodes.where((n) => n.id == taskId).cast<TaskHierarchyNode?>().firstOrNull;
          if (found != null) {
            node = found;
            projectName = g.project.name;
            projectNodes = g.nodes;
            break;
          }
        }
        if (node == null) return _Error(l.taskInspectorNotFound);

        // Walk parent chain → ancestor list (root-first), used for the
        // breadcrumb above the title.
        final byId = {for (final n in projectNodes) n.id: n};
        final ancestors = <TaskHierarchyNode>[];
        var cursor = node.parentTaskId == null ? null : byId[node.parentTaskId];
        while (cursor != null) {
          ancestors.add(cursor);
          cursor = cursor.parentTaskId == null ? null : byId[cursor.parentTaskId];
        }
        final ancestorChain = ancestors.reversed.toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ancestorChain.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _AncestorBreadcrumb(chain: ancestorChain),
                ),
              Row(
                children: [
                  Icon(
                    node.hasChildren ? Icons.folder_open_outlined : Icons.task_alt_outlined,
                    size: 18,
                    color: node.hasChildren ? theme.colorScheme.primary : theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  if (node.number > 0) ...[
                    Text(
                      node.wbs.isEmpty ? 'MK-${node.number}' : '${node.wbs} · MK-${node.number}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.outline,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(child: _TitleEditor(node: node)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: [
                _Pill(label: projectName ?? '?', icon: Icons.folder_outlined),
                _InlineStatusPicker(node: node),
                _InlineWaitingToggle(node: node),
                _InlinePriorityPicker(node: node),
                _InlineParentPicker(
                  node: node,
                  siblings: groups.firstWhere((g) => g.nodes.any((n) => n.id == taskId)).nodes,
                ),
              ]),
              const SizedBox(height: 16),
              _SectionHeader(l.inspectorSectionNotes),
              _DescriptionEditor(node: node),
              const SizedBox(height: 20),
              _SectionHeader(l.inspectorSectionTimelines),
              _TimelineRow(label: l.timelineL1Origin, timeline: _resolveOrigin(node), node: node, kind: _TimelineKind.origin),
              _TimelineRow(label: l.timelineL2Current, timeline: _resolveCurrent(node), node: node, kind: _TimelineKind.current),
              _TimelineRow(label: l.timelineL3Real, timeline: _resolveReal(node), node: node, kind: _TimelineKind.real, highlightTimed: true),
              const SizedBox(height: 16),
              _SectionHeader(l.inspectorSectionAssignees),
              _AssigneeList(assignments: assignments, resources: resources),
              const SizedBox(height: 16),
              if (node.hasChildren) ...[
                _SectionHeader(l.inspectorSectionChildren),
                _ChildrenList(parentId: node.id, allGroups: groups),
                const SizedBox(height: 16),
              ],
              _SectionHeader(l.inspectorSectionComments),
              TaskCommentsSection(taskId: taskId),
              const SizedBox(height: 20),
              _SectionHeader(l.inspectorSectionRecentChanges),
              _ChangeLogList(taskId: taskId),
              const SizedBox(height: 16),
              _ActionRow(node: node),
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

/// Status pill that doubles as an inline picker. For aggregate (parent)
/// rows it stays read-only — the parent's status is computed from children
/// and editing it directly would be misleading. Leaf rows get a PopupMenu
/// on tap to switch status without opening the modal editor.
class _InlineStatusPicker extends ConsumerWidget {
  final TaskHierarchyNode node;
  const _InlineStatusPicker({required this.node});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = node.hasChildren ? node.computedStatus : node.status;
    final pill = _Pill(
      label: taskStatusDisplay(context, s, aggregated: node.hasChildren),
      icon: Icons.circle,
      color: taskStatusBg(theme, s),
    );
    if (node.hasChildren) return pill;

    return PopupMenuButton<TaskStatus>(
      tooltip: AppL10n.of(context).actionEdit,
      initialValue: node.status,
      itemBuilder: (ctx) => [
        // Planning / PlanReview are bot-driven entry points (set when an
        // agent starts planning / submits an AgentPlan). Letting users
        // select them from the picker would invite meaningless transitions
        // ("why is this PlanReview with no plan?"), so they are hidden
        // here. Other 7 states are user-pickable. Managers can still force
        // these via the API directly if needed.
        for (final v in TaskStatus.values)
          if (v != TaskStatus.Planning && v != TaskStatus.PlanReview)
            PopupMenuItem(
              value: v,
              child: Row(children: [
                Icon(Icons.circle, size: 10, color: taskStatusBg(theme, v)),
                const SizedBox(width: 8),
                Text(taskStatusLabel(context, v)),
              ]),
            ),
      ],
      onSelected: (next) async {
        if (next == node.status) return;
        await _patchTaskStatus(ref, node, next);
      },
      child: pill,
    );
  }
}

/// Priority pill that doubles as an inline picker. Parent rows show the
/// aggregated priority (max of any non-Unset child) read-only — editing it
/// directly would just be overwritten on the next aggregation. Leaf rows
/// get the popup picker so the user can rank work directly.
class _InlinePriorityPicker extends ConsumerWidget {
  final TaskHierarchyNode node;
  const _InlinePriorityPicker({required this.node});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = node.hasChildren ? node.computedPriority : node.priority;
    final pill = _Pill(
      label: taskPriorityDisplay(context, p, aggregated: node.hasChildren),
      icon: taskPriorityIcon(p),
      color: taskPriorityBg(theme, p),
    );
    if (node.hasChildren) return pill;

    return PopupMenuButton<TaskPriority>(
      tooltip: AppL10n.of(context).filterPriority,
      initialValue: p,
      itemBuilder: (ctx) => [
        for (final v in TaskPriority.values)
          PopupMenuItem(
            value: v,
            child: Row(children: [
              Icon(taskPriorityIcon(v), size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(taskPriorityLabel(context, v)),
            ]),
          ),
      ],
      onSelected: (next) async {
        if (next == p) return;
        await _patchTaskPriority(ref, node, next);
      },
      child: pill,
    );
  }
}

/// Toggle the orthogonal "stuck" flag — lifecycle stays put, but a small
/// hourglass overlays the row to flag that progress is blocked on
/// something. Distinct from OnHold (active user pause). Phase 2 will let
/// bots auto-set this when they detect unfinished predecessors; for now
/// it's a pure manual toggle in the inspector. Parents read-only because
/// IsWaiting isn't aggregated yet.
class _InlineWaitingToggle extends ConsumerWidget {
  final TaskHierarchyNode node;
  const _InlineWaitingToggle({required this.node});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final on = node.isWaiting;
    final pill = _Pill(
      label: l.taskWaitingToggle,
      icon: Icons.hourglass_top,
      color: on ? theme.colorScheme.errorContainer : theme.colorScheme.surfaceContainerLowest,
    );
    if (node.hasChildren) return pill;
    return Tooltip(
      message: l.taskWaitingTooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _patchTaskWaiting(ref, node, !on),
        child: pill,
      ),
    );
  }
}

/// Inline parent picker — chip showing current parent (or "최상위") that
/// opens a popup of valid candidates on tap. Self + descendants are
/// excluded to prevent cycles.
class _InlineParentPicker extends ConsumerWidget {
  final TaskHierarchyNode node;
  final List<TaskHierarchyNode> siblings;
  const _InlineParentPicker({required this.node, required this.siblings});

  Set<String> _selfAndDescendants() {
    final byParent = <String?, List<TaskHierarchyNode>>{};
    for (final n in siblings) {
      byParent.putIfAbsent(n.parentTaskId, () => []).add(n);
    }
    final out = <String>{node.id};
    final stack = [node.id];
    while (stack.isNotEmpty) {
      final cur = stack.removeLast();
      for (final c in byParent[cur] ?? const []) {
        if (out.add(c.id)) stack.add(c.id);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final invalid = _selfAndDescendants();
    final candidates = siblings.where((n) => !invalid.contains(n.id)).toList();
    final parentTitle = node.parentTaskId == null
        ? l.taskEditorParentTopLevel
        : siblings.firstWhere(
            (n) => n.id == node.parentTaskId,
            orElse: () => node,
          ).title;
    final pill = _Pill(
      label: parentTitle,
      icon: node.parentTaskId == null ? Icons.account_tree_outlined : Icons.subdirectory_arrow_right,
    );
    return PopupMenuButton<String?>(
      tooltip: l.taskEditorFieldParent,
      initialValue: node.parentTaskId,
      itemBuilder: (ctx) => [
        PopupMenuItem<String?>(
          value: null,
          child: Row(children: [
            const Icon(Icons.account_tree_outlined, size: 14),
            const SizedBox(width: 8),
            Text(l.taskEditorParentTopLevel),
          ]),
        ),
        const PopupMenuDivider(),
        for (final c in candidates)
          PopupMenuItem<String?>(
            value: c.id,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(c.title, overflow: TextOverflow.ellipsis),
            ),
          ),
      ],
      onSelected: (next) async {
        if (next == node.parentTaskId) return;
        await _patchTaskParent(ref, node, next);
      },
      child: pill,
    );
  }
}

/// Inline title editor — single-line text field that swaps in on tap and
/// commits to the API on blur or Enter. Mirrors `_DescriptionEditor` so
/// title and notes feel the same.
class _TitleEditor extends ConsumerStatefulWidget {
  final TaskHierarchyNode node;
  const _TitleEditor({required this.node});

  @override
  ConsumerState<_TitleEditor> createState() => _TitleEditorState();
}

class _TitleEditorState extends ConsumerState<_TitleEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _editing = false;
  String _saved = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _saved = widget.node.title;
    _controller = TextEditingController(text: _saved);
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editing) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant _TitleEditor old) {
    super.didUpdateWidget(old);
    if (old.node.id != widget.node.id || old.node.title != widget.node.title) {
      _saved = widget.node.title;
      _controller.text = _saved;
      _editing = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _commit() async {
    final next = _controller.text.trim();
    if (next.isEmpty || next == _saved) {
      _controller.text = _saved;
      setState(() => _editing = false);
      return;
    }
    setState(() => _saving = true);
    try {
      await _patchTaskTitle(ref, widget.node, next);
      _saved = next;
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _editing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!_editing) {
      return InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () {
          setState(() => _editing = true);
          WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            _saved,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        suffix: _saving
            ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
            : null,
      ),
      onSubmitted: (_) => _commit(),
    );
  }
}

/// Which slot of the task's three-timeline state to edit.
enum _TimelineKind { origin, current, real }

Future<void> _patchTaskStatus(WidgetRef ref, TaskHierarchyNode node, TaskStatus next) async {
  final updated = TaskItem(
    id: node.id,
    projectId: node.projectId,
    parentTaskId: node.parentTaskId,
    title: node.title,
    description: node.description,
    status: next,
    isWaiting: node.isWaiting,
    priority: node.priority,
    originTimeline: node.originTimeline,
    currentTimeline: node.currentTimeline,
    realTimeline: node.realTimeline,
    createdAt: node.createdAt,
    updatedAt: node.updatedAt,
  );
  await ref.read(apiClientProvider).updateTask(node.id, updated);
  ref.invalidate(allHierarchyByProjectProvider);
  ref.invalidate(taskHierarchyProvider(node.projectId));
  ref.invalidate(taskChangeLogsProvider(node.id));
}

Future<void> _patchTaskPriority(WidgetRef ref, TaskHierarchyNode node, TaskPriority next) async {
  final updated = TaskItem(
    id: node.id,
    projectId: node.projectId,
    parentTaskId: node.parentTaskId,
    title: node.title,
    description: node.description,
    status: node.status,
    isWaiting: node.isWaiting,
    priority: next,
    originTimeline: node.originTimeline,
    currentTimeline: node.currentTimeline,
    realTimeline: node.realTimeline,
    createdAt: node.createdAt,
    updatedAt: node.updatedAt,
  );
  await ref.read(apiClientProvider).updateTask(node.id, updated);
  ref.invalidate(allHierarchyByProjectProvider);
  ref.invalidate(taskHierarchyProvider(node.projectId));
  ref.invalidate(taskChangeLogsProvider(node.id));
}

Future<void> _patchTaskWaiting(WidgetRef ref, TaskHierarchyNode node, bool next) async {
  final updated = TaskItem(
    id: node.id,
    projectId: node.projectId,
    parentTaskId: node.parentTaskId,
    title: node.title,
    description: node.description,
    status: node.status,
    isWaiting: next,
    priority: node.priority,
    originTimeline: node.originTimeline,
    currentTimeline: node.currentTimeline,
    realTimeline: node.realTimeline,
    createdAt: node.createdAt,
    updatedAt: node.updatedAt,
  );
  await ref.read(apiClientProvider).updateTask(node.id, updated);
  ref.invalidate(allHierarchyByProjectProvider);
  ref.invalidate(taskHierarchyProvider(node.projectId));
  ref.invalidate(taskChangeLogsProvider(node.id));
}

Future<void> _patchTaskTitle(WidgetRef ref, TaskHierarchyNode node, String next) async {
  final updated = TaskItem(
    id: node.id,
    projectId: node.projectId,
    parentTaskId: node.parentTaskId,
    title: next,
    description: node.description,
    status: node.status,
    priority: node.priority,
    originTimeline: node.originTimeline,
    currentTimeline: node.currentTimeline,
    realTimeline: node.realTimeline,
    createdAt: node.createdAt,
    updatedAt: node.updatedAt,
  );
  await ref.read(apiClientProvider).updateTask(node.id, updated);
  ref.invalidate(allHierarchyByProjectProvider);
  ref.invalidate(taskHierarchyProvider(node.projectId));
  ref.invalidate(taskChangeLogsProvider(node.id));
}

Future<void> _patchTaskParent(WidgetRef ref, TaskHierarchyNode node, String? next) async {
  final updated = TaskItem(
    id: node.id,
    projectId: node.projectId,
    parentTaskId: next,
    title: node.title,
    description: node.description,
    status: node.status,
    priority: node.priority,
    originTimeline: node.originTimeline,
    currentTimeline: node.currentTimeline,
    realTimeline: node.realTimeline,
    createdAt: node.createdAt,
    updatedAt: node.updatedAt,
  );
  await ref.read(apiClientProvider).updateTask(node.id, updated);
  ref.invalidate(allHierarchyByProjectProvider);
  ref.invalidate(taskHierarchyProvider(node.projectId));
  ref.invalidate(taskChangeLogsProvider(node.id));
}

Future<void> _patchTaskTimeline(
  WidgetRef ref,
  TaskHierarchyNode node,
  _TimelineKind kind,
  Timeline next,
) async {
  final updated = TaskItem(
    id: node.id,
    projectId: node.projectId,
    parentTaskId: node.parentTaskId,
    title: node.title,
    description: node.description,
    status: node.status,
    priority: node.priority,
    // Origin is locked once set (per ADR-009): only flip Origin when it was
    // previously empty. Treat it as "first commitment" — afterwards Current
    // is the editable plan and Real is what actually happened.
    originTimeline: kind == _TimelineKind.origin && node.originTimeline.isEmpty
        ? next
        : node.originTimeline,
    currentTimeline: kind == _TimelineKind.current ? next : node.currentTimeline,
    realTimeline: kind == _TimelineKind.real ? next : node.realTimeline,
    createdAt: node.createdAt,
    updatedAt: node.updatedAt,
  );
  await ref.read(apiClientProvider).updateTask(node.id, updated);
  ref.invalidate(allHierarchyByProjectProvider);
  ref.invalidate(taskHierarchyProvider(node.projectId));
  ref.invalidate(taskChangeLogsProvider(node.id));
}

class _TimelineRow extends ConsumerWidget {
  final String label;
  final Timeline timeline;
  final TaskHierarchyNode node;
  final _TimelineKind kind;
  final bool highlightTimed;
  const _TimelineRow({
    required this.label,
    required this.timeline,
    required this.node,
    required this.kind,
    this.highlightTimed = false,
  });

  /// Aggregated parent rows show computed timelines that can't be edited
  /// directly; Origin is locked once first set (per ADR-009).
  bool get _editable {
    if (node.hasChildren) return false;
    if (kind == _TimelineKind.origin && !node.originTimeline.isEmpty) return false;
    return true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final locale = dateLocale(context);
    final dfDate = DateFormat.yMMMd(locale);
    final dfTime = DateFormat.Hm(locale);

    String fmt(DateTime? t) {
      if (t == null) return '?';
      final local = t.toLocal();
      if (timeline.isAllDay) return dfDate.format(local);
      return '${dfDate.format(local)} ${dfTime.format(local)}';
    }

    final l = AppL10n.of(context);
    final body = timeline.isEmpty ? '—' : '${fmt(timeline.start)}  →  ${fmt(timeline.end)}';
    final tag = timeline.isEmpty ? null : (timeline.isAllDay ? l.timelineAllDayBadge : l.timelineTimedBadge);

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
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
                      color: highlightTimed && !timeline.isAllDay
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
          if (_editable)
            Icon(Icons.edit, size: 12, color: theme.colorScheme.outline),
        ],
      ),
    );

    if (!_editable) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        // All-day: anchored inline popover (Linear-style).
        // Timed: existing compact dialog (rarer use, time pickers inherently popup).
        // Pickers internally guard their context across awaits.
        final picked = timeline.isAllDay
            // ignore: use_build_context_synchronously
            ? await showInlineDateRangePopover(context, timeline)
            // ignore: use_build_context_synchronously
            : await pickTimedTimeline(context, timeline);
        if (picked != null) {
          await _patchTaskTimeline(ref, node, kind, picked);
        }
      },
      child: content,
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
                      taskStatusLabel(context, c.hasChildren ? c.computedStatus : c.status),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

/// Notion-like notes / description editor. Displays the saved description
/// when not focused; on tap the field expands into a multiline TextField that
/// PUTs the task on blur or with Cmd/Ctrl+Enter.
class _DescriptionEditor extends ConsumerStatefulWidget {
  final TaskHierarchyNode node;
  const _DescriptionEditor({required this.node});

  @override
  ConsumerState<_DescriptionEditor> createState() => _DescriptionEditorState();
}

class _DescriptionEditorState extends ConsumerState<_DescriptionEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _editing = false;
  String _savedValue = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _savedValue = widget.node.description ?? '';
    _controller = TextEditingController(text: _savedValue);
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editing) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant _DescriptionEditor old) {
    super.didUpdateWidget(old);
    // If the inspector is reopened on a different task, refresh the buffer.
    if (old.node.id != widget.node.id) {
      _savedValue = widget.node.description ?? '';
      _controller.text = _savedValue;
      _editing = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _commit() async {
    final next = _controller.text;
    if (next == _savedValue) {
      setState(() => _editing = false);
      return;
    }
    setState(() => _saving = true);
    try {
      final node = widget.node;
      final updated = TaskItem(
        id: node.id,
        projectId: node.projectId,
        parentTaskId: node.parentTaskId,
        title: node.title,
        description: next.isEmpty ? null : next,
        status: node.status,
        originTimeline: node.originTimeline,
        currentTimeline: node.currentTimeline,
        realTimeline: node.realTimeline,
        createdAt: node.createdAt,
        updatedAt: node.updatedAt,
      );
      await ref.read(apiClientProvider).updateTask(node.id, updated);
      _savedValue = next;
      ref.invalidate(allHierarchyByProjectProvider);
      ref.invalidate(taskHierarchyProvider(node.projectId));
      ref.invalidate(taskChangeLogsProvider(node.id));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _editing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_editing) {
      final text = _savedValue.trim();
      return InkWell(
        onTap: () {
          setState(() => _editing = true);
          WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
          ),
          child: text.isEmpty
              ? Text(
                  AppL10n.of(context).notesPlaceholderEmpty,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
                )
              : Text(text, style: theme.textTheme.bodyMedium),
        ),
      );
    }

    final l = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          maxLines: null,
          minLines: 4,
          decoration: InputDecoration(
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
            hintText: l.notesHint,
            contentPadding: const EdgeInsets.all(10),
          ),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (_saving)
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Text(
                l.notesSaveHint,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
            const Spacer(),
            TextButton(
              onPressed: _saving
                  ? null
                  : () {
                      _controller.text = _savedValue;
                      setState(() => _editing = false);
                    },
              child: Text(l.actionCancel),
            ),
            FilledButton.tonal(
              onPressed: _saving ? null : _commit,
              child: Text(l.actionSave),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionRow extends ConsumerWidget {
  final TaskHierarchyNode node;
  const _ActionRow({required this.node});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    return Row(
      children: [
        TextButton.icon(
          icon: const Icon(Icons.delete_outline, size: 16),
          label: Text(l.actionDelete),
          onPressed: () async {
            final ok = await _confirmDelete(context, node.title);
            if (!ok) return;
            await ref.read(apiClientProvider).deleteTask(node.id);
            ref.invalidate(allHierarchyByProjectProvider);
            ref.invalidate(allAssignmentsProvider);
            ref.invalidate(taskHierarchyProvider(node.projectId));
            ref.invalidate(tasksProvider(node.projectId));
            ref.read(inspectionProvider.notifier).state = null;
          },
        ),
      ],
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String title) async {
    final l = AppL10n.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteTaskTitle),
        content: Text(l.deleteTaskBody(title)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.actionCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.actionDelete),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _ChangeLogList extends ConsumerWidget {
  final String taskId;
  const _ChangeLogList({required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final logs = ref.watch(taskChangeLogsProvider(taskId));
    final df = DateFormat('M/d HH:mm', dateLocale(context));
    return logs.when(
      loading: () => const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Text('$e', style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
      data: (list) {
        if (list.isEmpty) return Text(AppL10n.of(context).notesNoChanges, style: theme.textTheme.bodySmall);
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

/// Root-first ancestor chain shown above the task title. Each crumb is
/// "{wbs} · MK-{number}  Title" and tapping it focuses the inspector
/// on that ancestor — keeps navigation single-handed when drilling
/// in/out of a deep subtree.
class _AncestorBreadcrumb extends ConsumerWidget {
  final List<TaskHierarchyNode> chain;
  const _AncestorBreadcrumb({required this.chain});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.outline,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final children = <Widget>[];
    for (var i = 0; i < chain.length; i++) {
      if (i > 0) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('›', style: style),
        ));
      }
      final n = chain[i];
      final label = n.wbs.isEmpty ? 'MK-${n.number}' : '${n.wbs} · MK-${n.number}';
      children.add(InkWell(
        onTap: () =>
            ref.read(inspectionProvider.notifier).state = TaskInspection(n.id),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Text('$label  ${n.title}', style: style),
        ),
      ));
    }
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: children);
  }
}
