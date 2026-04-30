class Timeline {
  final DateTime? start;
  final DateTime? end;

  const Timeline({this.start, this.end});

  bool get isEmpty => start == null && end == null;

  factory Timeline.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const Timeline();
    return Timeline(
      start: _parse(json['start']),
      end: _parse(json['end']),
    );
  }

  Map<String, dynamic> toJson() => {
        'start': start?.toUtc().toIso8601String(),
        'end': end?.toUtc().toIso8601String(),
      };

  Timeline copyWith({DateTime? start, DateTime? end, bool clearStart = false, bool clearEnd = false}) {
    return Timeline(
      start: clearStart ? null : (start ?? this.start),
      end: clearEnd ? null : (end ?? this.end),
    );
  }

  static DateTime? _parse(Object? v) => v == null ? null : DateTime.parse(v as String).toUtc();
}
