import 'package:equatable/equatable.dart';

import '../../../domain/models/app_user.dart';
import '../../../domain/models/auth_provider.dart';
import '../../../domain/models/sighting.dart';

/// 화면이 한 번만 반응해야 하는 신호.
enum ProfileSignal {
  logoutFailed,

  /// 탈퇴가 끝났다. 화면은 안내를 띄우고 로그아웃된 상태로 돌아간다.
  accountDeleted,

  deleteAccountFailed,
  loadFailed,
}

class ProfileState extends Equatable {
  const ProfileState({
    this.user,
    this.loginProvider,
    this.sightings = const [],
    this.isLoading = false,
    this.hasLoaded = false,
    this.isWorking = false,
    this.signal,
  });

  final AppUser? user;

  /// 마지막으로 쓴 로그인 방식. 설정 화면의 "로그인 방식" 에만 쓴다.
  final AuthProvider? loginProvider;

  final List<Sighting> sightings;
  final bool isLoading;

  /// 한 번이라도 읽어봤는지. 다시 들어올 때마다 서버를 부르지 않기 위한 표시다.
  final bool hasLoaded;

  /// 로그아웃·탈퇴처럼 되돌릴 수 없는 작업이 도는 중.
  final bool isWorking;

  final ProfileSignal? signal;

  bool get isLoggedIn => user != null;

  int get sightingCount => sightings.length;

  ProfileState copyWith({
    AppUser? user,
    AuthProvider? loginProvider,
    List<Sighting>? sightings,
    bool? isLoading,
    bool? hasLoaded,
    bool? isWorking,
    ProfileSignal? signal,
    bool clearUser = false,
    bool clearSignal = false,
  }) {
    return ProfileState(
      user: clearUser ? null : (user ?? this.user),
      loginProvider: loginProvider ?? this.loginProvider,
      sightings: sightings ?? this.sightings,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      isWorking: isWorking ?? this.isWorking,
      signal: clearSignal ? null : (signal ?? this.signal),
    );
  }

  @override
  List<Object?> get props =>
      [user, loginProvider, sightings, isLoading, hasLoaded, isWorking, signal];
}
