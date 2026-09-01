import 'package:bloc_test/bloc_test.dart';
import 'package:catmap_flutter/domain/models/coordinate.dart';
import 'package:catmap_flutter/domain/models/nearby_place.dart';
import 'package:catmap_flutter/domain/models/shelter_animal.dart';
import 'package:catmap_flutter/domain/repositories/location_repository.dart';
import 'package:catmap_flutter/domain/repositories/nearby_repository.dart';
import 'package:catmap_flutter/features/nearby/bloc/nearby_place_bloc.dart';
import 'package:catmap_flutter/features/nearby/bloc/shelter_animal_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNearbyPlaceRepository extends Mock implements NearbyPlaceRepository {}

class MockShelterAnimalRepository extends Mock
    implements ShelterAnimalRepository {}

class FakeLocationRepository extends Fake implements LocationRepository {
  FakeLocationRepository({this.administrativeArea = '서울특별시'});

  String? administrativeArea;
  Object? throwOnLocation;

  @override
  Future<Coordinate> currentLocation() async {
    final error = throwOnLocation;
    if (error != null) throw error;
    return const Coordinate(latitude: 37.5, longitude: 127);
  }

  @override
  Future<AdministrativeAddress> reverseGeocode(Coordinate coordinate) async {
    return AdministrativeAddress(administrativeArea: administrativeArea);
  }
}

NearbyPlace makePlace(String id, {int distance = 100}) => NearbyPlace(
      id: id,
      name: '병원 $id',
      category: '동물병원',
      address: '서울 어딘가',
      roadAddress: '서울 어딘가 1',
      phone: '02-000-0000',
      distance: distance,
      latitude: 37.5,
      longitude: 127,
    );

ShelterAnimal makeAnimal(String id) => ShelterAnimal(
      id: id,
      kind: '한국 고양이',
      color: '치즈',
      age: '2025(년생)',
      weight: '3(Kg)',
      sex: ShelterAnimalSex.female,
      neuterYn: 'N',
      happenPlace: '서울시 어딘가',
      specialMark: '순함',
      processState: '보호중',
      shelterName: '보호소',
      shelterPhone: '02-111-1111',
      shelterAddress: '서울시',
      noticeStartDate: '20260101',
      noticeEndDate: '20261231',
    );

