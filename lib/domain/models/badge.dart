/// 칭호 — rawValue 는 서버 `user_badges.badge_type` 과 매핑.
/// Swift 의 `enum Badge: String` 과 같은 역할. Dart enum 은 raw value 가 없어서
/// 필드로 들고 다니고, 모르는 값은 null 로 떨어뜨린다(서버가 새 칭호를 추가해도 앱이 안 깨짐).
enum Badge {
  beginnerExplorer('beginner_explorer', '초보탐험가'),
  intermediateExplorer('intermediate_explorer', '중급탐험가'),
  advancedExplorer('advanced_explorer', '고급탐험가'),
  veteranExplorer('veteran_explorer', '베테랑탐험가'),
  popularStar('popular_star', '인기스타'),
  hongGilDong('hong_gil_dong', '홍길동');

  const Badge(this.rawValue, this.displayName);

  final String rawValue;
  final String displayName;

  static Badge? fromRawValue(String? raw) {
    if (raw == null) return null;
    for (final b in Badge.values) {
      if (b.rawValue == raw) return b;
    }
    return null;
  }
}
