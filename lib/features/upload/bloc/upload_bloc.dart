import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/review_prompt_storage.dart';
import '../../../domain/models/cat_type.dart';
import '../../../domain/models/coordinate.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/location_repository.dart';
import '../../../domain/repositories/sighting_repository.dart';
import '../../../domain/repositories/storage_repository.dart';
import '../image_processor.dart';
import 'upload_event.dart';
import 'upload_state.dart';

/// 사진 등록. iOS 의 `UploadFeature` 를 그대로 옮긴 것이다.
///
/// 순서도 같다: 촬영/선택 → 자르기 → 메모·종류·위치 → 등록.
class UploadBloc extends Bloc<UploadEvent, UploadState> {
  UploadBloc({
    required AuthRepository authRepository,
    required LocationRepository locationRepository,
    required SightingRepository sightingRepository,
    required StorageRepository storageRepository,
    ImageProcessor imageProcessor = const ImageProcessor(),
    ReviewPrompt reviewPrompt = const ReviewPrompt(),
  })  : _auth = authRepository,
        _location = locationRepository,
        _sightings = sightingRepository,
        _storage = storageRepository,
        _images = imageProcessor,
        _review = reviewPrompt,
        super(const UploadState()) {
    on<UploadStarted>(_onStarted);
    on<UploadFlashToggled>((e, emit) =>
        emit(state.copyWith(isFlashOn: !state.isFlashOn)));
    on<UploadCameraFlipped>((e, emit) =>
        emit(state.copyWith(isUsingFrontCamera: !state.isUsingFrontCamera)));
    on<UploadPhotoCaptured>(_onPhotoCaptured);
    on<UploadGalleryPhotosSelected>(_onGalleryPhotosSelected);
    on<UploadPhotoRemoved>(_onPhotoRemoved);
    on<UploadNextRequested>(_onNextRequested);
    on<UploadCropCompleted>(_onCropCompleted);
    on<UploadCropSkipped>(_onCropSkipped);
    on<UploadBackToCamera>((e, emit) =>
        emit(state.copyWith(step: UploadStep.camera)));
    on<UploadMemoChanged>(_onMemoChanged);
    on<UploadCatTypeChanged>((e, emit) =>
        emit(state.copyWith(catType: e.catType)));
    on<UploadAdjustLocationRequested>((e, emit) =>
        emit(state.copyWith(isLocationPickerOpen: true)));
    on<UploadLocationPickerDismissed>((e, emit) =>
        emit(state.copyWith(isLocationPickerOpen: false)));
    on<UploadLocationAdjusted>(_onLocationAdjusted);
    // 등록 버튼 연타로 같은 글이 두 번 올라가지 않게 막는다.
    on<UploadSubmitted>(_onSubmitted, transformer: droppable());
    on<UploadSignalConsumed>((e, emit) => emit(state.copyWith(clearSignal: true)));
  }

  final AuthRepository _auth;
  final LocationRepository _location;
  final SightingRepository _sightings;
  final StorageRepository _storage;
  final ImageProcessor _images;
  final ReviewPrompt _review;

  Future<void> _onStarted(UploadStarted event, Emitter<UploadState> emit) async {
    try {
      final coordinate = await _location.currentLocation();
      final address = await _describe(coordinate, fallback: '위치를 가져왔습니다');
      emit(state.copyWith(
        location: coordinate,
        locationAddress: address,
        locationSource: UploadLocationSource.current,
      ));
    } catch (_) {
      // 위치를 못 잡아도 화면은 그대로 쓴다. 등록 직전에 다시 막는다.
    }
  }

  void _onPhotoCaptured(UploadPhotoCaptured event, Emitter<UploadState> emit) {
    if (!state.canTakeMore) {
      emit(state.copyWith(signal: UploadSignal.photoLimitReached));
      return;
    }
    emit(state.copyWith(photos: [...state.photos, event.bytes]));
  }

  void _onGalleryPhotosSelected(
    UploadGalleryPhotosSelected event,
    Emitter<UploadState> emit,
  ) {
    final remaining = UploadState.maxPhotos - state.photos.length;
    if (remaining <= 0) {
      emit(state.copyWith(signal: UploadSignal.photoLimitReached));
      return;
    }
    // 3장을 넘겨 고르면 앞에서부터 채우고 나머지는 버린다. iOS 와 같다.
    emit(state.copyWith(
      photos: [...state.photos, ...event.photos.take(remaining)],
    ));
  }

  void _onPhotoRemoved(UploadPhotoRemoved event, Emitter<UploadState> emit) {
    if (event.index < 0 || event.index >= state.photos.length) return;
    final photos = [...state.photos]..removeAt(event.index);
    emit(state.copyWith(
      photos: photos,
      // 사진이 하나도 없으면 메모 단계에 있을 수 없다.
      step: photos.isEmpty ? UploadStep.camera : state.step,
    ));
  }

  void _onNextRequested(UploadNextRequested event, Emitter<UploadState> emit) {
    if (state.photos.isEmpty) return;
    emit(state.copyWith(step: UploadStep.crop, cropPhotoIndex: 0));
  }

