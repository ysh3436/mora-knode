/// Mirrors backend Domain/AgentPlan.cs PlanStatus enum. Backend serializes
/// the enum by name (BsonRepresentation.String) so the wire format is
/// human-readable across migrations.
enum PlanStatus {
  pendingReview,
  approved,
  rejected;

  static PlanStatus parse(Object? v) {
    final n = v?.toString().toLowerCase();
    return switch (n) {
      'approved' => PlanStatus.approved,
      'rejected' => PlanStatus.rejected,
      _ => PlanStatus.pendingReview,
    };
  }

  String get wire => switch (this) {
        PlanStatus.pendingReview => 'PendingReview',
        PlanStatus.approved => 'Approved',
        PlanStatus.rejected => 'Rejected',
      };
}

/// One step inside a plan. Free-form description + optional minute estimate.
/// The backend stores PlanStep as a sub-document inside AgentPlan.Steps.
class PlanStep {
  final String description;
  final int? estimateMinutes;

  const PlanStep({required this.description, this.estimateMinutes});

  factory PlanStep.fromJson(Map<String, dynamic> json) => PlanStep(
        description: (json['description'] as String?) ?? '',
        estimateMinutes: (json['estimateMinutes'] as num?)?.toInt(),
      );
}

/// Mirrors Domain/AgentPlan.cs. PendingReview plans are what the review
/// queue surfaces; Approved / Rejected are terminal and shown in the
/// per-task plan history.
class AgentPlan {
  final String id;
  final String taskId;
  final String submittedByResourceId;
  final PlanStatus status;
  final String title;
  final int? estimateMinutes;
  final List<PlanStep> steps;
  final String? notes;
  final String? reviewerComment;
  final String? reviewedByResourceId;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AgentPlan({
    required this.id,
    required this.taskId,
    required this.submittedByResourceId,
    required this.status,
    required this.title,
    this.estimateMinutes,
    this.steps = const [],
    this.notes,
    this.reviewerComment,
    this.reviewedByResourceId,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AgentPlan.fromJson(Map<String, dynamic> json) => AgentPlan(
        id: json['id'] as String,
        taskId: json['taskId'] as String,
        submittedByResourceId: json['submittedByResourceId'] as String,
        status: PlanStatus.parse(json['status']),
        title: (json['title'] as String?) ?? '',
        estimateMinutes: (json['estimateMinutes'] as num?)?.toInt(),
        steps: ((json['steps'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(PlanStep.fromJson)
            .toList(),
        notes: json['notes'] as String?,
        reviewerComment: json['reviewerComment'] as String?,
        reviewedByResourceId: json['reviewedByResourceId'] as String?,
        reviewedAt: _parseDate(json['reviewedAt']),
        createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
        updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      );

  static DateTime? _parseDate(Object? v) =>
      v == null ? null : DateTime.parse(v as String).toUtc();
}
