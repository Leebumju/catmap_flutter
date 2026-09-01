import 'package:equatable/equatable.dart';

sealed class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

/// 화면 진입 — 사용자와 내 게시물을 읽는다.
final class ProfileStarted extends ProfileEvent {
  const ProfileStarted({this.force = false});

  /// 이미 읽어둔 게 있어도 다시 읽는다. 로그인·프로필 수정 뒤에 쓴다.
  final bool force;

  @override
  List<Object?> get props => [force];
}

final class ProfileSignalConsumed extends ProfileEvent {
  const ProfileSignalConsumed();
}

final class ProfileLogoutConfirmed extends ProfileEvent {
  const ProfileLogoutConfirmed();
}

final class ProfileDeleteAccountConfirmed extends ProfileEvent {
  const ProfileDeleteAccountConfirmed();
}
