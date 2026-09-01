import 'package:equatable/equatable.dart';

import '../../../domain/models/auth_provider.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// 화면 진입 — 마지막으로 쓴 로그인 방식을 읽어 "최근 로그인" 말풍선을 붙인다.
final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

final class AuthLoginPressed extends AuthEvent {
  const AuthLoginPressed(this.provider);

  final AuthProvider provider;

  @override
  List<Object?> get props => [provider];
}

/// 화면이 신호(스낵바 등)를 처리했음을 알린다.
final class AuthSignalConsumed extends AuthEvent {
  const AuthSignalConsumed();
}
