import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:catmap_flutter/domain/models/app_user.dart';
import 'package:catmap_flutter/domain/models/cat_type.dart';
import 'package:catmap_flutter/domain/models/coordinate.dart';
import 'package:catmap_flutter/domain/models/sighting.dart';
import 'package:catmap_flutter/domain/repositories/auth_repository.dart';
import 'package:catmap_flutter/domain/repositories/location_repository.dart';
import 'package:catmap_flutter/domain/repositories/sighting_repository.dart';
import 'package:catmap_flutter/domain/repositories/storage_repository.dart';
import 'package:catmap_flutter/features/upload/bloc/upload_bloc.dart';
import 'package:catmap_flutter/features/upload/bloc/upload_event.dart';
import 'package:catmap_flutter/features/upload/bloc/upload_state.dart';
import 'package:catmap_flutter/features/upload/image_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSightingRepository extends Mock implements SightingRepository {}

class MockStorageRepository extends Mock implements StorageRepository {}

class FakeAuthRepository extends Fake implements AuthRepository {
  FakeAuthRepository(this.user);

  AppUser? user;

  @override
  Future<AppUser?> currentUser() async => user;
}

/// 위치 조회와 역지오코딩만 쓰는 가짜. 검색은 업로드 화면에서 부르지 않으므로
/// 구현하지 않는다 — 부르기 시작하면 테스트가 터져서 알려준다.
class FakeLocationRepository extends Fake implements LocationRepository {
  FakeLocationRepository({this.current, this.address = '서울특별시 마포구 서교동'});

  Coordinate? current;
  String address;

  @override
  Future<Coordinate> currentLocation() async {
    final value = current;
    if (value == null) throw Exception('위치 없음');
    return value;
  }

  @override
  Future<AdministrativeAddress> reverseGeocode(Coordinate coordinate) async {
    final parts = address.split(' ');
    return AdministrativeAddress(
      administrativeArea: parts.isNotEmpty ? parts[0] : null,
      locality: parts.length > 1 ? parts[1] : null,
      subLocality: parts.length > 2 ? parts[2] : null,
    );
  }
}

/// 사진을 실제로 건드리지 않는 가짜 가공기.
/// 진짜 압축은 플랫폼 채널이 필요해서 단위 테스트에서 돌릴 수 없다.
class FakeImageProcessor implements ImageProcessor {
  FakeImageProcessor({this.exifLocation, this.thumbnailFails = false});

  Coordinate? exifLocation;
  bool thumbnailFails;
  int compressCalls = 0;

  @override
  Future<Uint8List> compress(Uint8List bytes) async {
    compressCalls += 1;
    return bytes;
  }

  @override
  Future<Uint8List> thumbnail(Uint8List bytes) async {
    if (thumbnailFails) throw Exception('썸네일 실패');
    return bytes;
  }

  @override
  Future<Coordinate?> extractLocation(Uint8List bytes) async => exifLocation;
}

final photo1 = Uint8List.fromList([1, 2, 3]);
final photo2 = Uint8List.fromList([4, 5, 6]);
final photo3 = Uint8List.fromList([7, 8, 9]);
final photo4 = Uint8List.fromList([10, 11, 12]);

final me = AppUser(
  id: 'U1',
  email: 'me@example.com',
  createdAt: DateTime.utc(2026, 1, 1),
);

