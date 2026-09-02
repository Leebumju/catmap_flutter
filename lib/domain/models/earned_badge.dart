import 'package:equatable/equatable.dart';

import 'badge.dart';

/// 획득한 칭호와 그 시각.
///
/// 시각은 서버 `user_badges.earned_at` 이다. "새로 딴 칭호"를 가려낼 때
/// 기기 시계가 아니라 이 값으로만 비교한다 — 기기 시계는 틀릴 수 있다.
class EarnedBadge extends Equatable {
  const EarnedBadge({required this.badge, required this.earnedAt});

  final Badge badge;
  final DateTime earnedAt;

  @override
  List<Object?> get props => [badge, earnedAt];
}