  Future<void> _onCropCompleted(
    UploadCropCompleted event,
    Emitter<UploadState> emit,
  ) async {
    if (event.index < 0 || event.index >= state.photos.length) return;
    final photos = [...state.photos];
    photos[event.index] = event.bytes;
    emit(state.copyWith(photos: photos));
    await _advanceAfterCrop(event.index, emit);
  }

  Future<void> _onCropSkipped(
    UploadCropSkipped event,
    Emitter<UploadState> emit,
  ) async {
    await _advanceAfterCrop(state.cropPhotoIndex, emit);
  }

  /// 자르기를 마친 사진 다음으로 넘어간다. 마지막 장이면 메모 단계로 가면서
  /// 첫 사진의 EXIF 위치를 읽어 본다 — iOS 와 같은 자리, 같은 순서다.
  Future<void> _advanceAfterCrop(int index, Emitter<UploadState> emit) async {
    final next = index + 1;
    if (next < state.photos.length) {
      emit(state.copyWith(cropPhotoIndex: next));
      return;
    }

    emit(state.copyWith(step: UploadStep.memo));

    final first = state.photos.firstOrNull;
    if (first == null) return;
    final exifCoordinate = await _images.extractLocation(first);
    if (exifCoordinate == null) return;

    final address = await _describe(exifCoordinate, fallback: '사진 촬영 위치');
    emit(state.copyWith(
      location: exifCoordinate,
      locationAddress: address,
      locationSource: UploadLocationSource.photo,
    ));
  }

  void _onMemoChanged(UploadMemoChanged event, Emitter<UploadState> emit) {
    final memo = event.memo.length > UploadState.memoMaxLength
        ? event.memo.substring(0, UploadState.memoMaxLength)
        : event.memo;
    emit(state.copyWith(memo: memo));
  }

  Future<void> _onLocationAdjusted(
    UploadLocationAdjusted event,
    Emitter<UploadState> emit,
  ) async {
    emit(state.copyWith(
      location: event.coordinate,
      locationSource: UploadLocationSource.manual,
      isLocationPickerOpen: false,
    ));
    final address = await _describe(event.coordinate, fallback: '선택한 위치');
    emit(state.copyWith(locationAddress: address));
  }

  Future<void> _onSubmitted(
    UploadSubmitted event,
    Emitter<UploadState> emit,
  ) async {
    if (!state.canSubmit) return;

    emit(state.copyWith(isUploading: true, clearSignal: true));

    final user = await _auth.currentUser();
    if (user == null) {
      emit(state.copyWith(isUploading: false, signal: UploadSignal.notLoggedIn));
      return;
    }

    // 집냥이는 위치를 붙이지 않는다. iOS 와 같다 — 남의 집 위치가 지도에 찍히면 안 된다.
    final isStray = state.catType == CatType.stray;
    final coordinate = isStray ? state.location : null;
    final address = isStray ? state.locationAddress : '';

    try {
      final photoUrls = await _uploadPhotos(user.id);
      await _sightings.create(
        userId: user.id,
        photoUrls: photoUrls,
        latitude: coordinate?.latitude ?? 0,
        longitude: coordinate?.longitude ?? 0,
        catType: state.catType,
        address: address.isEmpty ? null : address,
        memo: state.memo.isEmpty ? null : state.memo,
      );
      emit(state.copyWith(isUploading: false, isCompleted: true));

      // 올리기를 마친 자리에서 센다. iOS 도 여기서 세고 조건이 되면 물어본다.
      // 이 호출이 실패해도 등록은 이미 끝났다. 실패로 보이게 하면 안 되므로
      // 바깥 try 에 섞지 않고 따로 감싼다.
      try {
        await _review.trackUpload();
        await _review.requestIfNeeded();
      } catch (_) {
        // 리뷰 요청은 없어도 되는 기능이다.
      }
    } catch (_) {
      emit(state.copyWith(isUploading: false, signal: UploadSignal.uploadFailed));
    }
  }

  /// 사진을 압축해 올리고 공개 URL 목록을 돌려준다.
  ///
  /// 썸네일은 원본 옆에 `_thumb` 이름으로 같이 올린다. 목록 화면이 이 규칙으로
  /// 경로를 유추하기 때문에 이름을 바꾸면 썸네일이 안 뜬다.
  /// 썸네일 실패는 무시한다 — 원본이 있으면 화면은 그려진다(iOS 와 같다).
  Future<List<String>> _uploadPhotos(String userId) async {
    final urls = <String>[];
    for (var index = 0; index < state.photos.length; index++) {
      final original = state.photos[index];
      final compressed = await _images.compress(original);

      final fileId = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
      final path = '$userId/${fileId}_$index.jpg';
      final thumbPath = '$userId/${fileId}_${index}_thumb.jpg';

      final url = await _storage.uploadPhoto(compressed, path);
      urls.add(url);

      try {
        final thumb = await _images.thumbnail(original);
        await _storage.uploadPhoto(thumb, thumbPath);
      } catch (_) {
        // 썸네일은 없어도 된다.
      }
    }
    return urls;
  }

  /// 좌표를 화면에 쓸 주소 문자열로. 실패하면 [fallback] 을 쓴다.
  Future<String> _describe(Coordinate coordinate, {required String fallback}) async {
    try {
      final address = await _location.reverseGeocode(coordinate);
      return address.display;
    } catch (_) {
      return fallback;
    }
  }
}
