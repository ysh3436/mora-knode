// Mirrors src/backend/Domain/Enums.cs ResourceKind. Backend serializes the
// enum by name (Human / Agent) so the wire format stays human-readable.
enum ResourceKindFE {
  human,
  agent;

  static ResourceKindFE parse(Object? v) {
    final name = v?.toString().toLowerCase();
    return name == 'agent' ? ResourceKindFE.agent : ResourceKindFE.human;
  }

  String get wire => switch (this) {
        ResourceKindFE.human => 'Human',
        ResourceKindFE.agent => 'Agent',
      };
}

// Mirrors src/backend/Domain/Enums.cs RbacPreset.
enum RbacPresetFE {
  manager,
  reviewer,
  developer,
  qa,
  human;

  static RbacPresetFE parse(Object? v) {
    final name = v?.toString().toLowerCase();
    return switch (name) {
      'manager' => RbacPresetFE.manager,
      'reviewer' => RbacPresetFE.reviewer,
      'developer' => RbacPresetFE.developer,
      'qa' => RbacPresetFE.qa,
      _ => RbacPresetFE.human,
    };
  }

  String get wire => switch (this) {
        RbacPresetFE.manager => 'Manager',
        RbacPresetFE.reviewer => 'Reviewer',
        RbacPresetFE.developer => 'Developer',
        RbacPresetFE.qa => 'QA',
        RbacPresetFE.human => 'Human',
      };

  String get label => switch (this) {
        RbacPresetFE.manager => 'Manager',
        RbacPresetFE.reviewer => 'Reviewer',
        RbacPresetFE.developer => 'Developer',
        RbacPresetFE.qa => 'QA',
        RbacPresetFE.human => 'Human',
      };

  /// Admin-equivalent presets see all data (no view-scope filtering applied
  /// on the backend). Mirrors UserContext.IsAdmin in src/backend/Auth.
  bool get isAdmin =>
      this == RbacPresetFE.manager ||
      this == RbacPresetFE.reviewer ||
      this == RbacPresetFE.human;
}

class Resource {
  final String? id;
  final String name;
  final String? role;
  final int capacityPercent;
  final ResourceKindFE kind;
  final RbacPresetFE rbac;
  final String? agentDescription;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Resource({
    this.id,
    required this.name,
    this.role,
    this.capacityPercent = 100,
    this.kind = ResourceKindFE.human,
    this.rbac = RbacPresetFE.human,
    this.agentDescription,
    this.createdAt,
    this.updatedAt,
  });

  factory Resource.fromJson(Map<String, dynamic> json) => Resource(
        id: json['id'] as String?,
        name: json['name'] as String,
        role: json['role'] as String?,
        capacityPercent: (json['capacityPercent'] as num?)?.toInt() ?? 100,
        kind: ResourceKindFE.parse(json['kind']),
        rbac: RbacPresetFE.parse(json['rbac']),
        agentDescription: json['agentDescription'] as String?,
        createdAt: _parseDate(json['createdAt']),
        updatedAt: _parseDate(json['updatedAt']),
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        'role': role,
        'capacityPercent': capacityPercent,
        'kind': kind.wire,
        'rbac': rbac.wire,
        if (agentDescription != null) 'agentDescription': agentDescription,
      };

  static DateTime? _parseDate(Object? v) => v == null ? null : DateTime.parse(v as String).toUtc();
}
