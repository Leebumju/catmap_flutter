import 'badge.dart';

/// 로그인한 사용자. 서버 `users` 테이블 한 줄에 대응한다.
///
/// 이름을 `User` 로 두면 supabase_flutter 가 내보내는 `User`(인증 세션의 계정)와
/// 겹친다. 둘은 다른 것이다 — 세션의 User 는 auth 스키마, 이쪽은 앱의 프로필이다.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.createdAt,
    this.nickname,
    this.profileImageUrl,
    this.isBanned = false,
    this.role = 'user',
    this.representativeBadge,
  });

  final String id;
  final String email;
  final String? nickname;
  final String? profileImageUrl;
  final bool isBanned;
  final String role;
  final DateTime createdAt;
  final Badge? representativeBadge;

  bool get isAdmin => role == 'admin';

  /// `users` 테이블 한 줄에서 만든다.
  ///
  /// created_at 은 timestamptz 라 오프셋이 붙어 온다. UTC 로 고정해 두지 않으면
  /// 기기 시간대에 따라 값이 달라진다 — 피드 커서에서 이미 겪은 문제다.
  factory AppUser.fromRow(Map<String, dynamic> row) {
    return AppUser(
      id: row['id'] as String,
      email: (row['email'] as String?) ?? '',
      nickname: row['nickname'] as String?,
      profileImageUrl: row['profile_image_url'] as String?,
      isBanned: (row['is_banned'] as bool?) ?? false,
      role: (row['role'] as String?) ?? 'user',
      createdAt:
          DateTime.parse(row['created_at'] as String).toUtc(),
      representativeBadge:
          Badge.fromRawValue(row['representative_badge'] as String?),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.id == id &&
      other.email == email &&
      other.nickname == nickname &&
      other.profileImageUrl == profileImageUrl &&
      other.isBanned == isBanned &&
      other.role == role &&
      other.createdAt == createdAt &&
      other.representativeBadge == representativeBadge;

  @override
  int get hashCode => Object.hash(
        id,
        email,
        nickname,
        profileImageUrl,
        isBanned,
        role,
        createdAt,
        representativeBadge,
      );
}
