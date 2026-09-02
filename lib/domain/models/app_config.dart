import 'package:equatable/equatable.dart';

/// 서버가 내려주는 앱 운영 설정. `app_config` 한 줄에 대응한다.
///
/// 두 가지를 정한다 — 이 버전보다 낮으면 업데이트를 강제할지, 그리고 지금 점검 중인지.
class AppConfig extends Equatable {
  const AppConfig({
    required this.minVersion,
    required this.maintenanceMode,
    this.maintenanceMessage,
  });

  /// 이 버전보다 낮으면 앱을 못 쓰게 막는다.
  final String minVersion;

  final bool maintenanceMode;
  final String? maintenanceMessage;

  /// 설정을 못 읽었을 때 쓰는 값. 막지 않는 쪽이 기본이다 —
  /// 서버가 잠깐 안 되는 것 때문에 앱 전체가 멈추면 안 된다. iOS 와 같은 판단이다.
  static const permissive =
      AppConfig(minVersion: '1.0.0', maintenanceMode: false);

  factory AppConfig.fromRow(Map<String, dynamic> row) {
    return AppConfig(
      minVersion: row['min_version'] as String? ?? '1.0.0',
      maintenanceMode: row['maintenance_mode'] as bool? ?? false,
      maintenanceMessage: row['maintenance_message'] as String?,
    );
  }

  @override
  List<Object?> get props => [minVersion, maintenanceMode, maintenanceMessage];
}

/// [current] 가 [minimum] 보다 낮으면 true — 업데이트가 필요하다는 뜻이다.
///
/// "1.2.0" 처럼 점으로 나뉜 숫자를 앞에서부터 견준다. 자리 수가 다르면
/// 없는 자리는 0 으로 본다("1.2" 는 "1.2.0" 과 같다). iOS 와 같은 규칙이다.
bool needsUpdate({required String current, required String minimum}) {
  List<int> parse(String version) => version
      .split('.')
      .map((part) => int.tryParse(part))
      .whereType<int>()
      .toList();

  final c = parse(current);
  final m = parse(minimum);
  final length = c.length > m.length ? c.length : m.length;

  for (var i = 0; i < length; i++) {
    final cv = i < c.length ? c[i] : 0;
    final mv = i < m.length ? m[i] : 0;
    if (cv < mv) return true;
    if (cv > mv) return false;
  }
  return false;
}
