import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/last_login_storage.dart';
import '../../../domain/models/auth_provider.dart';
import '../../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// 로그인 화면. iOS 의 `AuthFeature` 에 대응한다.
///
/// 다른 점이 하나 있다. iOS 는 `signIn` 이 세션을 바로 돌려줘서 성공/실패를 여기서
/// 다뤘다. 안드로이드는 브라우저로 나갔다가 딥링크로 돌아오는 구조라, 로그인 성공은
/// 이 bloc 이 아니라 세션 스트림(SessionBloc)이 받는다. 여기는 창을 띄우는 것까지만
/// 책임진다.
class AuthBloc extends Bloc<AuthEvent, AuthPageState> {
  AuthBloc({
    required AuthRepository authRepository,
    LastLoginStorage lastLoginStorage = const LastLoginStorage(),
  })  : _auth = authRepository,
        _lastLogin = lastLoginStorage,
        super(const AuthPageState()) {
    on<AuthStarted>(_onStarted);
    // 버튼 연타로 로그인 창이 두 번 뜨지 않게 막는다.
    on<AuthLoginPressed>(_onLoginPressed, transformer: droppable());
    on<AuthSignalConsumed>(_onSignalConsumed);
  }

  final AuthRepository _auth;
  final LastLoginStorage _lastLogin;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthPageState> emit) async {
    final provider = await _lastLogin.load();
    if (provider == null) return;
    emit(state.copyWith(lastLoginProvider: provider));
  }

  Future<void> _onLoginPressed(
    AuthLoginPressed event,
    Emitter<AuthPageState> emit,
  ) async {
    if (event.provider == AuthProvider.apple) {
      emit(state.copyWith(signal: AuthSignal.providerUnavailable));
      return;
    }

    emit(state.copyWith(isLaunching: true, clearSignal: true));
    try {
      await _auth.signIn(event.provider);
      // 창을 띄우는 데까지 성공했다. 실제 로그인 결과는 세션 스트림으로 온다.
      // "최근 로그인" 저장도 거기서 한다 — 여기서 저장하면 사용자가 로그인을
      // 취소하고 돌아와도 저장돼 버린다(iOS 는 성공했을 때만 저장한다).
      emit(state.copyWith(isLaunching: false));
    } catch (_) {
      emit(state.copyWith(isLaunching: false, signal: AuthSignal.loginFailed));
    }
  }

  void _onSignalConsumed(AuthSignalConsumed event, Emitter<AuthPageState> emit) {
    emit(state.copyWith(clearSignal: true));
  }
}
