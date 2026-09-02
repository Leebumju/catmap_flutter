import 'package:bloc_test/bloc_test.dart';
import 'package:catmap_flutter/domain/models/app_config.dart';
import 'package:catmap_flutter/domain/repositories/app_config_repository.dart';
import 'package:catmap_flutter/features/app/bloc/app_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAppConfigRepository implements AppConfigRepository {
  FakeAppConfigRepository(this.config);

  AppConfig config;

  @override
  Future<AppConfig> fetch() async => config;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAppConfigRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = FakeAppConfigRepository(AppConfig.permissive);
  });

  AppBloc build({String version = '1.0.0'}) => AppBloc(
        appConfigRepository: repository,
        currentVersion: version,
      );

  // 스플래시 시간이 있어서 그보다 넉넉히 기다린다.
  const settle = Duration(milliseconds: 1500);

  blocTest<AppBloc, AppState>(
    '처음 켜면 첫 실행 안내로 간다',
    build: build,
    act: (bloc) => bloc.add(const AppStarted()),
    wait: settle,
    verify: (bloc) => expect(bloc.state.gate, AppGate.onboarding),
  );

  blocTest<AppBloc, AppState>(
    '안내를 이미 봤으면 본 화면으로 바로 간다',
    build: () {
      SharedPreferences.setMockInitialValues(
          {AppBloc.hasSeenOnboardingKey: true});
      return build();
    },
    act: (bloc) => bloc.add(const AppStarted()),
    wait: settle,
    verify: (bloc) => expect(bloc.state.gate, AppGate.ready),
  );

  blocTest<AppBloc, AppState>(
    '점검 중이면 다른 무엇보다 먼저 점검 화면을 보여준다',
    build: () {
      repository.config = const AppConfig(
        minVersion: '9.9.9',
        maintenanceMode: true,
        maintenanceMessage: '서버 정비 중',
      );
      return build();
    },
    act: (bloc) => bloc.add(const AppStarted()),
    wait: settle,
    verify: (bloc) {
      expect(bloc.state.gate, AppGate.maintenance);
      expect(bloc.state.maintenanceMessage, '서버 정비 중');
    },
  );

  blocTest<AppBloc, AppState>(
    '버전이 최소 버전보다 낮으면 업데이트 화면에서 막는다',
    build: () {
      repository.config =
          const AppConfig(minVersion: '2.0.0', maintenanceMode: false);
      return build(version: '1.9.9');
    },
    act: (bloc) => bloc.add(const AppStarted()),
    wait: settle,
    verify: (bloc) => expect(bloc.state.gate, AppGate.forceUpdate),
  );

  blocTest<AppBloc, AppState>(
    '안내를 마치면 다음부터는 다시 보여주지 않는다',
    build: build,
    act: (bloc) => bloc.add(const AppOnboardingFinished()),
    verify: (bloc) async {
      expect(bloc.state.gate, AppGate.ready);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppBloc.hasSeenOnboardingKey), isTrue);
    },
  );

  group('버전 비교', () {
    test('낮으면 업데이트가 필요하다', () {
      expect(needsUpdate(current: '1.0.0', minimum: '1.1.0'), isTrue);
      expect(needsUpdate(current: '1.9.9', minimum: '2.0.0'), isTrue);
    });

    test('같거나 높으면 필요 없다', () {
      expect(needsUpdate(current: '1.1.0', minimum: '1.1.0'), isFalse);
      expect(needsUpdate(current: '2.0.0', minimum: '1.9.9'), isFalse);
    });

    test('자리 수가 달라도 없는 자리는 0 으로 본다', () {
      expect(needsUpdate(current: '1.2', minimum: '1.2.0'), isFalse);
      expect(needsUpdate(current: '1.2', minimum: '1.2.1'), isTrue);
    });
  });
}
