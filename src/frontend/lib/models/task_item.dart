// Enum values mirror backend Enums.cs TaskStatus exactly (PascalCase) so
// `status.name` round-trips through JSON without a translation table.
// ignore_for_file: constant_identifier_names

import 'timeline.dart';

// Mirror of backend Enums.cs TaskStatus. Stored / serialized by name so the
// integer values are only an ordering hint — anchors at 10/30/50, beats in
// between (InReview 20, Blocked 40), terminal-non-success above Done
// (Cancelled 51, Dropped 52). Declaration order here also drives the
// dropdown / filter order, so keep it ascending.
enum TaskStatus {
  NotStarted,
  InReview,
  InProgress,
  Blocked,
  Done,
  Cancelled,
  Dropped,
}

// Mirror of backend Enums.cs TaskPriority. Same persistence pattern as
// TaskStatus (string by name). Declaration order drives the picker order
// — keep ascending so the dropdown reads from least to most urgent.
enum TaskPriority {
  Unset,
  Low,
  Normal,
  High,
  Urgent,
}

class TaskItem {
  final String? id;
  final String projectId;
  final String? parentTaskId;
  /// Global "MK-{N}" identifier. Assigned by the backend on create; 0
  /// only on documents that pre-date the migration (treated as "no
  /// number" in display).
  final int number;
  final String title;
  final String? description;
  final TaskStatus status;
  final TaskPriority priority;
  final Timeline originTimeline;
  final Timeline currentTimeline;
  final Timeline realTimeline;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Transient fields surfaced when saving an update so the backend can annotate
  // the ScheduleChangeLog.
  final String? changeReason;
  final String? changedBy;

  const TaskItem({
    this.id,
    required this.projectId,
    this.parentTaskId,
    this.number = 0,
    required this.title,
    this.description,
    this.status = TaskStatus.NotStarted,
    this.priority = TaskPriority.Unset,
    this.originTimeline = const Timeline(),
    this.currentTimeline = const Timeline(),
    this.realTimeline = const Timeline(),
    this.createdAt,
    this.updatedAt,
    this.changeReason,
    this.changedBy,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        id: json['id'] as String?,
        projectId: json['projectId'] as String,
        parentTaskId: json['parentTaskId'] as String?,
        number: (json['number'] as num?)?.toInt() ?? 0,
        title: json['title'] as String,
        description: json['description'] as String?,
        status: _parseStatus(json['status']),
        priority: _parsePriority(json['priority']),
        originTimeline: Timeline.fromJson(json['originTimeline'] as Map<String, dynamic>?),
        currentTimeline: Timeline.fromJson(json['currentTimeline'] as Map<String, dynamic>?),
        realTimeline: Timeline.fromJson(json['realTimeline'] as Map<String, dynamic>?),
        createdAt: _parseDate(json['createdAt']),
        updatedAt: _parseDate(json['updatedAt']),
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'projectId': projectId,
        'parentTaskId': parentTaskId,
        'number': number,
        'title': title,
        'description': description,
        'status': status.name,
        'priority': priority.name,
        'originTimeline': originTimeline.toJson(),
        'currentTimeline': currentTimeline.toJson(),
        'realTimeline': realTimeline.toJson(),
        if (changeReason != null) 'changeReason': changeReason,
        if (changedBy != null) 'changedBy': changedBy,
      };

  TaskItem copyWith({
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    Timeline? currentTimeline,
    Timeline? realTimeline,
    String? changeReason,
    String? changedBy,
  }) {
    return TaskItem(
      id: id,
      projectId: projectId,
      parentTaskId: parentTaskId,
      number: number,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      originTimeline: originTimeline,
      currentTimeline: currentTimeline ?? this.currentTimeline,
      realTimeline: realTimeline ?? this.realTimeline,
      createdAt: createdAt,
      updatedAt: updatedAt,
      changeReason: changeReason ?? this.changeReason,
      changedBy: changedBy ?? this.changedBy,
    );
  }

  static TaskStatus _parseStatus(Object? v) =>
      TaskStatus.values.firstWhere((s) => s.name == v, orElse: () => TaskStatus.NotStarted);
  static TaskPriority _parsePriority(Object? v) =>
      TaskPriority.values.firstWhere((p) => p.name == v, orElse: () => TaskPriority.Unset);
  static DateTime? _parseDate(Object? v) => v == null ? null : DateTime.parse(v as String).toUtc();
}
