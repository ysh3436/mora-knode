// ignore: constant_identifier_names
enum ChangeEntityType { Project, Task, Milestone }

class ChangeLog {
  final String id;
  final ChangeEntityType entityType;
  final String entityId;
  final String field;
  final String? beforeValue;
  final String? afterValue;
  final String? reason;
  final String? changedBy;
  final DateTime changedAt;

  const ChangeLog({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.field,
    this.beforeValue,
    this.afterValue,
    this.reason,
    this.changedBy,
    required this.changedAt,
  });

  factory ChangeLog.fromJson(Map<String, dynamic> json) => ChangeLog(
        id: json['id'] as String,
        entityType: ChangeEntityType.values.firstWhere(
          (e) => e.name == json['entityType'],
          orElse: () => ChangeEntityType.Task,
        ),
        entityId: json['entityId'] as String,
        field: json['field'] as String,
        beforeValue: json['beforeValue'] as String?,
        afterValue: json['afterValue'] as String?,
        reason: json['reason'] as String?,
        changedBy: json['changedBy'] as String?,
        changedAt: DateTime.parse(json['changedAt'] as String).toUtc(),
      );
}
