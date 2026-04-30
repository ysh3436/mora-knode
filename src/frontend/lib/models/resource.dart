class Resource {
  final String? id;
  final String name;
  final String? role;
  final int capacityPercent;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Resource({
    this.id,
    required this.name,
    this.role,
    this.capacityPercent = 100,
    this.createdAt,
    this.updatedAt,
  });

  factory Resource.fromJson(Map<String, dynamic> json) => Resource(
        id: json['id'] as String?,
        name: json['name'] as String,
        role: json['role'] as String?,
        capacityPercent: (json['capacityPercent'] as num?)?.toInt() ?? 100,
        createdAt: _parseDate(json['createdAt']),
        updatedAt: _parseDate(json['updatedAt']),
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        'role': role,
        'capacityPercent': capacityPercent,
      };

  static DateTime? _parseDate(Object? v) => v == null ? null : DateTime.parse(v as String).toUtc();
}
