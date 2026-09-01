import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../../domain/models/cat_type.dart';
import '../../../domain/models/coordinate.dart';

/// 위치를 무엇으로 정했는지. iOS 의 `LocationSource` 와 같다.
enum UploadLocationSource {
  /// 사진에 박힌 촬영 위치(EXIF)
  photo,

  /// 지금 내 위치
  current,

  /// 지도에서 직접 찍은 위치
  manual,
}

/// 업로드 화면이 지금 어느 단계인지. iOS 는 showCropScreen / showMemoScreen
/// 두 플래그로 표현했는데, 셋 중 하나라는 게 분명하도록 하나로 합쳤다.
/// (플래그 두 개면 "둘 다 true" 라는 있을 수 없는 상태가 표현된다.)
enum UploadStep { camera, crop, memo }

/// 화면이 한 번만 반응해야 하는 신호.
enum UploadSignal {
  /// 사진은 3장까지
  photoLimitReached,

  /// 로그인이 풀렸다
  notLoggedIn,

  uploadFailed,
}

class UploadState extends Equatable {
  const UploadState({
    this.photos = const [],
    this.step = UploadStep.camera,
    this.cropPhotoIndex = 0,
    this.isFlashOn = false,
    this.isUsingFrontCamera = false,
    this.memo = '',
    this.catType = CatType.stray,
    this.location,
    this.locationAddress = '',
    this.locationSource = UploadLocationSource.current,
    this.isLocationPickerOpen = false,
    this.isUploading = false,
    this.isCompleted = false,
    this.signal,
  });

  /// 사진은 최대 3장. iOS 와 같은 상한이다.
  static const maxPhotos = 3;

  /// 메모는 100자까지.
  static const memoMaxLength = 100;

  final List<Uint8List> photos;
  final UploadStep step;
  final int cropPhotoIndex;
  final bool isFlashOn;
  final bool isUsingFrontCamera;
  final String memo;
  final CatType catType;
  final Coordinate? location;
  final String locationAddress;
  final UploadLocationSource locationSource;
  final bool isLocationPickerOpen;
  final bool isUploading;

  /// 업로드가 끝났다. 화면은 이걸 보고 닫는다.
  final bool isCompleted;

  final UploadSignal? signal;

  int get photoCount => photos.length;

  bool get canTakeMore => photos.length < maxPhotos;

  /// 등록 버튼을 누를 수 있는 조건. iOS 의 submitTapped 가드와 같다 —
  /// 길냥이는 위치가 반드시 있어야 하고, 집냥이는 위치 없이도 올릴 수 있다.
  bool get canSubmit {
    if (photos.isEmpty) return false;
    if (catType == CatType.stray && location == null) return false;
    return !isUploading;
  }

  UploadState copyWith({
    List<Uint8List>? photos,
    UploadStep? step,
    int? cropPhotoIndex,
    bool? isFlashOn,
    bool? isUsingFrontCamera,
    String? memo,
    CatType? catType,
    Coordinate? location,
    String? locationAddress,
    UploadLocationSource? locationSource,
    bool? isLocationPickerOpen,
    bool? isUploading,
    bool? isCompleted,
    UploadSignal? signal,
    bool clearSignal = false,
  }) {
    return UploadState(
      photos: photos ?? this.photos,
      step: step ?? this.step,
      cropPhotoIndex: cropPhotoIndex ?? this.cropPhotoIndex,
      isFlashOn: isFlashOn ?? this.isFlashOn,
      isUsingFrontCamera: isUsingFrontCamera ?? this.isUsingFrontCamera,
      memo: memo ?? this.memo,
      catType: catType ?? this.catType,
      location: location ?? this.location,
      locationAddress: locationAddress ?? this.locationAddress,
      locationSource: locationSource ?? this.locationSource,
      isLocationPickerOpen: isLocationPickerOpen ?? this.isLocationPickerOpen,
      isUploading: isUploading ?? this.isUploading,
      isCompleted: isCompleted ?? this.isCompleted,
      signal: clearSignal ? null : (signal ?? this.signal),
    );
  }

  @override
  List<Object?> get props => [
        photos,
        step,
        cropPhotoIndex,
        isFlashOn,
        isUsingFrontCamera,
        memo,
        catType,
        location,
        locationAddress,
        locationSource,
        isLocationPickerOpen,
        isUploading,
        isCompleted,
        signal,
      ];
}
