import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/app_config.dart';
import '../domain/repositories/app_config_repository.dart';

/// iOS 의 `AppConfigClientLive` 와 같은 테이블을 읽는다.
class SupabaseAppConfigRepository implements AppConfigRepository {
  SupabaseAppConfigRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AppConfig> fetch() async {
    try {
      final row = await _client.from('app_config').select().limit(1).single();
      return AppConfig.fromRow(row);
    } catch (_) {
      // 설정을 못 읽었다고 앱을 멈추지 않는다. iOS 와 같은 처리다.
      return AppConfig.permissive;
    }
  }
}
