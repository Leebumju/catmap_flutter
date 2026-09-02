import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/app_error.dart';
import '../domain/models/badge.dart';
import '../domain/models/earned_badge.dart';
import '../domain/models/notification_settings.dart';
import '../domain/repositories/profile_repository.dart';

/// 칭호. iOS 의 `BadgeClientLive` 와 같은 테이블·같은 RPC 를 쓴다.
class SupabaseBadgeRepository implements BadgeRepository {
  SupabaseBadgeRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Badge>> fetchMyBadges() async {
    try {
      final rows = await _client
          .from('user_badges')
          .select('badge_type')
          .order('earned_at', ascending: true);
      // 앱이 모르는 칭호(서버에 새로 생긴 것)는 버린다. 구버전이 안 깨지게 하는 장치다.
      return rows
          .map((r) => Badge.fromRawValue(r['badge_type'] as String?))
          .whereType<Badge>()
          .toList();
    } catch (error) {
      throw AppError.from(error);
    }
  }

  @override
  Future<void> setRepresentative(Badge badge) async {
    try {
      await _client.rpc<dynamic>(
        'set_representative_badge',
        params: {'p_badge_type': badge.rawValue},
      );
    } catch (error) {
      throw AppError.from(error);
    }
  }

  @override
  Future<void> unsetRepresentative() async {
    try {
      await _client.rpc<dynamic>('unset_representative_badge');
    } catch (error) {
      throw AppError.from(error);
    }
  }

  @override
  Future<List<EarnedBadge>> fetchMyEarnedBadges() async {
    try {
      final rows = await _client
          .from('user_badges')
          .select('badge_type, earned_at')
          .order('earned_at', ascending: true);

      final result = <EarnedBadge>[];
      for (final row in rows) {
        final badge = Badge.fromRawValue(row['badge_type'] as String?);
        // 앱이 모르는 칭호는 건너뛴다. 서버가 새 칭호를 추가해도 안 깨진다.
        if (badge == null) continue;
        result.add(EarnedBadge(
          badge: badge,
          earnedAt: DateTime.parse(row['earned_at'] as String).toUtc(),
        ));
      }
      return result;
    } catch (error) {
      throw AppError.from(error);
    }
  }

  @override
  Future<bool> checkHongGilDong() async {
    try {
      final result = await _client.rpc<dynamic>('check_hong_gil_dong');
      return result as bool? ?? false;
    } catch (error) {
      throw AppError.from(error);
    }
  }

  @override
  Future<DateTime?> lastSeenBadgeAt() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AppError.authRequired;

    try {
      final rows = await _client
          .from('users')
          .select('last_seen_badge_at')
          .eq('id', userId)
          .limit(1);
      if (rows.isEmpty) return null;
      final raw = rows.first['last_seen_badge_at'] as String?;
      return raw == null ? null : DateTime.parse(raw).toUtc();
    } catch (error) {
      throw AppError.from(error);
    }
  }

  @override
  Future<void> setLastSeenBadgeAt(DateTime timestamp) async {
    try {
      await _client.rpc<dynamic>(
        'set_last_seen_badge_at',
        params: {'p_ts': timestamp.toUtc().toIso8601String()},
      );
    } catch (error) {
      throw AppError.from(error);
    }
  }
}

/// 차단 목록. iOS 의 `BlockClientLive` 와 같은 질의다.
class SupabaseBlockRepository implements BlockRepository {
  SupabaseBlockRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<BlockedUser>> fetchBlockedUsers() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AppError.authRequired;

    try {
      // 차단한 사람의 닉네임을 같이 읽는다. 목록에 아이디만 뜨면 누구인지 알 수 없다.
      final rows = await _client
          .from('blocks')
          .select('id, blocked_id, created_at, blocked:users!blocked_id(nickname)')
          .eq('blocker_id', userId)
          .order('created_at', ascending: false);
      return rows.map(BlockedUser.fromRow).toList();
    } catch (error) {
      throw AppError.from(error);
    }
  }

  @override
  Future<void> unblockUser(String blockedUserId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AppError.authRequired;

    try {
      await _client
          .from('blocks')
          .delete()
          .eq('blocker_id', userId)
          .eq('blocked_id', blockedUserId);
    } catch (error) {
      throw AppError.from(error);
    }
  }
}

/// 알림 수신 설정. iOS 의 `NotificationClientLive` 와 같은 테이블을 쓴다.
class SupabaseNotificationSettingsRepository
    implements NotificationSettingsRepository {
  SupabaseNotificationSettingsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<NotificationSettings> fetch() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AppError.authRequired;

    try {
      final rows = await _client
          .from('notification_settings')
          .select()
          .eq('user_id', userId);
      // 저장된 적이 없으면 전부 켜진 상태가 기본값이다.
      if (rows.isEmpty) return const NotificationSettings();
      return NotificationSettings.fromRow(rows.first);
    } catch (error) {
      throw AppError.from(error);
    }
  }

  @override
  Future<void> update(NotificationSettings settings) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AppError.authRequired;

    try {
      await _client.from('notification_settings').upsert({
        'user_id': userId,
        'like_enabled': settings.likeEnabled,
        'confirmation_enabled': settings.confirmationEnabled,
        'comment_enabled': settings.commentEnabled,
      });
    } catch (error) {
      throw AppError.from(error);
    }
  }
}
