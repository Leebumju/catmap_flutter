/// 로그인 제공자. rawValue 는 Supabase 의 OAuth provider 이름과 같다.
///
/// iOS 는 카카오·애플 둘 다 쓴다. 안드로이드는 카카오만 노출한다 —
/// 애플 로그인은 안드로이드에 네이티브 경로가 없어 Supabase 대시보드에
/// Apple OAuth(Services ID) 를 따로 설정해야 하는데, 아직 안 했다.
enum AuthProvider {
  kakao('kakao'),
  apple('apple');

  const AuthProvider(this.rawValue);

  final String rawValue;

  static AuthProvider? fromRawValue(String? raw) {
    for (final p in AuthProvider.values) {
      if (p.rawValue == raw) return p;
    }
    return null;
  }
}
