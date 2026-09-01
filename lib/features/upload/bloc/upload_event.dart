import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../../domain/models/cat_type.dart';
import '../../../domain/models/coordinate.dart';

sealed class UploadEvent extends Equatable {
  const UploadEvent();

  @override
  List<Object?> get props => [];
}

/// 화면 진입 — 현재 위치를 먼저 잡아 둔다. 실패해도 그냥 넘어간다(iOS 와 같다).
final class UploadStarted extends UploadEvent {
  const UploadStarted();
}

final class UploadFlashToggled extends UploadEvent {
  const UploadFlashToggled();
}

final class UploadCameraFlipped extends UploadEvent {
  const UploadCameraFlipped();
}

final class UploadPhotoCaptured extends UploadEvent {
  const UploadPhotoCaptured(this.bytes);

  final Uint8List bytes;

  @override
  List<Object?> get props => [bytes];
}

final class UploadGalleryPhotosSelected extends UploadEvent {
  const UploadGalleryPhotosSelected(this.photos);

  final List<Uint8List> photos;

  @override
  List<Object?> get props => [photos];
}

final class UploadPhotoRemoved extends UploadEvent {
  const UploadPhotoRemoved(this.index);

  final int index;

  @override
  List<Object?> get props => [index];
}

/// 촬영을 마치고 다음 단계(사진 자르기)로.
final class UploadNextRequested extends UploadEvent {
  const UploadNextRequested();
}

final class UploadCropCompleted extends UploadEvent {
  const UploadCropCompleted(this.index, this.bytes);

  final int index;
  final Uint8List bytes;

  @override
  List<Object?> get props => [index, bytes];
}

final class UploadCropSkipped extends UploadEvent {
  const UploadCropSkipped();
}

final class UploadBackToCamera extends UploadEvent {
  const UploadBackToCamera();
}

final class UploadMemoChanged extends UploadEvent {
  const UploadMemoChanged(this.memo);

  final String memo;

  @override
  List<Object?> get props => [memo];
}

final class UploadCatTypeChanged extends UploadEvent {
  const UploadCatTypeChanged(this.catType);

  final CatType catType;

  @override
  List<Object?> get props => [catType];
}

final class UploadAdjustLocationRequested extends UploadEvent {
  const UploadAdjustLocationRequested();
}

final class UploadLocationPickerDismissed extends UploadEvent {
  const UploadLocationPickerDismissed();
}

final class UploadLocationAdjusted extends UploadEvent {
  const UploadLocationAdjusted(this.coordinate);

  final Coordinate coordinate;

  @override
  List<Object?> get props => [coordinate];
}

final class UploadSubmitted extends UploadEvent {
  const UploadSubmitted();
}

final class UploadSignalConsumed extends UploadEvent {
  const UploadSignalConsumed();
}
