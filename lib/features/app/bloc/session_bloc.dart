import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/auth_repository.dart';

sealed class SessionEvent extends Equatable {
  const SessionEvent();

  @override
  List<Object?> get props => [];
}

/// 앱 시작 — 저장된 세션을 확인하고, 이후 변화는 스트림으로 계속 듣는다.
final class SessionStarted extends SessionEvent {
  const SessionStarted();
}

final class SessionSignOutPressed extends SessionEvent {
  const SessionSignOutPressed();
}

/// 전역 로그인 상태 하나만 들고 있는 bloc.
///
/// iOS 의 `AppFeature` 가 `authStateStream` 을 구독해 하던 일이다. 화면마다
/// 따로 로그인 여부를 물어보면 화면끼리 상태가 어긋나므로 여기 한 곳에서만 듣는다.
class SessionBloc extends Bloc<SessionEvent, AuthStatus> {
  SessionBloc({required AuthRepository authRepository})
      : _auth = authRepository,
        super(const AuthUnknown()) {
    on<SessionStarted>(_onStarted);
    on<SessionSignOutPressed>(_onSignOut);
  }

  final AuthRepository _auth;

  Future<void> _onStarted(
    SessionStarted event,
    Emitter<AuthStatus> emit,
  ) async {
    // 스트림이 첫 값을 줄 때까지 기다리지 않고, 저장된 세션으로 먼저 답을 낸다.
    // 그래야 앱을 켜자마자 로그인 상태가 정해진다.
    try {
      final user = await _auth.currentUser();
      emit(user == null ? const AuthLoggedOut() : AuthLoggedIn(user));
    } catch (_) {
      emit(const AuthLoggedOut());
    }

    await emit.forEach<AuthStatus>(
      _auth.authStateChanges(),
      onData: (status) => status,
      // 스트림이 끊겨도 로그인 상태를 함부로 내리지 않는다. 네트워크 오류 한 번에
      // 로그아웃된 것처럼 보이면 안 된다.
      onError: (_, __) => state,
    );
  }

  Future<void> _onSignOut(
    SessionSignOutPressed event,
    Emitter<AuthStatus> emit,
  ) async {
    await _auth.signOut();
    // 실제 상태 변경은 스트림이 signedOut 을 흘려보내면서 반영된다.
  }
}
