import 'package:bloc_test/bloc_test.dart';
import 'package:catmap_flutter/domain/models/cat_type.dart';
import 'package:catmap_flutter/domain/models/coordinate.dart';
import 'package:catmap_flutter/domain/models/sighting.dart';
import 'package:catmap_flutter/domain/models/app_user.dart';
import 'package:catmap_flutter/domain/models/badge.dart';
import 'package:catmap_flutter/domain/models/earned_badge.dart';
import 'package:catmap_flutter/domain/repositories/auth_repository.dart';
import 'package:catmap_flutter/domain/repositories/location_repository.dart';
import 'package:catmap_flutter/domain/repositories/profile_repository.dart';
import 'package:catmap_flutter/domain/repositories/sighting_repository.dart';
import 'package:catmap_flutter/features/map/bloc/map_bloc.dart';
import 'package:catmap_flutter/features/map/bloc/map_event.dart';
import 'package:catmap_flutter/features/map/bloc/map_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSightingRepository extends Mock implements SightingRepository {}

class FakeAuthRepository extends Fake implements AuthRepository {
  FakeAuthRepository(this.user);

  AppUser? user;

  @override
  Future<AppUser?> currentUser() async => user;
}

/// 칭호 확인에 필요한 것만 가진 가짜.
class FakeBadgeRepository extends Fake implements BadgeRepository {
  FakeBadgeRepository({this.earned = const [], this.lastSeen});

  List<EarnedBadge> earned;
  DateTime? lastSeen;
  DateTime? savedLastSeen;

  @override
  Future<bool> checkHongGilDong() async => false;

  @override
  Future<List<EarnedBadge>> fetchMyEarnedBadges() async => earned;

  @override
  Future<DateTime?> lastSeenBadgeAt() async => lastSeen;

  @override
  Future<void> setLastSeenBadgeAt(DateTime timestamp) async {
    savedLastSeen = timestamp;
  }
}

class FakeLocationRepository extends Fake implements LocationRepository {
  FakeLocationRepository({
    this.permission = LocationPermissionStatus.authorized,
    this.current = const Coordinate(latitude: 37.5, longitude: 127),
  });

  LocationPermissionStatus permission;
  Coordinate current;

  @override
  Future<LocationPermissionStatus> requestPermission() async => permission;

