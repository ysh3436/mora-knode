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

const double _kRowHeight = 36;

/// Tree-style list of tasks. Project headers and parent tasks pin to the top
/// as nested sticky layers — outer scopes stay visible while their descendants
/// scroll past. Collapse state is shared with Gantt.
///
/// When [scopeProjectId] is null, projects are grouped under sticky project
/// headers. When set, the list is scoped to one project and the project header
/// row is skipped (the host page already names the project).
class TasksList extends ConsumerStatefulWidget {
  final String? scopeProjectId;
  const TasksList({super.key, this.scopeProjectId});

  @override
  ConsumerState<TasksList> createState() => _TasksListState();
}

class _TasksListState extends ConsumerState<TasksList> {
  late final ScrollController _vCtrl = ScrollController();

  @override
  void dispose() {
    _vCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final agg = ref.watch(allHierarchyByProjectProvider);
    final assignments = ref.watch(allAssignmentsProvider);
    final resources = ref.watch(resourcesProvider);
    final projectFilter = ref.watch(projectFilterProvider);
    final assigneeFilter = ref.watch(assigneeFilterProvider);
    final statusFilter = ref.watch(statusFilterProvider);
    final search = ref.watch(searchQueryProvider).toLowerCase().trim();
    final sortChain = ref.watch(taskSortChainProvider);
    final selected = ref.watch(inspectionProvider);
    final collapsed = ref.watch(collapsedNodesProvider);

    if (agg.isLoading || assignments.isLoading || resources.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (agg.hasError) return Center(child: Text(l.errorPrefix(agg.error.toString())));

    final groups = agg.value ?? const <ProjectHierarchy>[];
    final assignmentsByTask = <String, List<Assignment>>{};
    for (final a in assignments.value ?? const <Assignment>[]) {
      assignmentsByTask.putIfAbsent(a.taskId, () => []).add(a);
    }
    final resourceById = {for (final r in (resources.value ?? const <Resource>[])) r.id!: r};

    // Scoped mode: force the project filter to the host project; chip is
    // hidden in TasksFilters so the user can't override.
    final scopeId = widget.scopeProjectId;
    final effectiveProjectFilter = scopeId != null ? <String>{scopeId} : projectFilter;
    final showProjectHeaders = scopeId == null;

    final rows = <_Row>[];
    for (final g in groups) {
      if (effectiveProjectFilter.isNotEmpty && !effectiveProjectFilter.contains(g.project.id)) continue;
      final taskRows = _buildTaskRowsForProject(
        g,
        assignmentsByTask: assignmentsByTask,
        resourceById: resourceById,
        assigneeFilter: assigneeFilter,
        statusFilter: statusFilter,
        search: search,
        collapsed: collapsed,
        sortChain: sortChain,
      );
      if (taskRows.isEmpty) continue;
      if (showProjectHeaders) {
        final pkey = 'proj:${g.project.id}';
        final pCollapsed = collapsed.contains(pkey);
        rows.add(_ProjectRow(
          key: pkey,
          title: g.project.name,
          taskCount: taskRows.length,
          isCollapsed: pCollapsed,
        ));
        if (!pCollapsed) {
          rows.addAll(taskRows);
        }
      } else {
        rows.addAll(taskRows);
      }
    }

    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Text(
            l.filterNoMatch,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
      );
    }

    return Stack(
      children: [
        CustomScrollView(
          controller: _vCtrl,
          slivers: [
            SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (ctx, i) => _buildRow(rows[i], selected),
            ),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedBuilder(
            animation: _vCtrl,
            builder: (ctx, _) {
              final off = _vCtrl.hasClients ? _vCtrl.offset : 0.0;
              return _ListStickyAncestorStack(
                rows: rows,
                rowHeight: _kRowHeight,
                scrollOffset: off,
                collapsed: collapsed,
                onTap: _open,
                onToggleCollapse: (key) => _toggle(key),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRow(_Row row, Inspection? selected) {
    return switch (row) {
      _ProjectRow r => _ProjectHeaderRow(
          row: r,
          onToggle: () => _toggle(r.key),
        ),
      _TaskListRow t => _TaskRow(
          row: t.row,
          isSelected: selected is TaskInspection && selected.taskId == t.row.node.id,
          isCollapsed: t.isCollapsed,
          onTap: () => _open(t.row.node.id),
          onToggleCollapse: t.row.node.hasChildren ? () => _toggle(t.row.node.id) : null,
        ),
    };
  }

  void _open(String id) {
    if (id.startsWith('proj:')) return;
    ref.read(inspectionProvider.notifier).state = TaskInspection(id);
    ref.read(inspectorOpenProvider.notifier).state = true;
  }

  void _toggle(String key) {
    final notifier = ref.read(collapsedNodesProvider.notifier);
    final cur = ref.read(collapsedNodesProvider);
    final next = {...cur};
    if (!next.remove(key)) next.add(key);
    notifier.state = next;
  }

  List<_TaskListRow> _buildTaskRowsForProject(
    ProjectHierarchy g, {
    required Map<String, List<Assignment>> assignmentsByTask,
    required Map<String, Resource> resourceById,
    required Set<String> assigneeFilter,
    required Set<TaskStatus> statusFilter,
    required String search,
    required Set<String> collapsed,
    required List<TaskSortStep> sortChain,
  }) {
    final out = <_TaskListRow>[];
    final flat = flattenHierarchy(g.nodes, compare: taskSortComparator(sortChain));
    final hiddenAncestor = <String>{};
    for (final entry in flat) {
      final node = entry.$1;
      final depth = entry.$2;

      if (node.parentTaskId != null && hiddenAncestor.contains(node.parentTaskId)) {
        if (node.hasChildren) hiddenAncestor.add(node.id);
        continue;
      }
      if (node.hasChildren && collapsed.contains(node.id)) {
        hiddenAncestor.add(node.id);
      }

      if (search.isNotEmpty && !taskHierarchyMatchesSearch(node, search)) continue;

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

      out.add(_TaskListRow(
        row: _FlatRow(
          node: node,
          depth: depth,
          projectName: g.project.name,
          assignees: assigns.map((a) => resourceById[a.resourceId]).whereType<Resource>().toList(),
        ),
        isCollapsed: node.hasChildren && collapsed.contains(node.id),
      ));
    }
    return out;
  }
}

// --- Row model -----------------------------------------------------------

sealed class _Row {
  String get key;
  int get depth; // -1 for project header; 0+ for task rows
  bool get isSticky; // does this row pin?
}

class _ProjectRow extends _Row {
  @override
  final String key;
  final String title;
  final int taskCount;
  final bool isCollapsed;
  _ProjectRow({
    required this.key,
    required this.title,
    required this.taskCount,
    required this.isCollapsed,
  });
  @override
  int get depth => -1;
  @override
  bool get isSticky => true;
}

class _TaskListRow extends _Row {
  final _FlatRow row;
  final bool isCollapsed;
  _TaskListRow({required this.row, required this.isCollapsed});
  @override
  String get key => row.node.id;
  @override
  int get depth => row.depth;
  @override
  bool get isSticky => row.node.hasChildren;
}

class _FlatRow {
  final TaskHierarchyNode node;
  final int depth;
  final String projectName;
  final List<Resource> assignees;
  _FlatRow({required this.node, required this.depth, required this.projectName, required this.assignees});
}

// --- Project header row --------------------------------------------------

class _ProjectHeaderRow extends StatelessWidget {
  final _ProjectRow row;
  final VoidCallback onToggle;
  const _ProjectHeaderRow({required this.row, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: InkWell(
        onTap: onToggle,
        child: Container(
          height: _kRowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.dividerColor),
              top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
            ),
          ),
          child: Row(
            children: [
              Icon(
                row.isCollapsed ? Icons.chevron_right : Icons.expand_more,
                size: 18,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: 4),
              Icon(Icons.folder, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                row.title,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Text(
                '(${row.taskCount})',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Task row ------------------------------------------------------------

class _TaskRow extends StatelessWidget {
  final _FlatRow row;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;
  final VoidCallback? onToggleCollapse;

  const _TaskRow({
    required this.row,
    required this.isSelected,
    required this.isCollapsed,
    required this.onTap,
    required this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final node = row.node;
    final df = DateFormat('M/d', dateLocale(context));
    final timeline = node.hasChildren ? node.computedCurrentTimeline : node.currentTimeline;
    final status = node.hasChildren ? node.computedStatus : node.status;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: _kRowHeight,
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.5) : null,
            border: Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3))),
          ),
          // Base 28 (vs project header chevron at 12) so a depth-0 task
          // visibly sits *under* the project. Per-depth step is 18 — small
          // enough that 4-deep trees still fit, large enough to read.
          padding: EdgeInsets.fromLTRB(28 + row.depth * 18.0, 0, 12, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Disclosure column: chevron toggle for folders, blank
              // 22 px reservation for leaves. Hit area = the full
              // 22×22 box so a slightly imprecise click still toggles.
              SizedBox(
                width: 22,
                height: 22,
                child: node.hasChildren
                    ? Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onToggleCollapse,
                          borderRadius: BorderRadius.circular(4),
                          child: Center(
                            child: Icon(
                              isCollapsed ? Icons.chevron_right : Icons.expand_more,
                              size: 16,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
              // Kind icon — wrapped in a fixed centred 16×16 box so
              // folder_open_outlined and task_alt_outlined (whose
              // visible glyphs differ in width inside their default
              // square) share the same x for siblings.
              SizedBox(
                width: 16,
                height: 16,
                child: Center(
                  child: Icon(
                    node.hasChildren ? Icons.folder_open_outlined : Icons.task_alt_outlined,
                    size: 14,
                    color: node.hasChildren ? theme.colorScheme.primary : theme.colorScheme.outline,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    if (node.number > 0) ...[
                      _NumberBadge(number: node.number, wbs: node.wbs),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        node.title,
                        style: node.hasChildren
                            ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
                            : theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 100,
                child: Row(children: [
                  Flexible(child: _statusChip(context, theme, status, aggregated: node.hasChildren)),
                  if (node.isWaiting) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: AppL10n.of(context).taskWaitingTooltip,
                      child: Icon(Icons.hourglass_top, size: 14, color: theme.colorScheme.error),
                    ),
                  ],
                ]),
              ),
              SizedBox(
                width: 80,
                child: _priorityChip(
                  context,
                  theme,
                  node.hasChildren ? node.computedPriority : node.priority,
                  aggregated: node.hasChildren,
                ),
              ),
              SizedBox(width: 140, child: _assigneeStrip(theme, row.assignees)),
              SizedBox(width: 110, child: _timelineCell(theme, timeline, df)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(BuildContext context, ThemeData theme, TaskStatus status, {required bool aggregated}) {
    final color = taskStatusBg(theme, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(
        taskStatusDisplay(context, status, aggregated: aggregated),
        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Empty when priority is Unset — keeps the column width stable without
  /// adding visual noise for unranked tasks (the common case at first).
  Widget _priorityChip(BuildContext context, ThemeData theme, TaskPriority priority, {required bool aggregated}) {
    if (priority == TaskPriority.Unset) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: taskPriorityBg(theme, priority),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(taskPriorityIcon(priority), size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              taskPriorityDisplay(context, priority, aggregated: aggregated),
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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

// --- Sticky overlay ------------------------------------------------------

/// Overlay that renders the current ancestor stack (project + parent tasks)
/// pinned at the top of the list. Walks rows forward up to scrollOffset and
/// keeps the latest sticky-eligible row at each depth.
class _ListStickyAncestorStack extends StatelessWidget {
  final List<_Row> rows;
  final double rowHeight;
  final double scrollOffset;
  final Set<String> collapsed;
  final void Function(String id) onTap;
  final void Function(String key) onToggleCollapse;

  const _ListStickyAncestorStack({
    required this.rows,
    required this.rowHeight,
    required this.scrollOffset,
    required this.collapsed,
    required this.onTap,
    required this.onToggleCollapse,
  });

  /// Standard multi-level sticky algorithm (iOS-Calendar / Slack-channels):
  /// 1. Walk rows in order, building a depth-stack of "in-scope" sticky
  ///    ancestors of the current scroll position.
  /// 2. A sticky row pins when its top has scrolled past the bottom of its
  ///    would-be slot (rTop - slotY <= scrollOffset).
  /// 3. A sticky row pops once its entire subtree is above viewport top.
  /// 4. Refinement: drop a pinned row whose entire subtree is already covered
  ///    by the overlay — the user no longer sees any of its content, so the
  ///    breadcrumb is no longer meaningful.
  List<int> _computeStack() {
    if (rows.isEmpty) return const [];
    final stack = <int>[];

    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final rTop = i * rowHeight;

      // Pop ancestors whose subtree is fully behind us.
      while (stack.isNotEmpty) {
        final lastIdx = stack.last;
        final lastEnd = _subtreeEnd(lastIdx) * rowHeight;
        if (scrollOffset >= lastEnd) {
          stack.removeLast();
        } else {
          break;
        }
      }

      if (r.isSticky) {
        // If a same-or-shallower-depth previous sticky is still in stack,
        // its section hasn't ended yet — we haven't reached this one.
        if (stack.isNotEmpty && rows[stack.last].depth >= r.depth) break;
        final slotY = stack.length * rowHeight;
        if (scrollOffset >= rTop - slotY) {
          stack.add(i);
        } else {
          break;
        }
      } else {
        if (rTop > scrollOffset) break;
      }
    }

    // Refinement: if the deepest sticky's entire subtree is hidden behind the
    // overlay, drop it (no descendants visible → not a useful breadcrumb).
    while (stack.length > 1) {
      final lastIdx = stack.last;
      final lastEnd = _subtreeEnd(lastIdx) * rowHeight;
      final stackHeight = stack.length * rowHeight;
      if (lastEnd > scrollOffset + stackHeight) break;
      stack.removeLast();
    }

    return stack;
  }

  /// Returns idx-just-past-last-descendant (exclusive end) of row [idx].
  int _subtreeEnd(int idx) {
    final d = rows[idx].depth;
    for (var j = idx + 1; j < rows.length; j++) {
      if (rows[j].depth <= d) return j;
    }
    return rows.length;
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final stack = _computeStack();
    if (stack.isEmpty) return const SizedBox.shrink();

    // Push-up: when the next sticky row of equal-or-shallower depth is close,
    // slide the whole stack up so the deepest pin gets pushed off cleanly.
    double topOffset = 0;
    final deepestDepth = rows[stack.last].depth;
    final stackHeight = stack.length * rowHeight;
    for (var i = stack.last + 1; i < rows.length; i++) {
      if (!rows[i].isSticky) continue;
      if (rows[i].depth > deepestDepth) continue;
      final delta = (i * rowHeight) - scrollOffset;
      if (delta < stackHeight) topOffset = delta - stackHeight;
      break;
    }

    return Transform.translate(
      offset: Offset(0, topOffset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final idx in stack) _stickyRow(context, rows[idx]),
        ],
      ),
    );
  }

  Widget _stickyRow(BuildContext context, _Row r) {
    return switch (r) {
      _ProjectRow p => _ProjectHeaderRow(
          row: p,
          onToggle: () => onToggleCollapse(p.key),
        ),
      _TaskListRow t => _StickyTaskRow(
          row: t.row,
          isCollapsed: t.isCollapsed,
          onTap: () => onTap(t.row.node.id),
          onToggleCollapse: () => onToggleCollapse(t.row.node.id),
        ),
    };
  }
}

/// Compact single-line render of a parent task for the sticky overlay.
/// Mirrors `_TaskRow` columns but uses an opaque background so the rows
/// scrolling underneath don't bleed through.
class _StickyTaskRow extends StatelessWidget {
  final _FlatRow row;
  final bool isCollapsed;
  final VoidCallback onTap;
  final VoidCallback onToggleCollapse;
  const _StickyTaskRow({
    required this.row,
    required this.isCollapsed,
    required this.onTap,
    required this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final node = row.node;
    final df = DateFormat('M/d', dateLocale(context));
    final timeline = node.hasChildren ? node.computedCurrentTimeline : node.currentTimeline;
    final status = node.hasChildren ? node.computedStatus : node.status;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: _kRowHeight,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          // Base 28 (vs project header chevron at 12) so a depth-0 task
          // visibly sits *under* the project. Per-depth step is 18 — small
          // enough that 4-deep trees still fit, large enough to read.
          padding: EdgeInsets.fromLTRB(28 + row.depth * 18.0, 0, 12, 0),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: InkWell(
                  onTap: onToggleCollapse,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      isCollapsed ? Icons.chevron_right : Icons.expand_more,
                      size: 16,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              ),
              Icon(Icons.folder_open_outlined, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    if (node.number > 0) ...[
                      _NumberBadge(number: node.number, wbs: node.wbs),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        node.title,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 100,
                child: Row(children: [
                  Flexible(child: _statusChip(context, theme, status)),
                  if (node.isWaiting) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: AppL10n.of(context).taskWaitingTooltip,
                      child: Icon(Icons.hourglass_top, size: 14, color: theme.colorScheme.error),
                    ),
                  ],
                ]),
              ),
              SizedBox(width: 80, child: _priorityChip(context, theme, node.computedPriority, aggregated: true)),
              const SizedBox(width: 140), // assignees space (kept blank to match column widths)
              SizedBox(width: 110, child: _timelineCell(theme, timeline, df)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(BuildContext context, ThemeData theme, TaskStatus status) {
    final color = taskStatusBg(theme, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(
        taskStatusDisplay(context, status, aggregated: true),
        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Same as the leaf-row variant — empty for Unset to keep column width
  /// stable without visual noise on unranked tasks.
  Widget _priorityChip(BuildContext context, ThemeData theme, TaskPriority priority, {required bool aggregated}) {
    if (priority == TaskPriority.Unset) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: taskPriorityBg(theme, priority),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(taskPriorityIcon(priority), size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              taskPriorityDisplay(context, priority, aggregated: aggregated),
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineCell(ThemeData theme, Timeline t, DateFormat df) {
    if (t.isEmpty) return Text('—', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline));
    final s = t.start != null ? df.format(t.start!.toLocal()) : '?';
    final e = t.end != null ? df.format(t.end!.toLocal()) : '?';
    return Text('$s → $e${t.isAllDay ? '' : ' ⏱'}', style: theme.textTheme.bodySmall);
  }
}

/// Compact identifier shown before the title cell. Renders both the
/// stable "MK-12" key (use this when referring to the task in chat or
/// commits) and the derived "1.2.3" outline position so the visual
/// hierarchy is readable at a glance.
class _NumberBadge extends StatelessWidget {
  final int number;
  final String wbs;
  const _NumberBadge({required this.number, required this.wbs});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.outline,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    if (wbs.isEmpty) {
      return Text('MK-$number', style: style);
    }
    return Text('$wbs · MK-$number', style: style);
  }
}
