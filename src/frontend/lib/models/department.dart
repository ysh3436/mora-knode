/// Mirrors src/backend/Domain/Department.cs. The matrix's "functional"
/// axis: every Resource sits in at most one Department, and Departments
/// form a single-parent tree (multi-parent / DAG deferred to v1.1). A
/// matrix filter against a department subtree resolves to "every
/// resource reporting under this node, transitively".
class Department {
  final String? id;
  final String name;
  final String? description;
  final String? parentDepartmentId;
  final String? leadResourceId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Department({
    this.id,
    required this.name,
    this.description,
    this.parentDepartmentId,
    this.leadResourceId,
    this.createdAt,
    this.updatedAt,
  });

  factory Department.fromJson(Map<String, dynamic> json) => Department(
        id: json['id'] as String?,
        name: json['name'] as String,
        description: json['description'] as String?,
        parentDepartmentId: json['parentDepartmentId'] as String?,
        leadResourceId: json['leadResourceId'] as String?,
        createdAt: _parseDate(json['createdAt']),
        updatedAt: _parseDate(json['updatedAt']),
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        if (description != null) 'description': description,
        if (parentDepartmentId != null) 'parentDepartmentId': parentDepartmentId,
        if (leadResourceId != null) 'leadResourceId': leadResourceId,
      };

  static DateTime? _parseDate(Object? v) =>
      v == null ? null : DateTime.parse(v as String).toUtc();
}
