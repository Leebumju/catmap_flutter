import 'package:equatable/equatable.dart';

import '../../../domain/models/auth_provider.dart';

/// 화면이 한 번만 반응해야 하는 신호. 피드와 같은 방식이다.
enum AuthSignal {
  /// 로그인 창을 띄우지 못했다(브라우저 없음, 네트워크 등).
  loginFailed,

  /// 안드로이드에서 아직 못 쓰는 방식을 눌렀다.
  providerUnavailable,
}

class AuthPageState extends Equatable {
  const AuthPageState({
    this.isLaunching = false,
    this.lastLoginProvider,
    this.signal,
  });

  /// 로그인 창을 띄우는 동안만 true.
  ///
  /// 창이 뜬 뒤에는 false 로 되돌린다. 로그인 완료는 브라우저에서 딥링크로
  /// 돌아와야 알 수 있는데, 사용자가 그냥 브라우저를 닫고 돌아올 수도 있다.
  /// 그때 여기가 true 로 남아 있으면 화면이 영영 로딩 상태로 굳는다.
  final bool isLaunching;

  final AuthProvider? lastLoginProvider;
  final AuthSignal? signal;

  AuthPageState copyWith({
    bool? isLaunching,
    AuthProvider? lastLoginProvider,
    AuthSignal? signal,
    bool clearSignal = false,
  }) {
    return AuthPageState(
      isLaunching: isLaunching ?? this.isLaunching,
      lastLoginProvider: lastLoginProvider ?? this.lastLoginProvider,
      signal: clearSignal ? null : (signal ?? this.signal),
    );
  }

  @override
  List<Object?> get props => [isLaunching, lastLoginProvider, signal];
}
