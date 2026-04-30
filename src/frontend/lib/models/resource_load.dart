class ResourceLoadBucket {
  final DateTime date;
  final int loadPercent;
  final bool overloaded;

  const ResourceLoadBucket({
    required this.date,
    required this.loadPercent,
    required this.overloaded,
  });

  factory ResourceLoadBucket.fromJson(Map<String, dynamic> json) => ResourceLoadBucket(
        date: DateTime.parse(json['date'] as String).toUtc(),
        loadPercent: (json['loadPercent'] as num).toInt(),
        overloaded: json['overloaded'] as bool,
      );
}

class ResourceLoad {
  final String resourceId;
  final String resourceName;
  final String? resourceRole;
  final int capacityPercent;
  final List<ResourceLoadBucket> days;

  const ResourceLoad({
    required this.resourceId,
    required this.resourceName,
    this.resourceRole,
    required this.capacityPercent,
    required this.days,
  });

  factory ResourceLoad.fromJson(Map<String, dynamic> json) => ResourceLoad(
        resourceId: json['resourceId'] as String,
        resourceName: json['resourceName'] as String,
        resourceRole: json['resourceRole'] as String?,
        capacityPercent: (json['capacityPercent'] as num).toInt(),
        days: (json['days'] as List)
            .cast<Map<String, dynamic>>()
            .map(ResourceLoadBucket.fromJson)
            .toList(),
      );
}
