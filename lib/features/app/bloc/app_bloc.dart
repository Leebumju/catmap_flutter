import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/models/app_config.dart';
import '../../../domain/repositories/app_config_repository.dart';

sealed class AppEvent extends Equatable {
  const AppEvent();

  @override
  List<Object?> get props => [];
}

/// 앱이 켜졌다 — 설정을 받아오고 스플래시를 얼마간 보여준다.
final class AppStarted extends AppEvent {
  const AppStarted();
}

final class AppOnboardingFinished extends AppEvent {
  const AppOnboardingFinished();
}

/// 앱이 지금 어느 문 앞에 있는지.
enum AppGate {
  /// 시작 화면
  splash,

  /// 버전이 낮아 업데이트해야 한다
  forceUpdate,

  /// 서버 점검 중
  maintenance,

  /// 첫 실행 안내
  onboarding,

  /// 본 화면
  ready,
}

class AppState extends Equatable {
  const AppState({
    this.gate = AppGate.splash,
    this.maintenanceMessage,
  });

  final AppGate gate;
  final String? maintenanceMessage;

  @override
  List<Object?> get props => [gate, maintenanceMessage];
}

/// 앱을 열었을 때 무엇을 먼저 보여줄지 정하는 문지기.
/// iOS 의 `AppFeature` 중 스플래시·강제 업데이트·점검·온보딩 부분에 해당한다.
class AppBloc extends Bloc<AppEvent, AppState> {
  AppBloc({
    required AppConfigRepository appConfigRepository,
    required String currentVersion,
  })  : _appConfig = appConfigRepository,
        _currentVersion = currentVersion,
        super(const AppState()) {
    on<AppStarted>(_onStarted);
    on<AppOnboardingFinished>(_onOnboardingFinished);
  }

  /// 스플래시를 최소한 이만큼은 보여준다. 너무 빨리 사라지면 깜빡인 것처럼 보인다.
  static const splashDuration = Duration(milliseconds: 1200);

  static const hasSeenOnboardingKey = 'hasSeenOnboarding';

  final AppConfigRepository _appConfig;
  final String _currentVersion;

  Future<void> _onStarted(AppStarted event, Emitter<AppState> emit) async {
    // 설정 조회와 스플래시 시간을 같이 흘려보낸다. 둘 중 늦은 쪽까지 기다린다.
    final results = await Future.wait([
      _appConfig.fetch(),
      Future<void>.delayed(splashDuration),
    ]);
    final config = results.first as AppConfig;

    if (config.maintenanceMode) {
      emit(AppState(
        gate: AppGate.maintenance,
        maintenanceMessage: config.maintenanceMessage,
      ));
      return;
    }

    if (needsUpdate(current: _currentVersion, minimum: config.minVersion)) {
      emit(const AppState(gate: AppGate.forceUpdate));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(hasSeenOnboardingKey) ?? false;
    emit(AppState(gate: seen ? AppGate.ready : AppGate.onboarding));
  }

  Future<void> _onOnboardingFinished(
    AppOnboardingFinished event,
    Emitter<AppState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hasSeenOnboardingKey, true);
    emit(const AppState(gate: AppGate.ready));
  }
}
