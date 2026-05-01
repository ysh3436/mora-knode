import 'task_item.dart';
import 'timeline.dart';

class TaskHierarchyNode {
  final String id;
  final String projectId;
  final String? parentTaskId;
  final int number;
  /// Outline-style ("1.2.3") position label derived per-request from the
  /// current tree state. Stable as long as Number isn't reassigned;
  /// changes if the tree is reordered or moved. Use [number] for
  /// references in conversations and commits — `wbs` is for visual
  /// hierarchy only.
  final String wbs;
  final String title;
  final String? description;
  final TaskStatus status;
  final TaskPriority priority;
  final Timeline originTimeline;
  final Timeline currentTimeline;
  final Timeline realTimeline;
  final bool hasChildren;
  final TaskStatus computedStatus;
  final TaskPriority computedPriority;
  final Timeline computedOriginTimeline;
  final Timeline computedCurrentTimeline;
  final Timeline computedRealTimeline;
  final int assignmentCount;
  final bool nonLeafAssignmentWarning;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TaskHierarchyNode({
    required this.id,
    required this.projectId,
    required this.parentTaskId,
    required this.number,
    required this.wbs,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.originTimeline,
    required this.currentTimeline,
    required this.realTimeline,
    required this.hasChildren,
    required this.computedStatus,
    required this.computedPriority,
    required this.computedOriginTimeline,
    required this.computedCurrentTimeline,
    required this.computedRealTimeline,
    required this.assignmentCount,
    required this.nonLeafAssignmentWarning,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskHierarchyNode.fromJson(Map<String, dynamic> json) => TaskHierarchyNode(
        id: json['id'] as String,
        projectId: json['projectId'] as String,
        parentTaskId: json['parentTaskId'] as String?,
        number: (json['number'] as num?)?.toInt() ?? 0,
        wbs: json['wbs'] as String? ?? '',
        title: json['title'] as String,
        description: json['description'] as String?,
        status: _parseStatus(json['status']),
        priority: _parsePriority(json['priority']),
        originTimeline: Timeline.fromJson(json['originTimeline'] as Map<String, dynamic>?),
        currentTimeline: Timeline.fromJson(json['currentTimeline'] as Map<String, dynamic>?),
        realTimeline: Timeline.fromJson(json['realTimeline'] as Map<String, dynamic>?),
        hasChildren: json['hasChildren'] as bool,
        computedStatus: _parseStatus(json['computedStatus']),
        computedPriority: _parsePriority(json['computedPriority']),
        computedOriginTimeline: Timeline.fromJson(json['computedOriginTimeline'] as Map<String, dynamic>?),
        computedCurrentTimeline: Timeline.fromJson(json['computedCurrentTimeline'] as Map<String, dynamic>?),
        computedRealTimeline: Timeline.fromJson(json['computedRealTimeline'] as Map<String, dynamic>?),
        assignmentCount: (json['assignmentCount'] as num).toInt(),
        nonLeafAssignmentWarning: json['nonLeafAssignmentWarning'] as bool,
        createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
        updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      );

  /// Convert back to a plain TaskItem for edit flows that still use the CRUD endpoint.
  TaskItem toTaskItem() => TaskItem(
        id: id,
        projectId: projectId,
        parentTaskId: parentTaskId,
        number: number,
        title: title,
        description: description,
        status: status,
        priority: priority,
        originTimeline: originTimeline,
        currentTimeline: currentTimeline,
        realTimeline: realTimeline,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  static TaskStatus _parseStatus(Object? v) =>
      TaskStatus.values.firstWhere((s) => s.name == v, orElse: () => TaskStatus.NotStarted);
  static TaskPriority _parsePriority(Object? v) =>
      TaskPriority.values.firstWhere((p) => p.name == v, orElse: () => TaskPriority.Unset);
}

/// Depth-first flatten of hierarchy nodes. Roots and siblings are sorted
/// per parent group using [compare] (defaults to current-timeline-start
/// ascending, the original behaviour). Sorting per group preserves the
/// hierarchical structure — children always appear under their parent
/// regardless of how they would compare to other branches.
/// Returned tuple = (node, depth from 0).
List<(TaskHierarchyNode node, int depth)> flattenHierarchy(
  List<TaskHierarchyNode> nodes, {
  Comparator<TaskHierarchyNode>? compare,
}) {
  final byParent = <String?, List<TaskHierarchyNode>>{};
  for (final n in nodes) {
    byParent.putIfAbsent(n.parentTaskId, () => []).add(n);
  }
  final cmp = compare ?? _defaultCompare;
  for (final list in byParent.values) {
    list.sort(cmp);
  }

  final out = <(TaskHierarchyNode, int)>[];
  void visit(TaskHierarchyNode n, int depth) {
    out.add((n, depth));
    for (final k in byParent[n.id] ?? const []) {
      visit(k, depth + 1);
    }
  }

  for (final r in byParent[null] ?? const <TaskHierarchyNode>[]) {
    visit(r, 0);
  }
  return out;
}

int _defaultCompare(TaskHierarchyNode a, TaskHierarchyNode b) {
  final ka = (a.computedCurrentTimeline.start ?? a.createdAt).millisecondsSinceEpoch;
  final kb = (b.computedCurrentTimeline.start ?? b.createdAt).millisecondsSinceEpoch;
  return ka.compareTo(kb);
}

/// Sort key shared by the tasks workspace (List + Gantt + Calendar).
/// Only "real" keys live here — the implicit fallback (creation order /
/// hierarchy position) is expressed by an empty sort chain, not by an
/// enum value. Declaration order is the dropdown order: stable handle
/// first (Number), then triage signals (Status, Priority), then
/// schedule (Start / Due).
enum TaskSortKey { number, status, priority, startDate, dueDate }

/// Pre-compiled "MK-{N}" search pattern: matches "mk-12", "mk12", "MK-12".
/// Used by the task search box so typing the identifier jumps straight
/// to the task without scanning titles.
final RegExp _mkSearchPattern = RegExp(r'^mk-?(\d+)$');

/// True when [search] (already lowercased + trimmed) selects this node.
/// Two paths: exact "MK-N" → number equality, otherwise title substring.
/// Empty search → always true (caller already short-circuits, but
/// included here for safety).
bool taskHierarchyMatchesSearch(TaskHierarchyNode node, String search) {
  if (search.isEmpty) return true;
  final mk = _mkSearchPattern.firstMatch(search);
  if (mk != null) {
    final n = int.tryParse(mk.group(1)!);
    return n != null && node.number == n;
  }
  return node.title.toLowerCase().contains(search);
}

/// One step in a multi-level (Notion-style) sort. The chain is evaluated
/// left-to-right; the first non-zero result wins, and `_defaultCompare`
/// is the final tie-breaker once the chain is exhausted.
class TaskSortStep {
  final TaskSortKey key;
  final bool asc;
  const TaskSortStep(this.key, {this.asc = true});

  TaskSortStep withAsc(bool v) => TaskSortStep(key, asc: v);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskSortStep && other.key == key && other.asc == asc);

  @override
  int get hashCode => Object.hash(key, asc);
}

/// Hand-crafted ordering for status sort — "active first, terminal last"
/// regardless of the underlying enum integer mapping. Lower number = more
/// active. Used only for UI sort, not for backend logic.
const _statusActiveOrder = <TaskStatus, int>{
  TaskStatus.InProgress: 0,
  TaskStatus.InReview: 1,
  TaskStatus.Blocked: 2,
  TaskStatus.NotStarted: 3,
  TaskStatus.Done: 4,
  TaskStatus.Cancelled: 5,
  TaskStatus.Dropped: 6,
};

/// Hand-crafted ordering for priority sort. The Dart enum's declaration
/// `.index` runs Unset(0) → Urgent(4), which is the *opposite* of the
/// backend integer mapping (Urgent=-20 most urgent, Unset=+100 least), so
/// we cannot rely on `.index` directly — ASC by rank below means "most
/// urgent first" with Unset always at the bottom regardless of direction
/// (DESC then surfaces the lowest-priority ranked rows first while
/// keeping unranked rows at the end).
const _priorityActiveOrder = <TaskPriority, int>{
  TaskPriority.Urgent: 0,
  TaskPriority.High: 1,
  TaskPriority.Normal: 2,
  TaskPriority.Low: 3,
  TaskPriority.Unset: 4,
};

/// Per-step comparator. Returns 0 on tie so the chain executor can fall
/// through to the next step. For aggregate (parent) rows the *computed*
/// values are used so the parent's spot reflects what the user actually
/// sees on the row.
Comparator<TaskHierarchyNode> _stepComparator(TaskSortStep step) {
  int dir(int x) => step.asc ? x : -x;
  switch (step.key) {
    case TaskSortKey.priority:
      // Use _priorityActiveOrder so ASC means "most urgent first" — the
      // Dart enum's declaration index runs the opposite direction from
      // the backend's signed integer mapping (Urgent = -20 backend vs
      // index 4 in Dart), so a manual rank is the only safe choice.
      return (a, b) {
        final pa = _priorityActiveOrder[a.hasChildren ? a.computedPriority : a.priority] ?? 99;
        final pb = _priorityActiveOrder[b.hasChildren ? b.computedPriority : b.priority] ?? 99;
        return dir(pa.compareTo(pb));
      };
    case TaskSortKey.startDate:
      return (a, b) {
        // Aggregate parents use the union start (computed); leaves use
        // their own current timeline start. Tasks without a start date
        // drop to the bottom regardless of direction.
        final sa = (a.hasChildren ? a.computedCurrentTimeline.start : a.currentTimeline.start);
        final sb = (b.hasChildren ? b.computedCurrentTimeline.start : b.currentTimeline.start);
        if (sa == null && sb == null) return 0;
        if (sa == null) return 1;
        if (sb == null) return -1;
        return dir(sa.compareTo(sb));
      };
    case TaskSortKey.dueDate:
      return (a, b) {
        // Aggregate parents use the union end (computed); leaves use their
        // own current timeline end. Tasks without a due date drop to the
        // bottom regardless of direction.
        final ea = (a.hasChildren ? a.computedCurrentTimeline.end : a.currentTimeline.end);
        final eb = (b.hasChildren ? b.computedCurrentTimeline.end : b.currentTimeline.end);
        if (ea == null && eb == null) return 0;
        if (ea == null) return 1;
        if (eb == null) return -1;
        return dir(ea.compareTo(eb));
      };
    case TaskSortKey.status:
      return (a, b) {
        final sa = a.hasChildren ? a.computedStatus : a.status;
        final sb = b.hasChildren ? b.computedStatus : b.status;
        final ra = _statusActiveOrder[sa] ?? 99;
        final rb = _statusActiveOrder[sb] ?? 99;
        return dir(ra.compareTo(rb));
      };
    case TaskSortKey.number:
      // Plain integer compare on the MK-{N} value — same direction as
      // the underlying number, no remapping needed. Tasks that pre-date
      // the migration (number == 0) drop to the bottom regardless of
      // direction so they don't visually crowd the head/tail.
      return (a, b) {
        if (a.number == 0 && b.number == 0) return 0;
        if (a.number == 0) return 1;
        if (b.number == 0) return -1;
        return dir(a.number.compareTo(b.number));
      };
  }
}

/// Build a comparator for [flattenHierarchy] from a Notion-style sort
/// chain. Empty chain → falls through to [_defaultCompare] (creation /
/// hierarchy order). Otherwise each step is tried in turn; the first
/// non-zero result wins, and ties at the end of the chain still defer
/// to [_defaultCompare] for stability.
Comparator<TaskHierarchyNode> taskSortComparator(List<TaskSortStep> chain) {
  if (chain.isEmpty) return _defaultCompare;
  final cmps = chain.map(_stepComparator).toList(growable: false);
  return (a, b) {
    for (final c in cmps) {
      final r = c(a, b);
      if (r != 0) return r;
    }
    return _defaultCompare(a, b);
  };
}
