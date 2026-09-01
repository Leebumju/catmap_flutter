import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/notification_settings.dart';
import '../../../domain/repositories/profile_repository.dart';

sealed class BlockListEvent extends Equatable {
  const BlockListEvent();

  @override
  List<Object?> get props => [];
}

final class BlockListStarted extends BlockListEvent {
  const BlockListStarted();
}

final class BlockListUnblockPressed extends BlockListEvent {
  const BlockListUnblockPressed(this.blockedUserId);

  final String blockedUserId;

  @override
  List<Object?> get props => [blockedUserId];
}

final class BlockListSignalConsumed extends BlockListEvent {
  const BlockListSignalConsumed();
}

enum BlockListSignal { loadFailed, unblockFailed }

class BlockListState extends Equatable {
  const BlockListState({
    this.users = const [],
    this.isLoading = false,
    this.signal,
  });

  final List<BlockedUser> users;
  final bool isLoading;
  final BlockListSignal? signal;

  BlockListState copyWith({
    List<BlockedUser>? users,
    bool? isLoading,
    BlockListSignal? signal,
    bool clearSignal = false,
  }) {
    return BlockListState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      signal: clearSignal ? null : (signal ?? this.signal),
    );
  }

  @override
  List<Object?> get props => [users, isLoading, signal];
}

/// 차단 목록. iOS 의 `BlockListFeature` 와 같다.
class BlockListBloc extends Bloc<BlockListEvent, BlockListState> {
  BlockListBloc({required BlockRepository repository})
      : _repository = repository,
        super(const BlockListState()) {
    on<BlockListStarted>(_onStarted);
    // 같은 사람을 두 번 해제하지 않도록 진행 중에는 새 요청을 버린다.
    on<BlockListUnblockPressed>(_onUnblock, transformer: droppable());
    on<BlockListSignalConsumed>((e, emit) => emit(state.copyWith(clearSignal: true)));
  }

  final BlockRepository _repository;

  Future<void> _onStarted(
    BlockListStarted event,
    Emitter<BlockListState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearSignal: true));
    try {
      final users = await _repository.fetchBlockedUsers();
      emit(state.copyWith(users: users, isLoading: false));
    } catch (_) {
      emit(state.copyWith(isLoading: false, signal: BlockListSignal.loadFailed));
    }
  }

  Future<void> _onUnblock(
    BlockListUnblockPressed event,
    Emitter<BlockListState> emit,
  ) async {
    try {
      await _repository.unblockUser(event.blockedUserId);
      emit(state.copyWith(
        users: state.users
            .where((u) => u.blockedUserId != event.blockedUserId)
            .toList(),
      ));
    } catch (_) {
      emit(state.copyWith(signal: BlockListSignal.unblockFailed));
    }
  }
}
