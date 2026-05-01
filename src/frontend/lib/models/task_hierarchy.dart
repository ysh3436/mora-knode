import 'task_item.dart';
import 'timeline.dart';

class TaskHierarchyNode {
  final String id;
  final String projectId;
  final String? parentTaskId;
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

/// Depth-first flatten of hierarchy nodes. Roots and siblings sorted by current
/// timeline start (then created date). Returned tuple = (node, depth from 0).
List<(TaskHierarchyNode node, int depth)> flattenHierarchy(List<TaskHierarchyNode> nodes) {
  final byParent = <String?, List<TaskHierarchyNode>>{};
  for (final n in nodes) {
    byParent.putIfAbsent(n.parentTaskId, () => []).add(n);
  }
  int sortKey(TaskHierarchyNode n) =>
      (n.computedCurrentTimeline.start ?? n.createdAt).millisecondsSinceEpoch;
  for (final list in byParent.values) {
    list.sort((a, b) => sortKey(a).compareTo(sortKey(b)));
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
