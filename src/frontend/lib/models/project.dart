// ignore: constant_identifier_names
enum ProjectStatus { Planning, Active, OnHold, Done, Archived }

class Project {
  final String? id;
  final String name;
  final String? description;
  final ProjectStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Project({
    this.id,
    required this.name,
    this.description,
    this.status = ProjectStatus.Planning,
    this.createdAt,
    this.updatedAt,
  });

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String?,
        name: json['name'] as String,
        description: json['description'] as String?,
        status: _parseStatus(json['status']),
        createdAt: _parseDate(json['createdAt']),
        updatedAt: _parseDate(json['updatedAt']),
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        'description': description,
        'status': status.name,
      };

  static ProjectStatus _parseStatus(Object? v) =>
      ProjectStatus.values.firstWhere((s) => s.name == v, orElse: () => ProjectStatus.Planning);
  static DateTime? _parseDate(Object? v) => v == null ? null : DateTime.parse(v as String).toUtc();
}
