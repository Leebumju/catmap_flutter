import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/sighting_repository.dart';

sealed class UploadGateEvent extends Equatable {
  const UploadGateEvent();

  @override
  List<Object?> get props => [];
}

final class UploadGateCameraPressed extends UploadGateEvent {
  const UploadGateCameraPressed();
}

/// 최초 안내를 읽고 확인을 누름.
final class UploadGateGuideConfirmed extends UploadGateEvent {
  const UploadGateGuideConfirmed();
}

final class UploadGateAlertDismissed extends UploadGateEvent {
  const UploadGateAlertDismissed();
}

final class UploadGateSignalConsumed extends UploadGateEvent {
  const UploadGateSignalConsumed();
}

/// 게이트가 막았을 때 띄우는 알림.
enum UploadGateAlert {
  /// 게시물 30개 제한
  limitReached,

  /// 최초 1회 업로드 안내
  guide,
}

/// 게이트를 통과했거나, 화면 바깥이 처리해야 하는 결과.
enum UploadGateSignal {
  openCamera,
  loginRequired,
  accountBanned,
  checkFailed,
}

class UploadGateState extends Equatable {
  const UploadGateState({
    this.isChecking = false,
    this.alert,
    this.signal,
  });

  final bool isChecking;
  final UploadGateAlert? alert;
  final UploadGateSignal? signal;

  UploadGateState copyWith({
    bool? isChecking,
    UploadGateAlert? alert,
    UploadGateSignal? signal,
    bool clearAlert = false,
    bool clearSignal = false,
  }) {
    return UploadGateState(
      isChecking: isChecking ?? this.isChecking,
      alert: clearAlert ? null : (alert ?? this.alert),
      signal: clearSignal ? null : (signal ?? this.signal),
    );
  }

  @override
  List<Object?> get props => [isChecking, alert, signal];
}

/// 카메라 버튼을 눌렀을 때의 공통 관문. iOS 의 `UploadEntryFeature` 와 같다.
///
/// 지도와 피드 양쪽에 같은 버튼이 있어서, 정책(로그인 → 정지 → 개수 제한 →
/// 최초 안내)을 한 곳에 둔다. 화면마다 따로 검사하면 한쪽만 고치는 일이 생긴다.
class UploadGateBloc extends Bloc<UploadGateEvent, UploadGateState> {
  UploadGateBloc({
    required AuthRepository authRepository,
    required SightingRepository sightingRepository,
  })  : _auth = authRepository,
        _sightings = sightingRepository,
        super(const UploadGateState()) {
    on<UploadGateCameraPressed>(_onCameraPressed);
    on<UploadGateGuideConfirmed>(_onGuideConfirmed);
    on<UploadGateAlertDismissed>((e, emit) => emit(state.copyWith(clearAlert: true)));
    on<UploadGateSignalConsumed>((e, emit) => emit(state.copyWith(clearSignal: true)));
  }

  /// 게시물 상한. iOS 와 같은 값이다.
  static const uploadLimit = 30;

  /// 지도·피드 어느 쪽으로 들어와도 안내는 최초 1회만. iOS 와 같은 키를 쓴다.
  static const hasSeenGuideKey = 'hasSeenUploadGuide';

  final AuthRepository _auth;
  final SightingRepository _sightings;

  Future<void> _onCameraPressed(
    UploadGateCameraPressed event,
    Emitter<UploadGateState> emit,
  ) async {
    emit(state.copyWith(isChecking: true, clearAlert: true, clearSignal: true));

    final user = await _auth.currentUser();
    if (user == null) {
      emit(state.copyWith(
        isChecking: false,
        signal: UploadGateSignal.loginRequired,
      ));
      return;
    }
    if (user.isBanned) {
      emit(state.copyWith(
        isChecking: false,
        signal: UploadGateSignal.accountBanned,
      ));
      return;
    }

    int count;
    try {
      count = await _sightings.fetchMyCount();
    } catch (_) {
      // 개수를 못 세면 통과시키지 않는다. 여기서 열어주면 상한을 넘겨 올릴 수 있다.
      emit(state.copyWith(
        isChecking: false,
        signal: UploadGateSignal.checkFailed,
      ));
      return;
    }

    if (count >= uploadLimit) {
      emit(state.copyWith(
        isChecking: false,
        alert: UploadGateAlert.limitReached,
      ));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(hasSeenGuideKey) ?? false) {
      emit(state.copyWith(
        isChecking: false,
        signal: UploadGateSignal.openCamera,
      ));
      return;
    }
    emit(state.copyWith(isChecking: false, alert: UploadGateAlert.guide));
  }

  Future<void> _onGuideConfirmed(
    UploadGateGuideConfirmed event,
    Emitter<UploadGateState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hasSeenGuideKey, true);
    emit(state.copyWith(
      clearAlert: true,
      signal: UploadGateSignal.openCamera,
    ));
  }
}
