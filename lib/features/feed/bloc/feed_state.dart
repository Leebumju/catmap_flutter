import 'package:equatable/equatable.dart';

import '../../../domain/models/sighting.dart';
import 'reaction_tally.dart';

/// 화면이 한 번만 반응해야 하는 신호. 상태에 남겨두면 같은 소식이 두 번째로 왔을 때
/// 값이 안 바뀌어 안 뜨므로, 화면이 처리한 뒤 [FeedSignalConsumed] 로 지운다.
enum FeedSignal {
  loginRequired,
  accountBanned,
  loadFailed,
  reported,
  reportFailed,
  blocked,
  blockFailed,
  deleted,
  deleteFailed,
}

/// 피드 화면이 그리는 데 필요한 전부.
class FeedState extends Equatable {
  const FeedState({
    this.sightings = const [],
    this.currentIndex = 0,
    this.currentPhotoIndex = 0,
    this.reactions = const {},
    this.pendingReactions = const {},
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMorePages = true,
    this.currentUserId,
    this.signal,
  });

  static const int pageSize = 15;

  final List<Sighting> sightings;
  final int currentIndex;
  final int currentPhotoIndex;

  /// 반응 종류별 집계. 좋아요와 저도봤어요가 같은 자리에 들어간다.
  final Map<ReactionKind, ReactionTally> reactions;

  /// 서버 응답을 기다리는 중인 반응 종류. 연타로 두 번 나가는 걸 막는다.
  /// 종류별로 따로 막으므로 좋아요를 누르는 중에도 저도봤어요는 누를 수 있다.
  final Set<ReactionKind> pendingReactions;

  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMorePages;
  final String? currentUserId;
  final FeedSignal? signal;

  ReactionTally tally(ReactionKind kind) =>
      reactions[kind] ?? const ReactionTally();

  bool isMine(Sighting sighting) =>
      currentUserId != null && sighting.userId == currentUserId;

  /// 한 종류의 집계만 갈아끼운 새 상태.
  FeedState withTally(ReactionKind kind, ReactionTally tally) =>
      copyWith(reactions: {...reactions, kind: tally});

  /// 서버가 준 목격 기록들로 모든 반응 집계를 다시 세운다.
  FeedState seededWith(Iterable<Sighting> sightings) {
    final next = {...reactions};
    for (final kind in ReactionKind.values) {
      next[kind] = tally(kind).seeded(sightings, kind);
    }
    return copyWith(reactions: next);
  }

  FeedState copyWith({
    List<Sighting>? sightings,
    int? currentIndex,
    int? currentPhotoIndex,
    Map<ReactionKind, ReactionTally>? reactions,
    Set<ReactionKind>? pendingReactions,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMorePages,
    String? currentUserId,
    bool clearCurrentUserId = false,
    FeedSignal? signal,
    bool clearSignal = false,
  }) {
    return FeedState(
      sightings: sightings ?? this.sightings,
      currentIndex: currentIndex ?? this.currentIndex,
      currentPhotoIndex: currentPhotoIndex ?? this.currentPhotoIndex,
      reactions: reactions ?? this.reactions,
      pendingReactions: pendingReactions ?? this.pendingReactions,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMorePages: hasMorePages ?? this.hasMorePages,
      currentUserId:
          clearCurrentUserId ? null : (currentUserId ?? this.currentUserId),
      signal: clearSignal ? null : (signal ?? this.signal),
    );
  }

  @override
  List<Object?> get props => [
        sightings,
        currentIndex,
        currentPhotoIndex,
        reactions,
        pendingReactions,
        isLoading,
        isLoadingMore,
        hasMorePages,
        currentUserId,
        signal,
      ];
}
