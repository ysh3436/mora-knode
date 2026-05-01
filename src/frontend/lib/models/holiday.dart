/// Holiday data fetched from a user-configured iCalendar subscription.
/// One entry per (date, source) — multiple sources can mark the same date
/// (e.g. Google's Korean Holidays + a company-specific calendar).
class Holiday {
  /// UTC midnight of the day the holiday falls on.
  final DateTime date;
  final String name;
  final String? sourceId;
  final String? sourceName;
  final String? colorHex;

  Holiday({
    required this.date,
    required this.name,
    this.sourceId,
    this.sourceName,
    this.colorHex,
  });

  factory Holiday.fromJson(Map<String, dynamic> json) => Holiday(
        date: DateTime.parse(json['date'] as String).toUtc(),
        name: json['name'] as String,
        sourceId: json['sourceId'] as String?,
        sourceName: json['sourceName'] as String?,
        colorHex: json['colorHex'] as String?,
      );
}

/// User-configured iCalendar subscription. Backend periodically fetches
/// `url`, parses the .ics, and stores events in a cache that
/// `/api/holidays?from=&to=` reads from.
class HolidaySource {
  final String? id;
  final String name;
  final String url;
  final String? colorHex;
  final bool enabled;
  final DateTime? lastFetchedAt;
  final String? lastError;

  const HolidaySource({
    this.id,
    required this.name,
    required this.url,
    this.colorHex,
    this.enabled = true,
    this.lastFetchedAt,
    this.lastError,
  });

  factory HolidaySource.fromJson(Map<String, dynamic> json) => HolidaySource(
        id: json['id'] as String?,
        name: (json['name'] as String?) ?? '',
        url: (json['url'] as String?) ?? '',
        colorHex: json['colorHex'] as String?,
        enabled: (json['enabled'] as bool?) ?? true,
        lastFetchedAt: json['lastFetchedAt'] == null
            ? null
            : DateTime.parse(json['lastFetchedAt'] as String).toUtc(),
        lastError: json['lastError'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        'url': url,
        'colorHex': colorHex,
        'enabled': enabled,
      };

  HolidaySource copyWith({
    String? name,
    String? url,
    String? colorHex,
    bool? enabled,
  }) =>
      HolidaySource(
        id: id,
        name: name ?? this.name,
        url: url ?? this.url,
        colorHex: colorHex ?? this.colorHex,
        enabled: enabled ?? this.enabled,
        lastFetchedAt: lastFetchedAt,
        lastError: lastError,
      );
}
