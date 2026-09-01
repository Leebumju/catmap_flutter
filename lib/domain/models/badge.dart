import 'package:flutter/painting.dart' show Color;

/// 칭호 등급. iOS 의 `BadgeGrade` 와 같다.
enum BadgeGrade {
  common('일반', Color(0xFF888888)),
  rare('희귀', Color(0xFF7B1FA2)),
  heroic('영웅', Color(0xFFE65100)),
  legendary('전설', Color(0xFFF9A825)),
  special('특별', Color(0xFFF57F17));

  const BadgeGrade(this.displayName, this.headerColor);

  final String displayName;

  /// 편집 화면에서 등급 묶음 제목에 쓰는 색.
  final Color headerColor;
}

/// 칭호 — rawValue 는 서버 `user_badges.badge_type` 과 매핑.
///
/// Swift 의 `enum Badge: String` 과 같은 역할. Dart enum 은 raw value 가 없어서
/// 필드로 들고 다니고, 모르는 값은 null 로 떨어뜨린다(서버가 새 칭호를 추가해도 앱이 안 깨짐).
///
/// **여덟 개가 모두 있어야 한다.** 하나라도 빠지면 그 칭호를 단 사용자의 프로필에서
/// 칭호가 통째로 사라진다.
enum Badge {
  beginnerExplorer(
    'beginner_explorer',
    '초보탐험가',
    BadgeGrade.common,
    '목격 1건',
    Color(0xFFE8F5E9),
    Color(0xFF2E7D32),
  ),
  intermediateExplorer(
    'intermediate_explorer',
    '중급탐험가',
    BadgeGrade.common,
    '목격 10건',
    Color(0xFFE3F2FD),
    Color(0xFF1565C0),
  ),
  advancedExplorer(
    'advanced_explorer',
    '고급탐험가',
    BadgeGrade.rare,
    '목격 30건',
    Color(0xFFF3E5F5),
    Color(0xFF7B1FA2),
  ),
  veteranExplorer(
    'veteran_explorer',
    '베테랑탐험가',
    BadgeGrade.heroic,
    '목격 100건',
    Color(0xFFFFF3E0),
    Color(0xFFE65100),
  ),
  popularStar(
    'popular_star',
    '인기스타',
    BadgeGrade.rare,
    '게시물 좋아요 10개',
    Color(0xFFFCE4EC),
    Color(0xFFC62828),
  ),
  hongGilDong(
    'hong_gil_dong',
    '홍길동',
    BadgeGrade.heroic,
    '전국 10개 시도 모두 목격',
    Color(0xFFECEFF1),
    Color(0xFF37474F),
  ),
  earlyMember(
    'early_member',
    '초기멤버',
    BadgeGrade.special,
    '가입 순서 100번 이내',
    Color(0xFFFFF8E1),
    Color(0xFFF57F17),
  ),
  sightingKing(
    'sighting_king',
    '목격왕 👑',
    BadgeGrade.legendary,
    '전월 게시물 최다 등록',
    Color(0xFFFFF9C4),
    Color(0xFFF9A825),
  );

  const Badge(
    this.rawValue,
    this.displayName,
    this.grade,
    this.conditionDescription,
    this.backgroundColor,
    this.textColor,
  );

  final String rawValue;
  final String displayName;
  final BadgeGrade grade;

  /// 달성 조건 설명.
  final String conditionDescription;

  final Color backgroundColor;
  final Color textColor;

  /// 아직 못 딴 칭호에 보여줄 조건.
  /// 홍길동은 숨은 칭호라 조건을 가린다 — iOS 와 같다.
  String get lockedConditionDisplay =>
      this == Badge.hongGilDong ? '???' : conditionDescription;

  static Badge? fromRawValue(String? raw) {
    if (raw == null) return null;
    for (final b in Badge.values) {
      if (b.rawValue == raw) return b;
    }
    return null;
  }
}
