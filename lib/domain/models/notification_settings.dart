import 'package:equatable/equatable.dart';

/// 어떤 알림을 받을지. 서버 `notification_settings` 한 줄에 대응한다.
///
/// 행이 아직 없는 사용자는 전부 켜진 것으로 본다 — iOS 와 같은 기본값이다.
class NotificationSettings extends Equatable {
  const NotificationSettings({
    this.likeEnabled = true,
    this.confirmationEnabled = true,
    this.commentEnabled = true,
  });

  final bool likeEnabled;
  final bool confirmationEnabled;
  final bool commentEnabled;

  factory NotificationSettings.fromRow(Map<String, dynamic> row) {
    return NotificationSettings(
      likeEnabled: row['like_enabled'] as bool? ?? true,
      confirmationEnabled: row['confirmation_enabled'] as bool? ?? true,
      // comment_enabled 는 나중에 추가된 컬럼이라 없을 수 있다.
      commentEnabled: row['comment_enabled'] as bool? ?? true,
    );
  }

  NotificationSettings copyWith({
    bool? likeEnabled,
    bool? confirmationEnabled,
    bool? commentEnabled,
  }) {
    return NotificationSettings(
      likeEnabled: likeEnabled ?? this.likeEnabled,
      confirmationEnabled: confirmationEnabled ?? this.confirmationEnabled,
      commentEnabled: commentEnabled ?? this.commentEnabled,
    );
  }

  @override
  List<Object?> get props => [likeEnabled, confirmationEnabled, commentEnabled];
}

/// 차단한 사용자 한 명. 차단 목록 화면에서 쓴다.
class BlockedUser extends Equatable {
  const BlockedUser({
    required this.blockId,
    required this.blockedUserId,
    required this.createdAt,
    this.nickname,
  });

  final String blockId;
  final String blockedUserId;
  final String? nickname;
  final DateTime createdAt;

  /// `blocks` 에 `users` 를 붙여 읽은 한 줄.
  factory BlockedUser.fromRow(Map<String, dynamic> row) {
    final blocked = row['blocked'] as Map<String, dynamic>?;
    return BlockedUser(
      blockId: row['id'] as String,
      blockedUserId: row['blocked_id'] as String,
      nickname: blocked?['nickname'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
    );
  }

  @override
  List<Object?> get props => [blockId, blockedUserId, nickname, createdAt];
}
