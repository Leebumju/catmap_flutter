import 'package:bloc_test/bloc_test.dart';
import 'package:catmap_flutter/domain/models/app_user.dart';
import 'package:catmap_flutter/domain/models/auth_provider.dart';
import 'package:catmap_flutter/domain/models/badge.dart';
import 'package:catmap_flutter/domain/models/cat_type.dart';
import 'package:catmap_flutter/domain/models/sighting.dart';
import 'package:catmap_flutter/domain/repositories/auth_repository.dart';
import 'package:catmap_flutter/domain/repositories/profile_repository.dart';
import 'package:catmap_flutter/domain/repositories/sighting_repository.dart';
import 'package:catmap_flutter/features/profile/bloc/profile_bloc.dart';
import 'package:catmap_flutter/features/profile/bloc/profile_edit_bloc.dart';
import 'package:catmap_flutter/features/profile/bloc/profile_event.dart';
import 'package:catmap_flutter/features/profile/bloc/profile_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSightingRepository extends Mock implements SightingRepository {}

class MockBadgeRepository extends Mock implements BadgeRepository {}

class FakeAuthRepository extends Fake implements AuthRepository {
  FakeAuthRepository(this.user);

  AppUser? user;
  bool signOutCalled = false;
  bool deleteAccountCalled = false;
  String? updatedNickname;
  Object? throwOnDelete;

  @override
  Future<AppUser?> currentUser() async => user;

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    user = null;
  }

  @override
  Future<void> deleteAccount() async {
    final error = throwOnDelete;
    if (error != null) throw error;
    deleteAccountCalled = true;
    user = null;
  }

  @override
  Future<AppUser> updateNickname(String nickname) async {
    updatedNickname = nickname;
    final current = user!;
    user = AppUser(
      id: current.id,
      email: current.email,
      nickname: nickname,
      createdAt: current.createdAt,
      representativeBadge: current.representativeBadge,
    );
    return user!;
  }
}

AppUser makeUser({String? nickname = '냥집사', Badge? badge}) => AppUser(
      id: 'U1',
      email: 'someone@example.com',
      nickname: nickname,
      createdAt: DateTime.utc(2026, 1, 1),
      representativeBadge: badge,
    );

