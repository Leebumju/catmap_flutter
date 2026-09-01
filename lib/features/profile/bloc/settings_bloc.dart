import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/notification_settings.dart';
import '../../../domain/repositories/profile_repository.dart';

sealed class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

final class SettingsStarted extends SettingsEvent {
  const SettingsStarted();
}

/// 어떤 알림을 켜고 끄는지.
enum NotificationKind { like, confirmation, comment }

final class SettingsNotificationToggled extends SettingsEvent {
  const SettingsNotificationToggled(this.kind, this.enabled);

  final NotificationKind kind;
  final bool enabled;

  @override
  List<Object?> get props => [kind, enabled];
}

class SettingsState extends Equatable {
  const SettingsState({
    this.settings = const NotificationSettings(),
    this.isLoading = false,
  });

  final NotificationSettings settings;
  final bool isLoading;

  SettingsState copyWith({NotificationSettings? settings, bool? isLoading}) {
    return SettingsState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [settings, isLoading];
}

/// 설정 화면의 알림 스위치. iOS 의 ProfileFeature 안에 있던 부분을 떼어냈다.
///
/// 스위치를 누르면 화면에 먼저 반영하고 서버에 보낸다. 서버 저장이 실패해도
/// 되돌리지 않는다 — iOS 도 `try?` 로 흘려보낸다.
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc({required NotificationSettingsRepository repository})
      : _repository = repository,
        super(const SettingsState()) {
    on<SettingsStarted>(_onStarted);
    on<SettingsNotificationToggled>(_onToggled, transformer: sequential());
  }

  final NotificationSettingsRepository _repository;

  Future<void> _onStarted(
    SettingsStarted event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final settings = await _repository.fetch();
      emit(state.copyWith(settings: settings, isLoading: false));
    } catch (_) {
      // 못 읽으면 기본값(전부 켜짐)으로 둔다.
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onToggled(
    SettingsNotificationToggled event,
    Emitter<SettingsState> emit,
  ) async {
    final next = switch (event.kind) {
      NotificationKind.like => state.settings.copyWith(likeEnabled: event.enabled),
      NotificationKind.confirmation =>
        state.settings.copyWith(confirmationEnabled: event.enabled),
      NotificationKind.comment =>
        state.settings.copyWith(commentEnabled: event.enabled),
    };
    emit(state.copyWith(settings: next));

    try {
      await _repository.update(next);
    } catch (_) {
      // 저장 실패는 조용히 넘긴다. iOS 와 같다.
    }
  }
}
