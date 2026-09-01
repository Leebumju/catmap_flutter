import 'package:bloc_test/bloc_test.dart';
import 'package:catmap_flutter/domain/models/app_user.dart';
import 'package:catmap_flutter/domain/repositories/auth_repository.dart';
import 'package:catmap_flutter/domain/repositories/sighting_repository.dart';
import 'package:catmap_flutter/features/upload/bloc/upload_gate_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSightingRepository extends Mock implements SightingRepository {}

class FakeAuthRepository extends Fake implements AuthRepository {
  FakeAuthRepository(this.user);

  AppUser? user;

  @override
  Future<AppUser?> currentUser() async => user;
}

AppUser makeUser({bool isBanned = false}) => AppUser(
      id: 'U1',
      email: 'me@example.com',
      isBanned: isBanned,
      createdAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSightingRepository sightings;
  late FakeAuthRepository auth;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sightings = MockSightingRepository();
    auth = FakeAuthRepository(makeUser());
    when(() => sightings.fetchMyCount()).thenAnswer((_) async => 0);
  });

  UploadGateBloc build() => UploadGateBloc(
        authRepository: auth,
        sightingRepository: sightings,
      );

  blocTest<UploadGateBloc, UploadGateState>(
    '비로그인이면 로그인을 요구하고 개수는 세지도 않는다',
    build: () {
      auth.user = null;
      return build();
    },
    act: (bloc) => bloc.add(const UploadGateCameraPressed()),
    verify: (bloc) {
      expect(bloc.state.signal, UploadGateSignal.loginRequired);
      verifyNever(() => sightings.fetchMyCount());
    },
  );

  blocTest<UploadGateBloc, UploadGateState>(
    '정지된 계정은 카메라를 열지 않는다',
    build: () {
      auth.user = makeUser(isBanned: true);
      return build();
    },
    act: (bloc) => bloc.add(const UploadGateCameraPressed()),
    verify: (bloc) =>
        expect(bloc.state.signal, UploadGateSignal.accountBanned),
  );

  blocTest<UploadGateBloc, UploadGateState>(
    '게시물이 30개면 제한 알림을 띄운다',
    build: () {
      when(() => sightings.fetchMyCount()).thenAnswer((_) async => 30);
      return build();
    },
    act: (bloc) => bloc.add(const UploadGateCameraPressed()),
    verify: (bloc) {
      expect(bloc.state.alert, UploadGateAlert.limitReached);
      expect(bloc.state.signal, isNull);
    },
  );

  blocTest<UploadGateBloc, UploadGateState>(
    '개수를 못 세면 카메라를 열지 않는다 — 열어주면 상한을 넘겨 올릴 수 있다',
    build: () {
      when(() => sightings.fetchMyCount()).thenThrow(Exception('네트워크'));
      return build();
    },
    act: (bloc) => bloc.add(const UploadGateCameraPressed()),
    verify: (bloc) => expect(bloc.state.signal, UploadGateSignal.checkFailed),
  );

  blocTest<UploadGateBloc, UploadGateState>(
    '처음에는 안내를 띄우고, 확인한 뒤에는 바로 카메라를 연다',
    build: build,
    act: (bloc) async {
      bloc.add(const UploadGateCameraPressed());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const UploadGateGuideConfirmed());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const UploadGateCameraPressed());
    },
    wait: const Duration(milliseconds: 50),
    verify: (bloc) {
      // 두 번째 진입에서는 안내 없이 카메라로 간다.
      expect(bloc.state.alert, isNull);
      expect(bloc.state.signal, UploadGateSignal.openCamera);
    },
  );
}
