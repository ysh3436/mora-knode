class ResourceLoadBucket {
  final DateTime date;
  final int loadPercent;
  final bool overloaded;
  final bool isWorkDay;

  const ResourceLoadBucket({
    required this.date,
    required this.loadPercent,
    required this.overloaded,
    required this.isWorkDay,
  });

  factory ResourceLoadBucket.fromJson(Map<String, dynamic> json) => ResourceLoadBucket(
        date: DateTime.parse(json['date'] as String).toUtc(),
        loadPercent: (json['loadPercent'] as num).toInt(),
        overloaded: json['overloaded'] as bool,
        isWorkDay: (json['isWorkDay'] as bool?) ?? true,
      );
}

class ResourceLoad {
  final String resourceId;
  final String resourceName;
  final String? resourceRole;
  final String? departmentId;
  final int capacityPercent;
  final List<ResourceLoadBucket> days;

  const ResourceLoad({
    required this.resourceId,
    required this.resourceName,
    this.resourceRole,
    this.departmentId,
    required this.capacityPercent,
    required this.days,
  });

  factory ResourceLoad.fromJson(Map<String, dynamic> json) => ResourceLoad(
        resourceId: json['resourceId'] as String,
        resourceName: json['resourceName'] as String,
        resourceRole: json['resourceRole'] as String?,
        departmentId: json['departmentId'] as String?,
        capacityPercent: (json['capacityPercent'] as num).toInt(),
        days: (json['days'] as List)
            .cast<Map<String, dynamic>>()
            .map(ResourceLoadBucket.fromJson)
            .toList(),
      );
}

/// Wrapper for /api/matrix/load — pairs the row data with the WorkCalendar
/// summary so the UI can show "Mon-Fri 09-18" or the "24/7 fallback" label.
class MatrixLoadResponse {
  final bool isFallbackCalendar;
  final WorkCalendarSummary workCalendar;
  final List<ResourceLoad> rows;

  const MatrixLoadResponse({
    required this.isFallbackCalendar,
    required this.workCalendar,
    required this.rows,
  });

  factory MatrixLoadResponse.fromJson(Map<String, dynamic> json) => MatrixLoadResponse(
        isFallbackCalendar: json['isFallbackCalendar'] as bool,
        workCalendar: WorkCalendarSummary.fromJson(json['workCalendar'] as Map<String, dynamic>),
        rows: (json['rows'] as List)
            .cast<Map<String, dynamic>>()
            .map(ResourceLoad.fromJson)
            .toList(),
      );
}

class WorkCalendarSummary {
  final String workDays;
  final int dailyStartMinutes;
  final int dailyEndMinutes;
  final String timezone;

  const WorkCalendarSummary({
    required this.workDays,
    required this.dailyStartMinutes,
    required this.dailyEndMinutes,
    required this.timezone,
  });

  factory WorkCalendarSummary.fromJson(Map<String, dynamic> json) => WorkCalendarSummary(
        workDays: json['workDays'].toString(),
        dailyStartMinutes: (json['dailyStartMinutes'] as num).toInt(),
        dailyEndMinutes: (json['dailyEndMinutes'] as num).toInt(),
        timezone: json['timezone'] as String,
      );
}
