import 'package:equatable/equatable.dart';

import 'reaction_tally.dart';

/// TCA 의 `Action` 에 해당한다.
sealed class FeedEvent extends Equatable {
  const FeedEvent();

  @override
  List<Object?> get props => [];
}

/// 화면 진입 — 이미 데이터가 있으면 다시 불러오지 않는다.
final class FeedStarted extends FeedEvent {
  const FeedStarted();
}

/// 당겨서 새로고침 — 데이터가 있어도 처음부터 다시 받는다.
final class FeedRefreshed extends FeedEvent {
  const FeedRefreshed();
}

final class FeedLoadMoreRequested extends FeedEvent {
  const FeedLoadMoreRequested();
}

/// 세로 페이저에서 다른 목격 기록으로 넘어감
final class FeedIndexChanged extends FeedEvent {
  const FeedIndexChanged(this.index);

  final int index;

  @override
  List<Object?> get props => [index];
}

/// 가로 페이저에서 다른 사진으로 넘어감
final class FeedPhotoIndexChanged extends FeedEvent {
  const FeedPhotoIndexChanged(this.index);

  final int index;

  @override
  List<Object?> get props => [index];
}

/// 좋아요 또는 저도봤어요를 눌렀다. 종류는 [kind] 로 구분한다.
final class FeedReactionToggled extends FeedEvent {
  const FeedReactionToggled({required this.kind, required this.sightingId});

  final ReactionKind kind;
  final String sightingId;

  @override
  List<Object?> get props => [kind, sightingId];
}

final class FeedReported extends FeedEvent {
  const FeedReported({required this.sightingId, required this.reason});

  final String sightingId;
  final String reason;

  @override
  List<Object?> get props => [sightingId, reason];
}

final class FeedUserBlocked extends FeedEvent {
  const FeedUserBlocked(this.userId);

  final String userId;

  @override
  List<Object?> get props => [userId];
}

final class FeedSightingDeleted extends FeedEvent {
  const FeedSightingDeleted(this.sightingId);

  final String sightingId;

  @override
  List<Object?> get props => [sightingId];
}

/// 화면이 일회성 신호를 소비했음을 알린다.
final class FeedSignalConsumed extends FeedEvent {
  const FeedSignalConsumed();
}
