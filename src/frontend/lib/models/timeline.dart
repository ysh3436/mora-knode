class Timeline {
  final DateTime? start;
  final DateTime? end;
  final bool isAllDay;

  const Timeline({this.start, this.end, this.isAllDay = true});

  bool get isEmpty => start == null && end == null;

  factory Timeline.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const Timeline();
    return Timeline(
      start: _parse(json['start']),
      end: _parse(json['end']),
      isAllDay: (json['isAllDay'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'start': start?.toUtc().toIso8601String(),
        'end': end?.toUtc().toIso8601String(),
        'isAllDay': isAllDay,
      };

  Timeline copyWith({
    DateTime? start,
    DateTime? end,
    bool? isAllDay,
    bool clearStart = false,
    bool clearEnd = false,
  }) {
    return Timeline(
      start: clearStart ? null : (start ?? this.start),
      end: clearEnd ? null : (end ?? this.end),
      isAllDay: isAllDay ?? this.isAllDay,
    );
  }

  static DateTime? _parse(Object? v) => v == null ? null : DateTime.parse(v as String).toUtc();
}
