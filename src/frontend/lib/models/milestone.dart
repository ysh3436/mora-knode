// ignore: constant_identifier_names
enum MilestoneStatus { Upcoming, Reached, Missed }

class Milestone {
  final String? id;
  final String projectId;
  final String title;
  final DateTime date;
  final MilestoneStatus status;

  const Milestone({
    this.id,
    required this.projectId,
    required this.title,
    required this.date,
    this.status = MilestoneStatus.Upcoming,
  });

  factory Milestone.fromJson(Map<String, dynamic> json) => Milestone(
        id: json['id'] as String?,
        projectId: json['projectId'] as String,
        title: json['title'] as String,
        date: DateTime.parse(json['date'] as String).toUtc(),
        status: _parseStatus(json['status']),
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'projectId': projectId,
        'title': title,
        'date': date.toUtc().toIso8601String(),
        'status': status.name,
      };

  static MilestoneStatus _parseStatus(Object? v) =>
      MilestoneStatus.values.firstWhere((s) => s.name == v, orElse: () => MilestoneStatus.Upcoming);
}