  @override
  Future<Coordinate> currentLocation() async => current;
}

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
  late MockSightingRepository sightings;
  late FakeLocationRepository location;
  late FakeAuthRepository auth;
  late FakeBadgeRepository badges;

  setUp(() {
    sightings = MockSightingRepository();
    location = FakeLocationRepository();
    auth = FakeAuthRepository(AppUser(
      id: 'U1',
      email: 'me@example.com',
      createdAt: DateTime.utc(2026, 1, 1),
    ));
    badges = FakeBadgeRepository();
    when(() => sightings.fetchNearby(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          radiusMeters: any(named: 'radiusMeters'),
        )).thenAnswer((_) async => [makeSighting('S1')]);
  });

  MapBloc build() => MapBloc(
        locationRepository: location,
        sightingRepository: sightings,
        authRepository: auth,
        badgeRepository: badges,
      );

  blocTest<MapBloc, MapPageState>(
    '위치 권한이 없으면 조회하지 않는다',
    build: () {
      location.permission = LocationPermissionStatus.denied;
      return build();
    },
    act: (bloc) => bloc.add(const MapStarted()),
    verify: (bloc) {
      expect(bloc.state.signal, MapSignal.locationDenied);
      verifyNever(() => sightings.fetchNearby(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            radiusMeters: any(named: 'radiusMeters'),
          ));
    },
  );

  blocTest<MapBloc, MapPageState>(
    '조금 움직인 것으로는 재검색 버튼이 뜨지 않는다',
    build: build,
    seed: () => const MapPageState(
      mapCenter: Coordinate(latitude: 37.5, longitude: 127),
    ),
    // 0.0005 + 0 = 임계값 0.002 미만
    act: (bloc) =>
        bloc.add(const MapMoved(Coordinate(latitude: 37.5005, longitude: 127))),
    verify: (bloc) => expect(bloc.state.showResearchButton, isFalse),
  );

  blocTest<MapBloc, MapPageState>(
    '200m 넘게 움직이면 재검색 버튼이 뜬다',
    build: build,
    seed: () => const MapPageState(
      mapCenter: Coordinate(latitude: 37.5, longitude: 127),
    ),
    act: (bloc) =>
        bloc.add(const MapMoved(Coordinate(latitude: 37.505, longitude: 127))),
    verify: (bloc) => expect(bloc.state.showResearchButton, isTrue),
  );

  blocTest<MapBloc, MapPageState>(
    '재검색을 연달아 눌러도 2초 안에는 한 번만 조회한다',
    build: build,
    seed: () => const MapPageState(
      mapCenter: Coordinate(latitude: 37.5, longitude: 127),
    ),
    act: (bloc) => bloc
      ..add(const MapResearchHereRequested())
      ..add(const MapResearchHereRequested()),
    wait: const Duration(milliseconds: 50),
    verify: (_) => verify(() => sightings.fetchNearby(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          radiusMeters: any(named: 'radiusMeters'),
        )).called(1),
  );

  blocTest<MapBloc, MapPageState>(
    '조회에 실패해도 이미 찍혀 있던 마커는 지우지 않는다',
    build: () {
      when(() => sightings.fetchNearby(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            radiusMeters: any(named: 'radiusMeters'),
          )).thenThrow(Exception('네트워크'));
      return build();
    },
    seed: () => MapPageState(
      mapCenter: const Coordinate(latitude: 37.5, longitude: 127),
      sightings: [makeSighting('S1')],
    ),
    act: (bloc) => bloc.add(const MapResearchHereRequested()),
    verify: (bloc) {
      expect(bloc.state.sightings.length, 1);
      expect(bloc.state.signal, MapSignal.loadFailed);
    },
  );

  blocTest<MapBloc, MapPageState>(
    '업로드가 끝나면 쓰로틀과 무관하게 다시 조회한다 — 방금 올린 글이 바로 보여야 한다',
    build: build,
    seed: () => const MapPageState(
      mapCenter: Coordinate(latitude: 37.5, longitude: 127),
    ),
    act: (bloc) => bloc
      ..add(const MapResearchHereRequested())
      ..add(const MapUploadCompleted()),
    wait: const Duration(milliseconds: 50),
    verify: (_) => verify(() => sightings.fetchNearby(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          radiusMeters: any(named: 'radiusMeters'),
        )).called(2),
  );

  group('겹친 마커 흩기', () {
    test('같은 자리의 두 번째 글부터는 조금씩 밀어 놓는다', () {
      final placed = spreadOverlappingMarkers([
        makeSighting('S1'),
        makeSighting('S2'),
      ]);

      expect(placed[0].coordinate.latitude, 37.5);
      expect(placed[0].coordinate.longitude, 127);
      // 두 번째는 같은 자리에 겹치지 않는다.
      expect(placed[1].coordinate, isNot(placed[0].coordinate));
    });

    test('자리가 다르면 좌표를 건드리지 않는다', () {
      final other = Sighting(
        id: 'S2',
        userId: 'U1',
        photoUrls: const [],
        latitude: 37.6,
        longitude: 127.1,
        catType: CatType.stray,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final placed = spreadOverlappingMarkers([makeSighting('S1'), other]);

      expect(placed[1].coordinate.latitude, 37.6);
      expect(placed[1].coordinate.longitude, 127.1);
    });
  });

  group('칭호 확인', () {
    blocTest<MapBloc, MapPageState>(
      '마지막으로 본 시각 이후에 딴 칭호만 새 것으로 본다',
      build: () {
        badges
          ..lastSeen = DateTime.utc(2026, 1, 10)
          ..earned = [
            EarnedBadge(
              badge: Badge.beginnerExplorer,
              earnedAt: DateTime.utc(2026, 1, 5),
            ),
            EarnedBadge(
              badge: Badge.popularStar,
              earnedAt: DateTime.utc(2026, 1, 15),
            ),
          ];
        return build();
      },
      act: (bloc) => bloc.add(const MapBadgesChecked()),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.unlockedBadges.length, 1);
        expect(bloc.state.unlockedBadges.first.badge, Badge.popularStar);
      },
    );

    blocTest<MapBloc, MapPageState>(
      '한 번도 본 적 없으면 가진 칭호 전부가 새 것이다',
      build: () {
        badges
          ..lastSeen = null
          ..earned = [
            EarnedBadge(
              badge: Badge.beginnerExplorer,
              earnedAt: DateTime.utc(2026, 1, 5),
            ),
          ];
        return build();
      },
      act: (bloc) => bloc.add(const MapBadgesChecked()),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) => expect(bloc.state.unlockedBadges.length, 1),
    );

    blocTest<MapBloc, MapPageState>(
      '비로그인이면 칭호를 조회하지 않는다',
      build: () {
        auth.user = null;
        badges.earned = [
          EarnedBadge(
            badge: Badge.beginnerExplorer,
            earnedAt: DateTime.utc(2026, 1, 5),
          ),
        ];
        return build();
      },
      act: (bloc) => bloc.add(const MapBadgesChecked()),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) => expect(bloc.state.unlockedBadges, isEmpty),
    );

    blocTest<MapBloc, MapPageState>(
      '한 세션에서 두 번 확인하지 않는다',
      build: () {
        badges.earned = [
          EarnedBadge(
            badge: Badge.beginnerExplorer,
            earnedAt: DateTime.utc(2026, 1, 5),
          ),
        ];
        return build();
      },
      act: (bloc) async {
        bloc.add(const MapBadgesChecked());
        await Future<void>.delayed(const Duration(milliseconds: 30));
        bloc.add(const MapBadgeModalDismissed());
        await Future<void>.delayed(const Duration(milliseconds: 30));
        bloc.add(const MapBadgesChecked());
      },
      wait: const Duration(milliseconds: 120),
      verify: (bloc) => expect(bloc.state.unlockedBadges, isEmpty),
    );

    blocTest<MapBloc, MapPageState>(
      '창을 닫으면 가장 늦게 딴 시각을 서버에 남긴다',
      build: () {
        badges.earned = [
          EarnedBadge(
            badge: Badge.beginnerExplorer,
            earnedAt: DateTime.utc(2026, 1, 5),
          ),
          EarnedBadge(
            badge: Badge.popularStar,
            earnedAt: DateTime.utc(2026, 1, 20),
          ),
        ];
        return build();
      },
      act: (bloc) async {
        bloc.add(const MapBadgesChecked());
        await Future<void>.delayed(const Duration(milliseconds: 30));
        bloc.add(const MapBadgeModalDismissed());
      },
      wait: const Duration(milliseconds: 100),
      verify: (_) => expect(badges.savedLastSeen, DateTime.utc(2026, 1, 20)),
    );
  });
}
