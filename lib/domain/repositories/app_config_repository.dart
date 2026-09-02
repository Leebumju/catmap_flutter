import '../models/app_config.dart';

/// 앱 운영 설정 조회. iOS 의 `AppConfigClient` 에 대응한다.
abstract class AppConfigRepository {
  /// 실패하면 막지 않는 기본값을 돌려준다 — 예외를 던지지 않는다.
  Future<AppConfig> fetch();
}