void main() {
  group('주변 장소', () {
    late MockNearbyPlaceRepository repository;

    setUp(() {
      repository = MockNearbyPlaceRepository();
      when(() => repository.search(
            query: any(named: 'query'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            radiusMeters: any(named: 'radiusMeters'),
            page: any(named: 'page'),
            size: any(named: 'size'),
          )).thenAnswer((_) async => NearbyPlaceResult(
            places: [makePlace('P1'), makePlace('P2')],
            isEnd: false,
            totalCount: 2,
          ));
    });

    NearbyPlaceBloc build() =>
        NearbyPlaceBloc(repository: repository, query: '동물병원');

    blocTest<NearbyPlaceBloc, NearbyPlaceState>(
      '기준 좌표가 정해지면 첫 페이지를 받는다',
      build: build,
      act: (bloc) => bloc.add(
        const NearbyPlaceLoadRequested(Coordinate(latitude: 37.5, longitude: 127)),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.places.length, 2);
        expect(bloc.state.hasLoadedInitial, isTrue);
      },
    );

    blocTest<NearbyPlaceBloc, NearbyPlaceState>(
      '페이지 경계에서 겹쳐 온 곳은 id 로 걸러낸다',
      build: build,
      act: (bloc) async {
        bloc.add(const NearbyPlaceLoadRequested(
            Coordinate(latitude: 37.5, longitude: 127)));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        // 두 번째 페이지가 같은 곳을 다시 준다
        bloc.add(const NearbyPlaceLoadMoreRequested());
      },
      wait: const Duration(milliseconds: 80),
      verify: (bloc) => expect(bloc.state.places.length, 2),
    );

    blocTest<NearbyPlaceBloc, NearbyPlaceState>(
      '조금만 움직였으면 재검색 버튼이 안 뜬다',
      build: build,
      seed: () => const NearbyPlaceState(
        query: '동물병원',
        coordinate: Coordinate(latitude: 37.5, longitude: 127),
      ),
      // 약 55m
      act: (bloc) => bloc.add(
        const NearbyPlaceMapMoved(Coordinate(latitude: 37.5005, longitude: 127)),
      ),
      verify: (bloc) => expect(bloc.state.showResearchButton, isFalse),
    );

    blocTest<NearbyPlaceBloc, NearbyPlaceState>(
      '200m 넘게 움직이면 재검색 버튼이 뜬다',
      build: build,
      seed: () => const NearbyPlaceState(
        query: '동물병원',
        coordinate: Coordinate(latitude: 37.5, longitude: 127),
      ),
      // 약 550m
      act: (bloc) => bloc.add(
        const NearbyPlaceMapMoved(Coordinate(latitude: 37.505, longitude: 127)),
      ),
      verify: (bloc) => expect(bloc.state.showResearchButton, isTrue),
    );

    blocTest<NearbyPlaceBloc, NearbyPlaceState>(
      '반경을 바꾸면 목록을 비우고 처음부터 다시 받는다',
      build: build,
      seed: () => NearbyPlaceState(
        query: '동물병원',
        coordinate: const Coordinate(latitude: 37.5, longitude: 127),
        places: [makePlace('OLD')],
      ),
      act: (bloc) => bloc.add(const NearbyPlaceRadiusChanged(5000)),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.radiusMeters, 5000);
        expect(bloc.state.places.map((p) => p.id), ['P1', 'P2']);
      },
    );
  });

  group('유기동물', () {
    late MockShelterAnimalRepository repository;
    late FakeLocationRepository location;

    setUp(() {
      repository = MockShelterAnimalRepository();
      location = FakeLocationRepository();
      when(() => repository.fetchSidoList()).thenAnswer((_) async => const [
            SidoCode(id: '6110000', name: '서울특별시'),
            SidoCode(id: '6260000', name: '부산광역시'),
          ]);
      when(() => repository.fetchSigunguList(any()))
          .thenAnswer((_) async => const [SigunguCode(id: '3220000', name: '강남구')]);
      when(() => repository.fetchAnimals(
            sidoCode: any(named: 'sidoCode'),
            sigunguCode: any(named: 'sigunguCode'),
            kind: any(named: 'kind'),
            page: any(named: 'page'),
            size: any(named: 'size'),
          )).thenAnswer((_) async =>
          ShelterAnimalResult(animals: [makeAnimal('A1')], totalCount: 1));
    });

    ShelterAnimalBloc build() => ShelterAnimalBloc(
          repository: repository,
          locationRepository: location,
        );

    blocTest<ShelterAnimalBloc, ShelterAnimalState>(
      '현재 위치의 시도를 자동으로 고른다',
      build: build,
      act: (bloc) => bloc.add(const ShelterAnimalStarted()),
      wait: const Duration(milliseconds: 100),
      verify: (bloc) {
        expect(bloc.state.selectedSido?.name, '서울특별시');
        expect(bloc.state.locationMappingFallback, isFalse);
        expect(bloc.state.animals.length, 1);
      },
    );

    blocTest<ShelterAnimalBloc, ShelterAnimalState>(
      '위치를 못 잡으면 서울로 시작하고 안내를 켠다 — 빈 화면으로 두지 않는다',
      build: () {
        location.throwOnLocation = Exception('권한 없음');
        return build();
      },
      act: (bloc) => bloc.add(const ShelterAnimalStarted()),
      wait: const Duration(milliseconds: 100),
      verify: (bloc) {
        expect(bloc.state.selectedSido, ShelterAnimalState.fallbackSido);
        expect(bloc.state.locationMappingFallback, isTrue);
      },
    );

    blocTest<ShelterAnimalBloc, ShelterAnimalState>(
      '시도 이름이 정확히 안 맞아도 이어 붙여 찾는다 ("서울" → "서울특별시")',
      build: () {
        location.administrativeArea = '서울';
        return build();
      },
      act: (bloc) => bloc.add(const ShelterAnimalStarted()),
      wait: const Duration(milliseconds: 100),
      verify: (bloc) {
        expect(bloc.state.selectedSido?.id, '6110000');
        expect(bloc.state.locationMappingFallback, isFalse);
      },
    );

    blocTest<ShelterAnimalBloc, ShelterAnimalState>(
      '시도를 직접 고르면 구 선택은 초기화된다',
      build: build,
      seed: () => const ShelterAnimalState(
        selectedSido: SidoCode(id: '6110000', name: '서울특별시'),
        selectedSigungu: SigunguCode(id: '3220000', name: '강남구'),
      ),
      act: (bloc) => bloc.add(
        const ShelterAnimalSidoSelected(SidoCode(id: '6260000', name: '부산광역시')),
      ),
      wait: const Duration(milliseconds: 100),
      verify: (bloc) {
        expect(bloc.state.selectedSido?.name, '부산광역시');
        expect(bloc.state.selectedSigungu, isNull);
        expect(bloc.state.manualRegionSelected, isTrue);
      },
    );

    test('한 페이지보다 적게 오면 마지막 장으로 본다', () async {
      when(() => repository.fetchAnimals(
            sidoCode: any(named: 'sidoCode'),
            sigunguCode: any(named: 'sigunguCode'),
            kind: any(named: 'kind'),
            page: any(named: 'page'),
            size: any(named: 'size'),
          )).thenAnswer((_) async =>
          ShelterAnimalResult(animals: [makeAnimal('A1')], totalCount: 1));

      final bloc = build();
      bloc.add(const ShelterAnimalStarted());
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(bloc.state.hasMorePages, isFalse);
      await bloc.close();
    });
  });

  group('공고 종료일 계산', () {
    test('종료일이 이틀 뒤면 D-2 를 붙인다', () {
      final days = ShelterAnimal.daysUntilEndFrom(
        '20260103',
        DateTime.utc(2026, 1, 1, 3), // 한국 시간 2026-01-01 12시
      );
      expect(days, 2);
    });

    test('한국 날짜로 센다 — 기기가 다른 시간대여도 같은 답이 나온다', () {
      // UTC 2025-12-31 20시 = 한국 2026-01-01 05시
      final days = ShelterAnimal.daysUntilEndFrom(
        '20260101',
        DateTime.utc(2025, 12, 31, 20),
      );
      expect(days, 0);
    });

    test('날짜 형식이 아니면 null 이다', () {
      expect(ShelterAnimal.daysUntilEndFrom('', DateTime.now()), isNull);
      expect(ShelterAnimal.daysUntilEndFrom('2026', DateTime.now()), isNull);
    });
  });
}