Sighting anySighting() => Sighting(
      id: 'S1',
      userId: 'U1',
      photoUrls: const ['https://example.com/a.jpg'],
      latitude: 37.5,
      longitude: 127,
      catType: CatType.stray,
      createdAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  // mocktail 의 any() 는 타입마다 "빈 값"을 알아야 한다. 기본형이 아닌 것은 미리 알려준다.
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(CatType.stray);
    registerFallbackValue(<String>[]);
  });

  late MockSightingRepository sightings;
  late MockStorageRepository storage;
  late FakeAuthRepository auth;
  late FakeLocationRepository location;
  late FakeImageProcessor images;

  setUp(() {
    sightings = MockSightingRepository();
    storage = MockStorageRepository();
    auth = FakeAuthRepository(me);
    location = FakeLocationRepository(
      current: const Coordinate(latitude: 37.5, longitude: 127),
    );
    images = FakeImageProcessor();

    when(() => storage.uploadPhoto(any(), any()))
        .thenAnswer((invocation) async =>
            'https://example.com/${invocation.positionalArguments[1]}');
    when(() => sightings.create(
          userId: any(named: 'userId'),
          photoUrls: any(named: 'photoUrls'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          catType: any(named: 'catType'),
          address: any(named: 'address'),
          memo: any(named: 'memo'),
        )).thenAnswer((_) async => anySighting());
  });

  UploadBloc build() => UploadBloc(
        authRepository: auth,
        locationRepository: location,
        sightingRepository: sightings,
        storageRepository: storage,
        imageProcessor: images,
      );

  group('사진 담기', () {
    blocTest<UploadBloc, UploadState>(
      '3장을 넘겨 찍으면 담지 않고 신호만 낸다',
      build: build,
      act: (bloc) => bloc
        ..add(UploadPhotoCaptured(photo1))
        ..add(UploadPhotoCaptured(photo2))
        ..add(UploadPhotoCaptured(photo3))
        ..add(UploadPhotoCaptured(photo4)),
      verify: (bloc) {
        expect(bloc.state.photos.length, 3);
        expect(bloc.state.signal, UploadSignal.photoLimitReached);
      },
    );

    blocTest<UploadBloc, UploadState>(
      '갤러리에서 남은 자리보다 많이 고르면 남은 만큼만 담는다',
      build: build,
      act: (bloc) => bloc
        ..add(UploadPhotoCaptured(photo1))
        ..add(UploadGalleryPhotosSelected([photo2, photo3, photo4])),
      verify: (bloc) => expect(bloc.state.photos, [photo1, photo2, photo3]),
    );

    blocTest<UploadBloc, UploadState>(
      '사진을 다 지우면 작성 단계에 남아 있지 않는다',
      build: build,
      seed: () => UploadState(photos: [photo1], step: UploadStep.memo),
      act: (bloc) => bloc.add(const UploadPhotoRemoved(0)),
      verify: (bloc) {
        expect(bloc.state.photos, isEmpty);
        expect(bloc.state.step, UploadStep.camera);
      },
    );
  });

  group('자르기', () {
    blocTest<UploadBloc, UploadState>(
      '마지막 장을 자르면 작성 단계로 넘어간다',
      build: build,
      seed: () => UploadState(photos: [photo1, photo2], step: UploadStep.crop),
      act: (bloc) => bloc
        ..add(UploadCropCompleted(0, photo3))
        ..add(UploadCropCompleted(1, photo4)),
      verify: (bloc) {
        expect(bloc.state.step, UploadStep.memo);
        expect(bloc.state.photos, [photo3, photo4]);
      },
    );

    blocTest<UploadBloc, UploadState>(
      '사진에 촬영 위치가 있으면 그 위치로 바꾸고 출처를 사진으로 표시한다',
      build: () {
        images.exifLocation = const Coordinate(latitude: 35.1, longitude: 129.0);
        return build();
      },
      seed: () => UploadState(photos: [photo1], step: UploadStep.crop),
      act: (bloc) => bloc.add(const UploadCropSkipped()),
      verify: (bloc) {
        expect(bloc.state.location,
            const Coordinate(latitude: 35.1, longitude: 129.0));
        expect(bloc.state.locationSource, UploadLocationSource.photo);
      },
    );
  });

  group('등록', () {
    blocTest<UploadBloc, UploadState>(
      '길냥이인데 위치가 없으면 등록하지 않는다',
      build: build,
      seed: () => UploadState(photos: [photo1], step: UploadStep.memo),
      act: (bloc) => bloc.add(const UploadSubmitted()),
      verify: (_) => verifyNever(() => sightings.create(
            userId: any(named: 'userId'),
            photoUrls: any(named: 'photoUrls'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            catType: any(named: 'catType'),
            address: any(named: 'address'),
            memo: any(named: 'memo'),
          )),
    );

    blocTest<UploadBloc, UploadState>(
      '집냥이는 위치를 붙이지 않는다 — 남의 집 위치가 지도에 찍히면 안 된다',
      build: build,
      seed: () => UploadState(
        photos: [photo1],
        step: UploadStep.memo,
        catType: CatType.domestic,
        location: const Coordinate(latitude: 37.5, longitude: 127),
        locationAddress: '서울특별시 마포구 서교동',
      ),
      act: (bloc) => bloc.add(const UploadSubmitted()),
      verify: (_) {
        final call = verify(() => sightings.create(
              userId: any(named: 'userId'),
              photoUrls: any(named: 'photoUrls'),
              latitude: captureAny(named: 'latitude'),
              longitude: captureAny(named: 'longitude'),
              catType: any(named: 'catType'),
              address: captureAny(named: 'address'),
              memo: any(named: 'memo'),
            ))
          ..called(1);
        expect(call.captured, [0.0, 0.0, null]);
      },
    );

    blocTest<UploadBloc, UploadState>(
      '썸네일이 실패해도 등록은 성공한다 — 원본만 있으면 화면은 그려진다',
      build: () {
        images.thumbnailFails = true;
        return build();
      },
      seed: () => UploadState(
        photos: [photo1],
        step: UploadStep.memo,
        location: const Coordinate(latitude: 37.5, longitude: 127),
      ),
      act: (bloc) => bloc.add(const UploadSubmitted()),
      verify: (bloc) {
        expect(bloc.state.isCompleted, isTrue);
        expect(bloc.state.signal, isNull);
      },
    );

    blocTest<UploadBloc, UploadState>(
      '등록 버튼을 연타해도 한 번만 올라간다',
      build: build,
      seed: () => UploadState(
        photos: [photo1],
        step: UploadStep.memo,
        location: const Coordinate(latitude: 37.5, longitude: 127),
      ),
      act: (bloc) => bloc
        ..add(const UploadSubmitted())
        ..add(const UploadSubmitted()),
      verify: (_) => verify(() => sightings.create(
            userId: any(named: 'userId'),
            photoUrls: any(named: 'photoUrls'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            catType: any(named: 'catType'),
            address: any(named: 'address'),
            memo: any(named: 'memo'),
          )).called(1),
    );

    blocTest<UploadBloc, UploadState>(
      '로그인이 풀렸으면 사진을 올리지 않는다',
      build: () {
        auth.user = null;
        return build();
      },
      seed: () => UploadState(
        photos: [photo1],
        step: UploadStep.memo,
        location: const Coordinate(latitude: 37.5, longitude: 127),
      ),
      act: (bloc) => bloc.add(const UploadSubmitted()),
      verify: (bloc) {
        expect(bloc.state.signal, UploadSignal.notLoggedIn);
        verifyNever(() => storage.uploadPhoto(any(), any()));
      },
    );
  });

  group('메모', () {
    blocTest<UploadBloc, UploadState>(
      '100자를 넘겨 입력하면 100자에서 자른다',
      build: build,
      act: (bloc) => bloc.add(UploadMemoChanged('가' * 150)),
      verify: (bloc) => expect(bloc.state.memo.length, 100),
    );
  });
}
