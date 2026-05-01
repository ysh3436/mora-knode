/// 대한민국 공휴일 데이터.
///
/// 출처: 공공데이터포털 [특일정보 API](https://www.data.go.kr/data/15012690/openapi.do)
/// 음력 기반 공휴일(설날·추석·부처님오신날)은 한국천문연구원(KASI) 발표 양력 환산일을
/// 그대로 사용한다.
///
/// **주의**: 매년 새해 시작 전에 갱신해야 한다. 정부의 임시공휴일 지정 (예: 선거일,
/// 광화문 행사일 등) 도 발표되면 추가 필요. 장기적으론 backend가 data.go.kr 또는
/// KASI API를 호출해서 캐시하고 frontend가 그걸 받는 형태가 깔끔하다 (현재는
/// 1인 dogfooding 단계라 정적 데이터로 충분).
library;

import 'package:flutter/foundation.dart';

@immutable
class KoreanHoliday {
  /// UTC 자정. 모든 비교는 y/m/d 기준이라 시간대 영향 없음.
  final DateTime date;
  final String name;
  /// 대체공휴일 여부 — 같은 이름의 본 공휴일과 구분.
  final bool isSubstitute;

  const KoreanHoliday(this.date, this.name, {this.isSubstitute = false});
}

final List<KoreanHoliday> _holidays = [
  // ===== 2025 =====
  KoreanHoliday(DateTime.utc(2025, 1, 1), '신정'),
  KoreanHoliday(DateTime.utc(2025, 1, 28), '설날 연휴'),
  KoreanHoliday(DateTime.utc(2025, 1, 29), '설날'),
  KoreanHoliday(DateTime.utc(2025, 1, 30), '설날 연휴'),
  KoreanHoliday(DateTime.utc(2025, 3, 1), '삼일절'),
  KoreanHoliday(DateTime.utc(2025, 3, 3), '대체공휴일 (삼일절)', isSubstitute: true),
  KoreanHoliday(DateTime.utc(2025, 5, 5), '어린이날 / 부처님오신날'),
  KoreanHoliday(DateTime.utc(2025, 5, 6), '대체공휴일 (어린이날)', isSubstitute: true),
  KoreanHoliday(DateTime.utc(2025, 6, 6), '현충일'),
  KoreanHoliday(DateTime.utc(2025, 8, 15), '광복절'),
  KoreanHoliday(DateTime.utc(2025, 10, 3), '개천절'),
  KoreanHoliday(DateTime.utc(2025, 10, 5), '추석 연휴'),
  KoreanHoliday(DateTime.utc(2025, 10, 6), '추석'),
  KoreanHoliday(DateTime.utc(2025, 10, 7), '추석 연휴'),
  KoreanHoliday(DateTime.utc(2025, 10, 8), '대체공휴일 (추석)', isSubstitute: true),
  KoreanHoliday(DateTime.utc(2025, 10, 9), '한글날'),
  KoreanHoliday(DateTime.utc(2025, 12, 25), '성탄절'),

  // ===== 2026 =====
  KoreanHoliday(DateTime.utc(2026, 1, 1), '신정'),
  KoreanHoliday(DateTime.utc(2026, 2, 16), '설날 연휴'),
  KoreanHoliday(DateTime.utc(2026, 2, 17), '설날'),
  KoreanHoliday(DateTime.utc(2026, 2, 18), '설날 연휴'),
  KoreanHoliday(DateTime.utc(2026, 3, 1), '삼일절'),
  KoreanHoliday(DateTime.utc(2026, 3, 2), '대체공휴일 (삼일절)', isSubstitute: true),
  KoreanHoliday(DateTime.utc(2026, 5, 5), '어린이날'),
  KoreanHoliday(DateTime.utc(2026, 5, 24), '부처님오신날'),
  KoreanHoliday(DateTime.utc(2026, 5, 25), '대체공휴일 (부처님오신날)', isSubstitute: true),
  KoreanHoliday(DateTime.utc(2026, 6, 6), '현충일'),
  KoreanHoliday(DateTime.utc(2026, 6, 8), '대체공휴일 (현충일)', isSubstitute: true),
  KoreanHoliday(DateTime.utc(2026, 8, 15), '광복절'),
  KoreanHoliday(DateTime.utc(2026, 8, 17), '대체공휴일 (광복절)', isSubstitute: true),
  KoreanHoliday(DateTime.utc(2026, 9, 24), '추석 연휴'),
  KoreanHoliday(DateTime.utc(2026, 9, 25), '추석'),
  KoreanHoliday(DateTime.utc(2026, 9, 26), '추석 연휴'),
  KoreanHoliday(DateTime.utc(2026, 10, 3), '개천절'),
  KoreanHoliday(DateTime.utc(2026, 10, 5), '대체공휴일 (개천절)', isSubstitute: true),
  KoreanHoliday(DateTime.utc(2026, 10, 9), '한글날'),
  KoreanHoliday(DateTime.utc(2026, 12, 25), '성탄절'),

  // ===== 2027 (음력 기반은 잠정 — 매년 KASI 발표 후 정확 갱신) =====
  KoreanHoliday(DateTime.utc(2027, 1, 1), '신정'),
  KoreanHoliday(DateTime.utc(2027, 2, 6), '설날 연휴'),
  KoreanHoliday(DateTime.utc(2027, 2, 7), '설날'),
  KoreanHoliday(DateTime.utc(2027, 2, 8), '설날 연휴'),
  KoreanHoliday(DateTime.utc(2027, 2, 9), '대체공휴일 (설날)', isSubstitute: true),
  KoreanHoliday(DateTime.utc(2027, 3, 1), '삼일절'),
  KoreanHoliday(DateTime.utc(2027, 5, 5), '어린이날'),
  KoreanHoliday(DateTime.utc(2027, 5, 13), '부처님오신날'),
  KoreanHoliday(DateTime.utc(2027, 6, 6), '현충일'),
  KoreanHoliday(DateTime.utc(2027, 6, 7), '대체공휴일 (현충일)', isSubstitute: true),
  KoreanHoliday(DateTime.utc(2027, 8, 15), '광복절'),
  KoreanHoliday(DateTime.utc(2027, 8, 16), '대체공휴일 (광복절)', isSubstitute: true),
  KoreanHoliday(DateTime.utc(2027, 9, 14), '추석 연휴'),
  KoreanHoliday(DateTime.utc(2027, 9, 15), '추석'),
  KoreanHoliday(DateTime.utc(2027, 9, 16), '추석 연휴'),
  KoreanHoliday(DateTime.utc(2027, 10, 3), '개천절'),
  KoreanHoliday(DateTime.utc(2027, 10, 4), '대체공휴일 (개천절)', isSubstitute: true),
  KoreanHoliday(DateTime.utc(2027, 10, 9), '한글날'),
  KoreanHoliday(DateTime.utc(2027, 10, 11), '대체공휴일 (한글날)', isSubstitute: true),
  KoreanHoliday(DateTime.utc(2027, 12, 25), '성탄절'),
];

/// O(1) date → holiday lookup. Keyed on UTC y/m/d so callers don't have to
/// worry about local-vs-UTC offsets.
final Map<int, KoreanHoliday> _byKey = {
  for (final h in _holidays) _key(h.date.year, h.date.month, h.date.day): h,
};

int _key(int y, int m, int d) => (y * 10000) + (m * 100) + d;

class KoreanHolidays {
  KoreanHolidays._();

  /// Returns the holiday for the given date, or null if it's not a public
  /// holiday. Compares y/m/d only (timezone-agnostic).
  static KoreanHoliday? forDate(DateTime date) {
    return _byKey[_key(date.year, date.month, date.day)];
  }
}
