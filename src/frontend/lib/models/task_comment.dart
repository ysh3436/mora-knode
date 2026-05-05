/// Mirrors backend Domain/TaskComment.cs. Body is plain markdown.
class TaskComment {
  final String id;
  final String taskId;
  final String authorResourceId;
  final String body;
  final String? kind;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TaskComment({
    required this.id,
    required this.taskId,
    required this.authorResourceId,
    required this.body,
    this.kind,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskComment.fromJson(Map<String, dynamic> json) => TaskComment(
        id: json['id'] as String,
        taskId: json['taskId'] as String,
        authorResourceId: json['authorResourceId'] as String,
        body: (json['body'] as String?) ?? '',
        kind: json['kind'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
        updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      );
}

