import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/app_error.dart';
import '../../../domain/models/comment.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/comment_repository.dart';
import '../../../domain/repositories/sighting_repository.dart';

sealed class CommentsEvent extends Equatable {
  const CommentsEvent();

  @override
  List<Object?> get props => [];
}

final class CommentsStarted extends CommentsEvent {
  const CommentsStarted();
}

final class CommentsLoadMoreRequested extends CommentsEvent {
  const CommentsLoadMoreRequested();
}

/// 답글을 펼치거나 접는다. 펼칠 때 아직 안 받았으면 받아온다.
final class CommentsRepliesToggled extends CommentsEvent {
  const CommentsRepliesToggled(this.parentId);

  final String parentId;

  @override
  List<Object?> get props => [parentId];
}

final class CommentsReplyTargetChanged extends CommentsEvent {
  const CommentsReplyTargetChanged(this.target);

  /// null 이면 최상위 댓글을 쓰는 중이다.
  final Comment? target;

  @override
  List<Object?> get props => [target];
}

final class CommentsInputChanged extends CommentsEvent {
  const CommentsInputChanged(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

final class CommentsSubmitted extends CommentsEvent {
  const CommentsSubmitted();
}

final class CommentsDeleted extends CommentsEvent {
  const CommentsDeleted(this.commentId);

  final String commentId;

  @override
  List<Object?> get props => [commentId];
}

final class CommentsReported extends CommentsEvent {
  const CommentsReported({required this.commentId, required this.reason});

  final String commentId;
  final String reason;

  @override
  List<Object?> get props => [commentId, reason];
}

final class CommentsUserBlocked extends CommentsEvent {
  const CommentsUserBlocked(this.userId);

  final String userId;

  @override
  List<Object?> get props => [userId];
}

final class CommentsSignalConsumed extends CommentsEvent {
  const CommentsSignalConsumed();
}

/// 화면이 한 번만 반응해야 하는 신호.
enum CommentsSignal {
  loginRequired,
  accountBanned,
  submitFailed,
  deleted,
  deleteFailed,
  reported,
  reportFailed,
  blocked,
  blockFailed,
  loadFailed,
}

class CommentsState extends Equatable {
  const CommentsState({
    required this.sightingId,
    this.comments = const [],
    this.replies = const {},
    this.expandedReplies = const {},
    this.loadingReplies = const {},
    this.replyingTo,
    this.inputText = '',
    this.currentUserId,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMorePages = true,
    this.isSubmitting = false,
    this.isReporting = false,
    this.isBlocking = false,
    this.signal,
  });

  static const pageSize = 20;

  /// 댓글 길이 상한. iOS 와 같은 500자다.
  static const maxLength = 500;

  final String sightingId;
  final List<Comment> comments;

  /// 최상위 댓글 id → 받아둔 답글(오래된 순).
  final Map<String, List<Comment>> replies;

  final Set<String> expandedReplies;
  final Set<String> loadingReplies;

  /// 답글을 다는 대상. null 이면 최상위 댓글을 쓰는 중이다.
  final Comment? replyingTo;

  final String inputText;
  final String? currentUserId;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMorePages;
  final bool isSubmitting;
  final bool isReporting;
  final bool isBlocking;
  final CommentsSignal? signal;

  /// 보낼 수 있는 상태인지. 공백만 있으면 안 되고, 500자를 넘어도 안 된다.
  bool get canSubmit {
    final trimmed = inputText.trim();
    return trimmed.isNotEmpty && trimmed.length <= maxLength && !isSubmitting;
  }

  int get loadedCount => comments.length;

  CommentsState copyWith({
    List<Comment>? comments,
    Map<String, List<Comment>>? replies,
    Set<String>? expandedReplies,
    Set<String>? loadingReplies,
    Comment? replyingTo,
    String? inputText,
    String? currentUserId,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMorePages,
    bool? isSubmitting,
    bool? isReporting,
    bool? isBlocking,
    CommentsSignal? signal,
    bool clearReplyingTo = false,
    bool clearSignal = false,
  }) {
    return CommentsState(
      sightingId: sightingId,
      comments: comments ?? this.comments,
      replies: replies ?? this.replies,
      expandedReplies: expandedReplies ?? this.expandedReplies,
      loadingReplies: loadingReplies ?? this.loadingReplies,
      replyingTo: clearReplyingTo ? null : (replyingTo ?? this.replyingTo),
      inputText: inputText ?? this.inputText,
      currentUserId: currentUserId ?? this.currentUserId,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMorePages: hasMorePages ?? this.hasMorePages,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isReporting: isReporting ?? this.isReporting,
      isBlocking: isBlocking ?? this.isBlocking,
      signal: clearSignal ? null : (signal ?? this.signal),
    );
  }

  @override
  List<Object?> get props => [
        sightingId,
        comments,
        replies,
        expandedReplies,
        loadingReplies,
        replyingTo,
        inputText,
        currentUserId,
        isLoading,
        isLoadingMore,
        hasMorePages,
        isSubmitting,
        isReporting,
        isBlocking,
        signal,
      ];
}

/// 댓글 화면. iOS 의 `CommentsFeature` 를 옮긴 것이다.
class CommentsBloc extends Bloc<CommentsEvent, CommentsState> {
  CommentsBloc({
    required CommentRepository commentRepository,
    required AuthRepository authRepository,
    required SightingRepository sightingRepository,
    required String sightingId,
  })  : _comments = commentRepository,
        _auth = authRepository,
        _sightings = sightingRepository,
        super(CommentsState(sightingId: sightingId)) {
    on<CommentsStarted>(_onStarted, transformer: droppable());
    on<CommentsLoadMoreRequested>(_onLoadMore, transformer: droppable());
    on<CommentsRepliesToggled>(_onRepliesToggled);
    on<CommentsReplyTargetChanged>((e, emit) => emit(state.copyWith(
          replyingTo: e.target,
          clearReplyingTo: e.target == null,
        )));
    on<CommentsInputChanged>(_onInputChanged);
    // 전송 버튼 연타로 같은 댓글이 두 번 올라가지 않게 막는다.
    on<CommentsSubmitted>(_onSubmitted, transformer: droppable());
    on<CommentsDeleted>(_onDeleted, transformer: droppable());
    on<CommentsReported>(_onReported, transformer: droppable());
    on<CommentsUserBlocked>(_onBlocked, transformer: droppable());
    on<CommentsSignalConsumed>((e, emit) => emit(state.copyWith(clearSignal: true)));
  }

  final CommentRepository _comments;
  final AuthRepository _auth;
  final SightingRepository _sightings;

  Future<void> _onStarted(
    CommentsStarted event,
    Emitter<CommentsState> emit,
  ) async {
    emit(state.copyWith(
      isLoading: true,
      clearSignal: true,
      currentUserId: _auth.currentUserId(),
    ));
    try {
      final comments = await _comments.fetch(
        sightingId: state.sightingId,
        limit: CommentsState.pageSize,
      );
      emit(state.copyWith(
        comments: comments,
        isLoading: false,
        hasMorePages: comments.length >= CommentsState.pageSize,
      ));
    } catch (_) {
      emit(state.copyWith(isLoading: false, signal: CommentsSignal.loadFailed));
    }
  }

  Future<void> _onLoadMore(
    CommentsLoadMoreRequested event,
    Emitter<CommentsState> emit,
  ) async {
    if (state.isLoadingMore || !state.hasMorePages || state.comments.isEmpty) {
      return;
    }
    emit(state.copyWith(isLoadingMore: true));

    final last = state.comments.last;
    try {
      final more = await _comments.fetch(
        sightingId: state.sightingId,
        cursor: CommentCursor(createdAt: last.createdAt, id: last.id),
        limit: CommentsState.pageSize,
      );
      // 커서 경계에서 겹쳐 온 것은 id 로 걸러낸다. 피드와 같은 이유다.
      final existing = state.comments.map((c) => c.id).toSet();
      final unique = more.where((c) => !existing.contains(c.id)).toList();
      emit(state.copyWith(
        comments: [...state.comments, ...unique],
        isLoadingMore: false,
        hasMorePages: more.length >= CommentsState.pageSize,
      ));
    } catch (_) {
      // 실패해도 hasMorePages 를 내리지 않는다. 한 번 실패로 페이징이 영영
      // 막히면 안 된다 — 피드에서 이미 고친 것과 같은 함정이다.
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onRepliesToggled(
    CommentsRepliesToggled event,
    Emitter<CommentsState> emit,
  ) async {
    final parentId = event.parentId;

    if (state.expandedReplies.contains(parentId)) {
      emit(state.copyWith(
        expandedReplies: {...state.expandedReplies}..remove(parentId),
      ));
      return;
    }

    emit(state.copyWith(
      expandedReplies: {...state.expandedReplies, parentId},
    ));

    // 이미 받아둔 답글이면 다시 받지 않는다.
    if (state.replies.containsKey(parentId)) return;

    emit(state.copyWith(loadingReplies: {...state.loadingReplies, parentId}));
    try {
      final replies = await _comments.fetchReplies(parentId);
      emit(state.copyWith(
        replies: {...state.replies, parentId: replies},
        loadingReplies: {...state.loadingReplies}..remove(parentId),
      ));
    } catch (_) {
      // 못 받으면 다시 접는다. 빈 채로 펼쳐두면 답글이 없는 것처럼 보인다.
      emit(state.copyWith(
        expandedReplies: {...state.expandedReplies}..remove(parentId),
        loadingReplies: {...state.loadingReplies}..remove(parentId),
      ));
    }
  }

  void _onInputChanged(
    CommentsInputChanged event,
    Emitter<CommentsState> emit,
  ) {
    final text = event.text.length > CommentsState.maxLength
        ? event.text.substring(0, CommentsState.maxLength)
        : event.text;
    emit(state.copyWith(inputText: text));
  }

  Future<void> _onSubmitted(
    CommentsSubmitted event,
    Emitter<CommentsState> emit,
  ) async {
    if (!state.canSubmit) return;
    if (_auth.currentUserId() == null) {
      emit(state.copyWith(signal: CommentsSignal.loginRequired));
      return;
    }

    final parent = state.replyingTo;
    final content = state.inputText.trim();
    emit(state.copyWith(isSubmitting: true, clearSignal: true));

    try {
      final created = await _comments.add(
        sightingId: state.sightingId,
        content: content,
        parentId: parent?.id,
      );

      if (parent == null) {
        // 최상위 댓글은 최신순이라 맨 앞에 붙인다.
        emit(state.copyWith(
          comments: [created, ...state.comments],
          inputText: '',
          isSubmitting: false,
        ));
      } else {
        // 답글은 오래된 순이라 뒤에 붙이고, 부모의 답글 수를 하나 올린다.
        final current = state.replies[parent.id] ?? const <Comment>[];
        emit(state.copyWith(
          replies: {...state.replies, parent.id: [...current, created]},
          expandedReplies: {...state.expandedReplies, parent.id},
          comments: _withReplyCountChanged(parent.id, 1),
          inputText: '',
          isSubmitting: false,
          clearReplyingTo: true,
        ));
      }
    } catch (error) {
      emit(state.copyWith(
        isSubmitting: false,
        signal: _isBanned(error)
            ? CommentsSignal.accountBanned
            : CommentsSignal.submitFailed,
      ));
    }
  }

  Future<void> _onDeleted(
    CommentsDeleted event,
    Emitter<CommentsState> emit,
  ) async {
    try {
      await _comments.delete(event.commentId);

      // 최상위 댓글이면 목록에서 빼고, 답글이면 부모의 답글 목록에서 뺀다.
      final isTopLevel = state.comments.any((c) => c.id == event.commentId);
      if (isTopLevel) {
        emit(state.copyWith(
          comments:
              state.comments.where((c) => c.id != event.commentId).toList(),
          replies: {...state.replies}..remove(event.commentId),
          signal: CommentsSignal.deleted,
        ));
        return;
      }

      String? parentId;
      final nextReplies = <String, List<Comment>>{};
      for (final entry in state.replies.entries) {
        if (entry.value.any((c) => c.id == event.commentId)) {
          parentId = entry.key;
          nextReplies[entry.key] =
              entry.value.where((c) => c.id != event.commentId).toList();
        } else {
          nextReplies[entry.key] = entry.value;
        }
      }
      emit(state.copyWith(
        replies: nextReplies,
        comments: parentId == null
            ? state.comments
            : _withReplyCountChanged(parentId, -1),
        signal: CommentsSignal.deleted,
      ));
    } catch (_) {
      emit(state.copyWith(signal: CommentsSignal.deleteFailed));
    }
  }

  Future<void> _onReported(
    CommentsReported event,
    Emitter<CommentsState> emit,
  ) async {
    if (state.isReporting) return;
    if (_auth.currentUserId() == null) {
      emit(state.copyWith(signal: CommentsSignal.loginRequired));
      return;
    }
    emit(state.copyWith(isReporting: true, clearSignal: true));
    try {
      await _comments.report(
        commentId: event.commentId,
        reason: event.reason,
      );
      emit(state.copyWith(isReporting: false, signal: CommentsSignal.reported));
    } catch (error) {
      emit(state.copyWith(
        isReporting: false,
        signal: _isBanned(error)
            ? CommentsSignal.accountBanned
            : CommentsSignal.reportFailed,
      ));
    }
  }

  Future<void> _onBlocked(
    CommentsUserBlocked event,
    Emitter<CommentsState> emit,
  ) async {
    if (state.isBlocking) return;
    if (_auth.currentUserId() == null) {
      emit(state.copyWith(signal: CommentsSignal.loginRequired));
      return;
    }
    emit(state.copyWith(isBlocking: true, clearSignal: true));
    try {
      await _sightings.blockUser(event.userId);

      // 차단한 사람의 댓글·답글을 화면에서 바로 걷어낸다. 다시 받지 않아도
      // 눈앞에서 사라져야 차단한 느낌이 난다 — 피드와 같은 처리다.
      final nextReplies = <String, List<Comment>>{};
      for (final entry in state.replies.entries) {
        nextReplies[entry.key] =
            entry.value.where((c) => c.userId != event.userId).toList();
      }
      emit(state.copyWith(
        comments: state.comments.where((c) => c.userId != event.userId).toList(),
        replies: nextReplies,
        isBlocking: false,
        signal: CommentsSignal.blocked,
      ));
    } catch (_) {
      emit(state.copyWith(isBlocking: false, signal: CommentsSignal.blockFailed));
    }
  }

  /// 부모 댓글의 답글 수를 [delta] 만큼 옮긴다. 0 밑으로는 안 내려간다.
  List<Comment> _withReplyCountChanged(String parentId, int delta) {
    return state.comments.map((c) {
      if (c.id != parentId) return c;
      final next = c.replyCount + delta;
      return Comment(
        id: c.id,
        sightingId: c.sightingId,
        userId: c.userId,
        parentId: c.parentId,
        content: c.content,
        reportCount: c.reportCount,
        isHidden: c.isHidden,
        createdAt: c.createdAt,
        userNickname: c.userNickname,
        userProfileImageUrl: c.userProfileImageUrl,
        userRole: c.userRole,
        userRepresentativeBadge: c.userRepresentativeBadge,
        replyCount: next < 0 ? 0 : next,
      );
    }).toList();
  }

  bool _isBanned(Object error) {
    final mapped = error is AppError ? error : AppError.from(error);
    return mapped == AppError.accountBanned;
  }
}
