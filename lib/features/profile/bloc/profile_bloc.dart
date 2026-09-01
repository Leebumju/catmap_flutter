import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/last_login_storage.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/sighting_repository.dart';
import 'profile_event.dart';
import 'profile_state.dart';

/// 내 정보 화면. iOS 의 `ProfileFeature` 를 옮긴 것이다.
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc({
    required AuthRepository authRepository,
    required SightingRepository sightingRepository,
    LastLoginStorage lastLoginStorage = const LastLoginStorage(),
  })  : _auth = authRepository,
        _sightings = sightingRepository,
        _lastLogin = lastLoginStorage,
        super(const ProfileState()) {
    // 화면을 오갈 때마다 들어오는 이벤트라, 앞의 조회가 끝나기 전이면 새로 시작한다.
    on<ProfileStarted>(_onStarted, transformer: restartable());
    on<ProfileLogoutConfirmed>(_onLogout, transformer: droppable());
    on<ProfileDeleteAccountConfirmed>(_onDeleteAccount, transformer: droppable());
    on<ProfileSignalConsumed>((e, emit) => emit(state.copyWith(clearSignal: true)));
  }

  final AuthRepository _auth;
  final SightingRepository _sightings;
  final LastLoginStorage _lastLogin;

  Future<void> _onStarted(
    ProfileStarted event,
    Emitter<ProfileState> emit,
  ) async {
    // 이미 읽어둔 게 있으면 다시 부르지 않는다. iOS 와 같은 가드다.
    if (state.hasLoaded && !event.force) return;

    emit(state.copyWith(isLoading: true, clearSignal: true));

    try {
      final user = await _auth.currentUser();
      if (user == null) {
        emit(state.copyWith(
          isLoading: false,
          hasLoaded: true,
          sightings: const [],
          clearUser: true,
        ));
        return;
      }

      final sightings = await _sightings.fetchByUser(user.id);
      final provider = await _lastLogin.load();
      emit(state.copyWith(
        user: user,
        loginProvider: provider,
        sightings: sightings,
        isLoading: false,
        hasLoaded: true,
      ));
    } catch (_) {
      emit(state.copyWith(
        isLoading: false,
        hasLoaded: true,
        signal: ProfileSignal.loadFailed,
      ));
    }
  }

  Future<void> _onLogout(
    ProfileLogoutConfirmed event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(isWorking: true, clearSignal: true));
    try {
      await _auth.signOut();
      emit(state.copyWith(
        isWorking: false,
        clearUser: true,
        sightings: const [],
        hasLoaded: true,
      ));
    } catch (_) {
      emit(state.copyWith(isWorking: false, signal: ProfileSignal.logoutFailed));
    }
  }

  Future<void> _onDeleteAccount(
    ProfileDeleteAccountConfirmed event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(isWorking: true, clearSignal: true));
    try {
      await _auth.deleteAccount();
      emit(state.copyWith(
        isWorking: false,
        clearUser: true,
        sightings: const [],
        hasLoaded: true,
        signal: ProfileSignal.accountDeleted,
      ));
    } catch (_) {
      emit(state.copyWith(
        isWorking: false,
        signal: ProfileSignal.deleteAccountFailed,
      ));
    }
  }
}
