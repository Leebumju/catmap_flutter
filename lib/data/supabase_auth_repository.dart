import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/app_error.dart';
import '../domain/models/app_user.dart';
import '../domain/models/auth_provider.dart' as domain;
import '../domain/models/nickname_generator.dart';
import '../domain/repositories/auth_repository.dart';
import 'last_login_storage.dart';

/// iOS 의 `AuthClientLive` 와 같은 서버를 같은 방식으로 쓴다.
/// 카카오 로그인은 양쪽 다 Supabase 의 OAuth 웹 플로우이고, 돌아오는 주소도
/// `catmap://login-callback` 으로 같다.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(
    this._client, {
    LastLoginStorage lastLoginStorage = const LastLoginStorage(),
  }) : _lastLogin = lastLoginStorage;

  final SupabaseClient _client;
  final LastLoginStorage _lastLogin;

  /// iOS 의 `SupabaseClientProvider.configure(redirectToURL:)` 와 같은 값.
  /// 안드로이드는 이 주소를 받을 intent-filter 가 AndroidManifest 에 있어야 한다.
  static const redirectUrl = 'catmap://login-callback';

  /// 닉네임 unique 제약에 걸렸을 때 숫자를 붙여 다시 시도하는 횟수. iOS 와 같다.
  static const _nicknameRetryLimit = 10;

  @override
  String? currentUserId() => _client.auth.currentUser?.id;

  @override
  Future<AppUser?> currentUser() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;
    return _loadProfile(session.user);
  }

  @override
  Future<void> signIn(domain.AuthProvider provider) async {
    if (provider == domain.AuthProvider.apple) {
      // 안드로이드에는 애플 로그인의 네이티브 경로가 없다. 웹 플로우로 지원하려면
      // Supabase 대시보드에 Apple OAuth(Services ID + 비밀키) 설정이 먼저 필요하다.
      throw AppError.loginFailed;
    }

    final launched = await _client.auth.signInWithOAuth(
      OAuthProvider.kakao,
      redirectTo: redirectUrl,
    );
    if (!launched) throw AppError.loginFailed;
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (error) {
      throw AppError.from(error);
    }
  }

  @override
  Future<AppUser> updateNickname(String nickname) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AppError.authRequired;

    try {
      await _client.from('users').update({'nickname': nickname}).eq('id', userId);
      final rows = await _client.from('users').select().eq('id', userId);
      if (rows.isEmpty) throw AppError.unknown;
      return AppUser.fromRow(rows.first);
    } catch (error) {
      if (error is AppError) rethrow;
      throw AppError.from(error);
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _client.rpc<dynamic>('delete_account');
    } catch (error) {
      throw AppError.from(error);
    }
    // 계정이 이미 지워졌으므로 서버에 로그아웃을 요청하지 않는다.
    // 로컬 세션만 정리한다 — iOS 도 같은 이유로 scope: .local 을 쓴다.
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      // 로컬 정리 실패는 무시한다. 탈퇴 자체는 이미 끝났다.
    }
  }

  @override
  Stream<AuthStatus> authStateChanges() {
    return _client.auth.onAuthStateChange.asyncMap((data) async {
      switch (data.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.initialSession:
          final user = data.session?.user;
          if (user == null) return const AuthLoggedOut();
          // "최근 로그인" 은 로그인이 실제로 성사된 이 자리에서만 기록한다.
          // 세션 복원(initialSession)이나 토큰 갱신은 새 로그인이 아니다.
          if (data.event == AuthChangeEvent.signedIn) {
            await _rememberProvider(user);
          }
          // 로그인 직후 users 행이 없을 수 있다(첫 로그인). iOS 는 signIn 안에서
          // upsert 하는데, 여기서는 세션이 딥링크로 나중에 도착하므로 이 자리가 그 지점이다.
          await _ensureProfile(user);
          final profile = await _loadProfile(user);
          return profile == null
              ? const AuthLoggedOut()
              : AuthLoggedIn(profile);
        case AuthChangeEvent.signedOut:
          return const AuthLoggedOut();
        default:
          return const AuthUnknown();
      }
    }).where((status) => status is! AuthUnknown);
  }

  // MARK: - 내부

  /// 어떤 방식으로 로그인했는지 기록한다. 값은 세션이 알려준다.
  Future<void> _rememberProvider(User sessionUser) async {
    final raw = sessionUser.appMetadata['provider'] as String?;
    final provider = domain.AuthProvider.fromRawValue(raw);
    if (provider == null) return;
    await _lastLogin.save(provider);
  }

  /// 세션의 계정으로 users 행을 읽는다.
  ///
  /// iOS 와 같은 규칙:
  /// - DB 조회가 실패하면(네트워크 등) 세션 정보로 최소한의 사용자를 만들어 준다 —
  ///   일시적인 오류로 로그아웃된 것처럼 보이면 안 된다
  /// - DB 에 행이 없으면(탈퇴 등) null
  Future<AppUser?> _loadProfile(User sessionUser) async {
    List<Map<String, dynamic>> rows;
    try {
      rows = await _client
          .from('users')
          .select()
          .eq('id', sessionUser.id);
    } catch (_) {
      return _fromSession(sessionUser);
    }

    if (rows.isEmpty) return null;

    final row = rows.first;
    final nickname = row['nickname'] as String?;
    if (nickname != null && nickname.isNotEmpty) {
      return AppUser.fromRow(row);
    }

    // 닉네임이 비어 있으면 만들어 넣고 그 값으로 돌려준다. iOS 와 같다.
    final generated = NicknameGenerator.generate();
    try {
      await _client
          .from('users')
          .update({'nickname': generated}).eq('id', sessionUser.id);
    } catch (_) {
      // 실패해도 화면은 닉네임을 보여줄 수 있어야 한다.
    }
    return AppUser.fromRow({...row, 'nickname': generated});
  }

  AppUser _fromSession(User sessionUser) {
    return AppUser(
      id: sessionUser.id,
      email: sessionUser.email ?? '',
      nickname: sessionUser.userMetadata?['nickname'] as String?,
      profileImageUrl: sessionUser.userMetadata?['avatar_url'] as String?,
      createdAt: DateTime.parse(sessionUser.createdAt).toUtc(),
    );
  }

  /// users 행이 없으면 만든다. 닉네임이 겹치면 숫자를 붙여 다시 시도한다.
  Future<void> _ensureProfile(User sessionUser) async {
    Map<String, dynamic>? existing;
    try {
      existing = await _client
          .from('users')
          .select('nickname')
          .eq('id', sessionUser.id)
          .maybeSingle();
    } catch (_) {
      existing = null;
    }

    final existingNickname = existing?['nickname'] as String?;
    final base = (existingNickname != null && existingNickname.isNotEmpty)
        ? existingNickname
        : NicknameGenerator.generate();

    var nickname = base;
    for (var attempt = 0; attempt < _nicknameRetryLimit; attempt++) {
      try {
        await _client.from('users').upsert({
          'id': sessionUser.id,
          'email': sessionUser.email ?? '',
          'nickname': nickname,
        });
        return;
      } catch (error) {
        if (!_isDuplicateNickname(error)) rethrow;
        nickname = '$base${attempt + 1}';
      }
    }

    // 10번 다 걸리면 겹칠 수 없는 접미사로 확정한다. iOS 와 같은 마지막 수단이다.
    final suffix = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    await _client.from('users').upsert({
      'id': sessionUser.id,
      'email': sessionUser.email ?? '',
      'nickname': '${base}_$suffix',
    });
  }

  /// 닉네임 unique 제약 위반인지 판별.
  ///
  /// PostgREST 는 이걸 코드 23505 로 내려준다. iOS 는 메시지 문자열로 봤는데,
  /// Dart SDK 는 코드를 그대로 주므로 코드로 본다 — 문자열보다 덜 깨진다.
  bool _isDuplicateNickname(Object error) {
    if (error is PostgrestException) {
      if (error.code == '23505') return true;
      final message = error.message.toLowerCase();
      return message.contains('unique') || message.contains('duplicate');
    }
    return false;
  }
}
