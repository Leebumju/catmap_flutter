import '../models/badge.dart';
import '../models/notification_settings.dart';

/// 칭호. iOS 의 `BadgeClient` 중 프로필 편집에 필요한 것만 뚫는다.
///
/// 칭호를 새로 발급하는 쪽(홍길동 판정 등)은 지도 화면의 몫이라 여기 없다.
abstract class BadgeRepository {
  /// 내가 가진 칭호 목록.
  Future<List<Badge>> fetchMyBadges();

  /// 대표 칭호 지정. 프로필에 이 칭호가 붙는다.
  Future<void> setRepresentative(Badge badge);

  /// 대표 칭호 해제.
  Future<void> unsetRepresentative();
}

/// 차단 목록. iOS 의 `BlockClient` 에 대응한다.
abstract class BlockRepository {
  Future<List<BlockedUser>> fetchBlockedUsers();

  Future<void> unblockUser(String blockedUserId);
}

/// 알림 수신 설정. iOS 의 `NotificationClient` 중 설정 부분만 옮긴 것이다.
///
/// 기기 토큰 등록·푸시 수신은 아직 옮기지 않았다 — 설정 화면의 스위치는
/// 서버에 저장되지만, 실제 푸시는 iOS 앱에서만 온다.
abstract class NotificationSettingsRepository {
  Future<NotificationSettings> fetch();

  Future<void> update(NotificationSettings settings);
}