Sighting makeSighting(String id) => Sighting(
      id: id,
      userId: 'U1',
      photoUrls: ['https://example.com/$id.jpg'],
      latitude: 37.5,
      longitude: 127,
      catType: CatType.stray,
      createdAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // mocktail 의 any() 는 타입마다 "빈 값"을 알아야 한다. when() 보다 먼저 등록해야 한다.
  setUpAll(() => registerFallbackValue(Badge.beginnerExplorer));

  late MockSightingRepository sightings;
  late FakeAuthRepository auth;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sightings = MockSightingRepository();
    auth = FakeAuthRepository(makeUser());
    when(() => sightings.fetchByUser(any()))
        .thenAnswer((_) async => [makeSighting('S1'), makeSighting('S2')]);
  });

  group('내 정보', () {
    ProfileBloc build() => ProfileBloc(
          authRepository: auth,
          sightingRepository: sightings,
        );

    blocTest<ProfileBloc, ProfileState>(
      '로그인 상태면 내 게시물을 읽어온다',
      build: build,
      act: (bloc) => bloc.add(const ProfileStarted()),
      verify: (bloc) {
        expect(bloc.state.isLoggedIn, isTrue);
        expect(bloc.state.sightingCount, 2);
      },
    );

    blocTest<ProfileBloc, ProfileState>(
      '비로그인이면 게시물을 부르지 않는다',
      build: () {
        auth.user = null;
        return build();
      },
      act: (bloc) => bloc.add(const ProfileStarted()),
      verify: (bloc) {
        expect(bloc.state.isLoggedIn, isFalse);
        verifyNever(() => sightings.fetchByUser(any()));
      },
    );

    blocTest<ProfileBloc, ProfileState>(
      '이미 읽었으면 다시 부르지 않는다 — 탭을 오갈 때마다 서버를 치면 안 된다',
      build: build,
      act: (bloc) async {
        bloc.add(const ProfileStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ProfileStarted());
      },
      wait: const Duration(milliseconds: 50),
      verify: (_) => verify(() => sightings.fetchByUser(any())).called(1),
    );

    blocTest<ProfileBloc, ProfileState>(
      'force 를 주면 다시 읽는다 — 로그인·프로필 수정 뒤에 쓴다',
      build: build,
      act: (bloc) async {
        bloc.add(const ProfileStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ProfileStarted(force: true));
      },
      wait: const Duration(milliseconds: 50),
      verify: (_) => verify(() => sightings.fetchByUser(any())).called(2),
    );

    blocTest<ProfileBloc, ProfileState>(
      '로그아웃하면 사용자와 게시물이 비워진다',
      build: build,
      act: (bloc) async {
        bloc.add(const ProfileStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ProfileLogoutConfirmed());
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(auth.signOutCalled, isTrue);
        expect(bloc.state.isLoggedIn, isFalse);
        expect(bloc.state.sightings, isEmpty);
      },
    );

    blocTest<ProfileBloc, ProfileState>(
      '회원탈퇴가 끝나면 로그아웃 상태가 되고 완료 신호를 낸다',
      build: build,
      act: (bloc) => bloc.add(const ProfileDeleteAccountConfirmed()),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(auth.deleteAccountCalled, isTrue);
        expect(bloc.state.isLoggedIn, isFalse);
        expect(bloc.state.signal, ProfileSignal.accountDeleted);
      },
    );

    blocTest<ProfileBloc, ProfileState>(
      '탈퇴가 실패하면 로그인 상태를 유지한다 — 지워지지 않았는데 지워진 척하면 안 된다',
      build: () {
        auth.throwOnDelete = Exception('서버 오류');
        return build();
      },
      seed: () => ProfileState(user: makeUser(), hasLoaded: true),
      act: (bloc) => bloc.add(const ProfileDeleteAccountConfirmed()),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.isLoggedIn, isTrue);
        expect(bloc.state.signal, ProfileSignal.deleteAccountFailed);
      },
    );

    blocTest<ProfileBloc, ProfileState>(
      '마지막 로그인 방식을 함께 읽어온다 — 설정 화면에 표시된다',
      build: () {
        SharedPreferences.setMockInitialValues({'lastLoginProvider': 'kakao'});
        return build();
      },
      act: (bloc) => bloc.add(const ProfileStarted()),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) => expect(bloc.state.loginProvider, AuthProvider.kakao),
    );
  });

  group('프로필 편집', () {
    late MockBadgeRepository badges;

    setUp(() {
      badges = MockBadgeRepository();
      when(() => badges.fetchMyBadges())
          .thenAnswer((_) async => [Badge.beginnerExplorer]);
      when(() => badges.setRepresentative(any())).thenAnswer((_) async {});
      when(() => badges.unsetRepresentative()).thenAnswer((_) async {});
    });

    ProfileEditBloc build({AppUser? user}) => ProfileEditBloc(
          authRepository: auth,
          badgeRepository: badges,
          user: user ?? makeUser(),
        );

    blocTest<ProfileEditBloc, ProfileEditState>(
      '바꾼 게 없으면 저장할 수 없다',
      build: build,
      verify: (bloc) => expect(bloc.state.canSave, isFalse),
    );

    blocTest<ProfileEditBloc, ProfileEditState>(
      '빈 닉네임은 저장할 수 없다',
      build: build,
      act: (bloc) => bloc.add(const ProfileEditNicknameChanged('   ')),
      verify: (bloc) => expect(bloc.state.canSave, isFalse),
    );

    blocTest<ProfileEditBloc, ProfileEditState>(
      '가지고 있지 않은 칭호는 고를 수 없다',
      build: build,
      act: (bloc) async {
        bloc.add(const ProfileEditStarted());
        await Future<void>.delayed(Duration.zero);
        // 보유 목록에 없는 칭호
        bloc.add(const ProfileEditBadgeSelected(Badge.sightingKing));
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) => expect(bloc.state.selectedBadge, isNull),
    );

    blocTest<ProfileEditBloc, ProfileEditState>(
      '닉네임만 바꾸면 칭호 쪽은 건드리지 않는다',
      build: build,
      act: (bloc) async {
        bloc.add(const ProfileEditNicknameChanged('새이름'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ProfileEditSaved());
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(auth.updatedNickname, '새이름');
        verifyNever(() => badges.setRepresentative(any()));
        verifyNever(() => badges.unsetRepresentative());
        expect(bloc.state.savedUser, isNotNull);
      },
    );

    blocTest<ProfileEditBloc, ProfileEditState>(
      '대표 칭호를 없애면 해제를 부른다',
      build: () => build(user: makeUser(badge: Badge.beginnerExplorer)),
      act: (bloc) async {
        bloc.add(const ProfileEditStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ProfileEditBadgeSelected(null));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ProfileEditSaved());
      },
      wait: const Duration(milliseconds: 50),
      verify: (_) {
        verify(() => badges.unsetRepresentative()).called(1);
        // 닉네임은 안 바뀌었으므로 부르지 않는다.
        expect(auth.updatedNickname, isNull);
      },
    );
  });
}
