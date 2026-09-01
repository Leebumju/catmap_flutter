import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/auth_provider.dart';

/// 마지막으로 쓴 로그인 방식. 로그인 화면의 "최근 로그인" 말풍선에만 쓴다.
///
/// iOS 는 이걸 키체인에 넣어서 앱을 지웠다 깔아도 남는다. 안드로이드에서는
/// SharedPreferences 라 앱을 지우면 같이 지워진다 — 말풍선이 한 번 안 뜰 뿐,
/// 로그인 자체에는 영향이 없어서 여기까지만 맞췄다.
class LastLoginStorage {
  const LastLoginStorage();

  static const _key = 'lastLoginProvider';

  Future<AuthProvider?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AuthProvider.fromRawValue(prefs.getString(_key));
  }

  Future<void> save(AuthProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, provider.rawValue);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
