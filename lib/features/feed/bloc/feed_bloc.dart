import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/review_prompt_storage.dart';
import '../../../domain/models/app_error.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/sighting_repository.dart';
import 'feed_event.dart';
import 'feed_state.dart';
import 'reaction_tally.dart';

/// 목격 피드의 상태 기계.
///
/// 원본(Swift/TCA)의 리듀서를 옮긴 것이다. 액션 하나가 상태 하나를 만든다는 규칙은
/// 같고, 이펙트 취소를 TCA 는 `.cancellable(id:)` 로, bloc 은 event transformer 로
/// 한다는 점이 다르다.
class FeedBloc extends Bloc<FeedEvent, FeedState> {
  FeedBloc({
    required SightingRepository sightingRepository,
    required AuthRepository authRepository,
    ReviewPrompt reviewPrompt = const ReviewPrompt(),
  })  : _sightings = sightingRepository,
        _auth = authRepository,
        _review = reviewPrompt,
        super(const FeedState()) {
    on<FeedStarted>(_onStarted);
    on<FeedRefreshed>(_onRefreshed, transformer: restartable());
    // droppable — 이미 불러오는 중이면 새 요청을 버린다.
    // 스크롤 콜백이 초당 여러 번 튀기 때문에 없으면 같은 페이지를 중복으로 받는다.
    on<FeedLoadMoreRequested>(_onLoadMore, transformer: droppable());
    on<FeedIndexChanged>(_onIndexChanged);
    on<FeedPhotoIndexChanged>(_onPhotoIndexChanged);
    // 반응은 종류별로 막아야 해서 transformer 대신 상태로 거른다.
    // droppable 을 걸면 좋아요를 누르는 중에 저도봤어요까지 막힌다.
    on<FeedReactionToggled>(_onReactionToggled);
    on<FeedReported>(_onReported, transformer: droppable());
    on<FeedUserBlocked>(_onUserBlocked, transformer: droppable());
    on<FeedSightingDeleted>(_onDeleted, transformer: droppable());
    on<FeedSignalConsumed>(_onSignalConsumed);
  }

  final SightingRepository _sightings;
  final AuthRepository _auth;
  final ReviewPrompt _review;

  // MARK: 목록 불러오기

  Future<void> _onStarted(FeedStarted event, Emitter<FeedState> emit) async {
    // 이미 데이터가 있으면 (지도에서 넘어온 경우) 다시 안 받는다.
    if (state.sightings.isNotEmpty) return;
    await _loadFirstPage(emit);
  }

  Future<void> _onRefreshed(
    FeedRefreshed event,
    Emitter<FeedState> emit,
  ) async {
    await _loadFirstPage(emit);
  }

  Future<void> _loadFirstPage(Emitter<FeedState> emit) async {
    emit(state.copyWith(isLoading: true, currentUserId: _auth.currentUserId()));
    try {
      final loaded = await _sightings.fetchFeed(
        cursor: null,
        limit: FeedState.pageSize,
      );
      emit(state
          .copyWith(
            isLoading: false,
            sightings: loaded,
            currentIndex: 0,
            currentPhotoIndex: 0,
            hasMorePages: loaded.length >= FeedState.pageSize,
            // 새로고침이면 이전 토글 결과를 버리고 서버 값으로 다시 세운다.
            reactions: const {},
          )
          .seededWith(loaded));
    } catch (_) {
      // 조용히 실패하면 사용자는 왜 비었는지 알 수 없다. 목록은 그대로 두고 알린다.
      emit(state.copyWith(isLoading: false, signal: FeedSignal.loadFailed));
    }
  }

