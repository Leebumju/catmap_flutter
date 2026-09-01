import '../models/app_user.dart';
import '../models/auth_provider.dart';

/// 전역 인증 상태. iOS 의 `AuthState` 와 같은 세 가지다.
///
/// `unknown` 이 따로 있는 이유는, 앱이 막 켜졌을 때 "로그아웃 상태"와
/// "아직 확인 전"을 구분해야 하기 때문이다. 둘을 합치면 세션을 복원하는
/// 짧은 순간에 로그인 화면이 깜빡인다.
sealed class AuthStatus {
  const AuthStatus();
}

class AuthUnknown extends AuthStatus {
  const AuthUnknown();
}

class AuthLoggedIn extends AuthStatus {
  const AuthLoggedIn(this.user);

  final AppUser user;

  @override
  bool operator ==(Object other) => other is AuthLoggedIn && other.user == user;

  @override
  int get hashCode => user.hashCode;
}

class AuthLoggedOut extends AuthStatus {
  const AuthLoggedOut();

  @override
  bool operator ==(Object other) => other is AuthLoggedOut;

  @override
  int get hashCode => 0;
}

/// 인증. 구현(Supabase)은 data 계층에만 둔다.
abstract class AuthRepository {
  /// 로그인 상태가 아니면 null. 피드가 "내 글인지"를 판단할 때 쓴다.
  String? currentUserId();

  /// 서버의 users 행까지 읽어온 현재 사용자. 로그인 안 했으면 null.
  Future<AppUser?> currentUser();

  /// 로그인 창을 띄운다.
  ///
  /// **끝날 때까지 기다리지 않는다.** 안드로이드/웹의 OAuth 는 브라우저로 나갔다가
  /// 딥링크로 돌아오는 구조라, 로그인 완료는 [authStateChanges] 로 들어온다.
  /// (iOS 네이티브 SDK 는 세션을 바로 돌려줘서 이 부분이 다르다.)
  /// 창을 띄우지 못하면 예외를 던진다.
  Future<void> signIn(AuthProvider provider);

  Future<void> signOut();

  /// 인증 상태 변경 스트림. 로그인 직후 서버에 프로필 행이 없으면 만들어 준다.
  Stream<AuthStatus> authStateChanges();
}
