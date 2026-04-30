/// Mirrors src/backend/Domain/WorkDayMask. Stored bitmask is the same
/// integer encoding as the backend Flags enum.
class WorkDays {
  static const int mon = 1 << 0;
  static const int tue = 1 << 1;
  static const int wed = 1 << 2;
  static const int thu = 1 << 3;
  static const int fri = 1 << 4;
  static const int sat = 1 << 5;
  static const int sun = 1 << 6;
  static const int monToFri = mon | tue | wed | thu | fri;
  static const int all = monToFri | sat | sun;

  static const ordered = <(String label, int mask)>[
    ('Mon', mon),
    ('Tue', tue),
    ('Wed', wed),
    ('Thu', thu),
    ('Fri', fri),
    ('Sat', sat),
    ('Sun', sun),
  ];

  /// Backend serializes as either an integer or a comma list of names. We
  /// accept both shapes here so the client never crashes on a wire change.
  static int parse(Object? raw) {
    if (raw is num) return raw.toInt();
    if (raw is String) {
      // Could be "MonToFri" or "Mon, Tue, Wed".
      if (raw == 'All') return all;
      if (raw == 'MonToFri') return monToFri;
      if (raw == 'None' || raw.isEmpty) return 0;
      var mask = 0;
      for (final part in raw.split(',')) {
        final s = part.trim();
        for (final entry in ordered) {
          if (entry.$1 == s) {
            mask |= entry.$2;
            break;
          }
        }
      }
      return mask;
    }
    return monToFri;
  }
}

class WorkCalendar {
  final String id;
  final int workDays;          // bitmask
  final int dailyStartMinutes;
  final int dailyEndMinutes;
  final String timezone;

  const WorkCalendar({
    this.id = 'default',
    required this.workDays,
    required this.dailyStartMinutes,
    required this.dailyEndMinutes,
    required this.timezone,
  });

  factory WorkCalendar.fromJson(Map<String, dynamic> json) => WorkCalendar(
        id: (json['id'] as String?) ?? 'default',
        workDays: WorkDays.parse(json['workDays']),
        dailyStartMinutes: (json['dailyStartMinutes'] as num).toInt(),
        dailyEndMinutes: (json['dailyEndMinutes'] as num).toInt(),
        timezone: (json['timezone'] as String?) ?? 'UTC',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'workDays': workDays,
        'dailyStartMinutes': dailyStartMinutes,
        'dailyEndMinutes': dailyEndMinutes,
        'timezone': timezone,
      };

  WorkCalendar copyWith({
    int? workDays,
    int? dailyStartMinutes,
    int? dailyEndMinutes,
    String? timezone,
  }) =>
      WorkCalendar(
        id: id,
        workDays: workDays ?? this.workDays,
        dailyStartMinutes: dailyStartMinutes ?? this.dailyStartMinutes,
        dailyEndMinutes: dailyEndMinutes ?? this.dailyEndMinutes,
        timezone: timezone ?? this.timezone,
      );
}

class WorkCalendarResponse {
  final bool isFallback;
  final WorkCalendar calendar;
  const WorkCalendarResponse({required this.isFallback, required this.calendar});

  factory WorkCalendarResponse.fromJson(Map<String, dynamic> json) => WorkCalendarResponse(
        isFallback: (json['isFallback'] as bool?) ?? false,
        calendar: WorkCalendar.fromJson(json['calendar'] as Map<String, dynamic>),
      );
}