  Future<void> _onLoadMore(
    FeedLoadMoreRequested event,
    Emitter<FeedState> emit,
  ) async {
    if (state.isLoadingMore ||
        !state.hasMorePages ||
        state.sightings.isEmpty) {
      return;
    }
    emit(state.copyWith(isLoadingMore: true));
    final last = state.sightings.last;
    try {
      final loaded = await _sightings.fetchFeed(
        cursor: FeedCursor(createdAt: last.createdAt, id: last.id),
        limit: FeedState.pageSize,
      );
      // 커서가 경계에서 겹칠 수 있어 id 로 한 번 걸러낸다.
      final existingIds = state.sightings.map((s) => s.id).toSet();
      final fresh = loaded.where((s) => !existingIds.contains(s.id)).toList();
      emit(state
          .copyWith(
            isLoadingMore: false,
            hasMorePages: loaded.length >= FeedState.pageSize,
            sightings: [...state.sightings, ...fresh],
          )
          .seededWith(fresh));
    } catch (_) {
      // 실패해도 hasMorePages 는 건드리지 않는다. 여기서 false 로 내리면
      // 일시적인 네트워크 오류 한 번에 페이징이 영구히 막힌다.
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  // MARK: 페이저 위치

  void _onIndexChanged(FeedIndexChanged event, Emitter<FeedState> emit) {
    emit(state.copyWith(currentIndex: event.index, currentPhotoIndex: 0));
  }

  void _onPhotoIndexChanged(
    FeedPhotoIndexChanged event,
    Emitter<FeedState> emit,
  ) {
    emit(state.copyWith(currentPhotoIndex: event.index));
  }

  // MARK: 반응 (좋아요 / 저도 봤어요)

  Future<void> _onReactionToggled(
    FeedReactionToggled event,
    Emitter<FeedState> emit,
  ) async {
    final kind = event.kind;
    if (state.pendingReactions.contains(kind)) return;
    if (_auth.currentUserId() == null) {
      emit(state.copyWith(signal: FeedSignal.loginRequired));
      return;
    }
    emit(state.copyWith(pendingReactions: {...state.pendingReactions, kind}));
    try {
      // 낙관적 업데이트를 하지 않는다 — 서버가 돌려준 결과로만 상태를 바꾼다.
      // 반응이 반 박자 늦더라도 서버와 숫자가 어긋나지 않는 쪽을 택했고,
      // 원본 앱도 같은 방식이다.
      final toggle = switch (kind) {
        ReactionKind.like => _sightings.toggleLike,
        ReactionKind.confirmation => _sightings.toggleConfirmation,
      };
      final isActive = await toggle(event.sightingId);
      emit(state
          .copyWith(pendingReactions: _without(kind))
          .withTally(
            kind,
            state.tally(kind).toggled(event.sightingId, isActive: isActive),
          ));

      // 좋아요를 켰을 때만 센다. 껐다 켰다를 반복해서 리뷰 창이 뜨면 안 된다.
      // iOS 도 켠 경우에만 세고 물어본다.
      // 여기서 실패해도 좋아요는 이미 서버에 반영됐다. 실패로 처리하지 않는다.
      if (kind == ReactionKind.like && isActive) {
        try {
          await _review.trackLike();
          await _review.requestIfNeeded();
        } catch (_) {
          // 리뷰 요청은 없어도 되는 기능이다.
        }
      }
    } catch (error) {
      // 정지 계정만 알린다. 그 밖의 실패는 조용히 넘긴다 — 원본과 같다.
      emit(state.copyWith(
        pendingReactions: _without(kind),
        signal: _isBanned(error) ? FeedSignal.accountBanned : null,
      ));
    }
  }

  Set<ReactionKind> _without(ReactionKind kind) =>
      {...state.pendingReactions}..remove(kind);

  // MARK: 신고 / 차단 / 삭제

  Future<void> _onReported(FeedReported event, Emitter<FeedState> emit) async {
    if (_auth.currentUserId() == null) {
      emit(state.copyWith(signal: FeedSignal.loginRequired));
      return;
    }
    try {
      await _sightings.report(
        sightingId: event.sightingId,
        reason: event.reason,
      );
      emit(state.copyWith(signal: FeedSignal.reported));
    } catch (error) {
      emit(state.copyWith(
        signal:
            _isBanned(error) ? FeedSignal.accountBanned : FeedSignal.reportFailed,
      ));
    }
  }

  Future<void> _onUserBlocked(
    FeedUserBlocked event,
    Emitter<FeedState> emit,
  ) async {
    if (_auth.currentUserId() == null) {
      emit(state.copyWith(signal: FeedSignal.loginRequired));
      return;
    }
    try {
      await _sightings.blockUser(event.userId);
    } catch (error) {
      emit(state.copyWith(
        signal:
            _isBanned(error) ? FeedSignal.accountBanned : FeedSignal.blockFailed,
      ));
      return;
    }
    // 차단한 유저의 게시물은 즉시 걷어낸다. 다음 새로고침 때는 서버가 빼주지만,
    // 지금 화면에 남아 있으면 차단이 안 먹은 것처럼 보인다.
    emit(_removing(
      (s) => s.userId == event.userId,
      signal: FeedSignal.blocked,
    ));
  }

  Future<void> _onDeleted(
    FeedSightingDeleted event,
    Emitter<FeedState> emit,
  ) async {
    final target =
        state.sightings.firstWhereOrNull((s) => s.id == event.sightingId);
    try {
      await _sightings.delete(
        event.sightingId,
        photoUrls: target?.photoUrls ?? const [],
      );
    } catch (_) {
      emit(state.copyWith(signal: FeedSignal.deleteFailed));
      return;
    }
    emit(_removing(
      (s) => s.id == event.sightingId,
      signal: FeedSignal.deleted,
    ));
  }

  /// 조건에 맞는 글을 목록에서 빼고, 보고 있던 위치가 범위를 벗어나면 당겨준다.
  FeedState _removing(
    bool Function(dynamic) matches, {
    required FeedSignal signal,
  }) {
    final remaining = state.sightings.where((s) => !matches(s)).toList();
    final index = remaining.isEmpty
        ? 0
        : state.currentIndex.clamp(0, remaining.length - 1);
    return state.copyWith(
      sightings: remaining,
      currentIndex: index,
      currentPhotoIndex: 0,
      signal: signal,
    );
  }

  void _onSignalConsumed(FeedSignalConsumed event, Emitter<FeedState> emit) {
    emit(state.copyWith(clearSignal: true));
  }

  bool _isBanned(Object error) {
    final mapped = error is AppError ? error : AppError.from(error);
    return mapped == AppError.accountBanned;
  }
}
