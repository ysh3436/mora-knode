class Assignment {
  final String? id;
  final String resourceId;
  final String taskId;
  final int allocationPercent;
  final DateTime start;
  final DateTime end;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Assignment({
    this.id,
    required this.resourceId,
    required this.taskId,
    required this.allocationPercent,
    required this.start,
    required this.end,
    this.createdAt,
    this.updatedAt,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) => Assignment(
        id: json['id'] as String?,
        resourceId: json['resourceId'] as String,
        taskId: json['taskId'] as String,
        allocationPercent: (json['allocationPercent'] as num).toInt(),
        start: DateTime.parse(json['start'] as String).toUtc(),
        end: DateTime.parse(json['end'] as String).toUtc(),
        createdAt: _parseDate(json['createdAt']),
        updatedAt: _parseDate(json['updatedAt']),
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'resourceId': resourceId,
        'taskId': taskId,
        'allocationPercent': allocationPercent,
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
      };

  static DateTime? _parseDate(Object? v) => v == null ? null : DateTime.parse(v as String).toUtc();
}
