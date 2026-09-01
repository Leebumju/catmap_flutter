import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:exif/exif.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../domain/models/coordinate.dart';

/// 업로드 전 사진 가공. iOS 의 `ImageCompressor` 와 같은 규격을 쓴다.
///
/// - 원본: 긴 변 1024px, JPEG 품질 50 (장당 200~500KB 목표)
/// - 썸네일: 긴 변 200px, 품질 40 — 지도 팝업과 목록에서 쓴다
///
/// 규격이 갈라지면 같은 서버에 서로 다른 크기의 사진이 쌓인다.
class ImageProcessor {
  const ImageProcessor();

  static const maxDimension = 1024;
  static const quality = 50;
  static const thumbnailMaxDimension = 200;
  static const thumbnailQuality = 40;

  Future<Uint8List> compress(Uint8List bytes) =>
      _resizeAndEncode(bytes, maxDimension, quality);

  Future<Uint8List> thumbnail(Uint8List bytes) =>
      _resizeAndEncode(bytes, thumbnailMaxDimension, thumbnailQuality);

  /// 긴 변이 [maxSide] 가 되도록 줄이고 JPEG 로 인코딩한다.
  ///
  /// flutter_image_compress 의 minWidth/minHeight 는 이름과 달리 상한이고,
  /// 배율을 `min(w/minWidth, h/minHeight)` 로 잡는다 — 그대로 1024,1024 를 주면
  /// **짧은 변**이 1024 가 되어 iOS 보다 큰 이미지가 나온다.
  /// 그래서 원본 비율로 목표 크기를 직접 계산해서 넘긴다.
  Future<Uint8List> _resizeAndEncode(
    Uint8List bytes,
    int maxSide,
    int jpegQuality,
  ) async {
    final size = await _decodeSize(bytes);
    final (targetWidth, targetHeight) = _targetSize(size, maxSide);

    final result = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: targetWidth,
      minHeight: targetHeight,
      quality: jpegQuality,
      format: CompressFormat.jpeg,
      // EXIF 를 남기면 사진에 촬영 좌표가 그대로 붙어 서버로 올라간다.
      // iOS 도 재인코딩하면서 떨어뜨린다. 위치는 별도 필드로만 보낸다.
      keepExif: false,
    );
    return result;
  }

  /// 이미지를 다 풀지 않고 헤더만 읽어 크기를 얻는다.
  Future<(int width, int height)> _decodeSize(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final size = (descriptor.width, descriptor.height);
    descriptor.dispose();
    buffer.dispose();
    return size;
  }

  /// iOS 의 `resize(maxDimension:)` 과 같은 규칙 — 긴 변을 맞추고, 이미 작으면 그대로.
  (int, int) _targetSize((int, int) source, int maxSide) {
    final (width, height) = source;
    if (width <= maxSide && height <= maxSide) return source;

    final ratio = maxSide / (width > height ? width : height);
    final targetWidth = (width * ratio).round();
    final targetHeight = (height * ratio).round();
    // 0 이 되면 압축이 실패한다. 아주 길쭉한 사진에서만 나오는 경우다.
    return (targetWidth < 1 ? 1 : targetWidth, targetHeight < 1 ? 1 : targetHeight);
  }

  /// 사진에 박힌 촬영 위치(EXIF GPS). 없으면 null.
  ///
  /// **압축 전 원본에서** 뽑아야 한다. 압축하면 EXIF 가 날아간다.
  Future<Coordinate?> extractLocation(Uint8List bytes) async {
    final Map<String, IfdTag> tags;
    try {
      tags = await readExifFromBytes(bytes);
    } catch (_) {
      return null;
    }

    final latitude = _degrees(tags['GPS GPSLatitude']);
    final longitude = _degrees(tags['GPS GPSLongitude']);
    if (latitude == null || longitude == null) return null;

    // 남반구/서반구는 부호를 뒤집는다. iOS 도 같은 처리를 한다.
    final latRef = tags['GPS GPSLatitudeRef']?.printable.trim() ?? 'N';
    final lonRef = tags['GPS GPSLongitudeRef']?.printable.trim() ?? 'E';

    return Coordinate(
      latitude: latRef == 'S' ? -latitude : latitude,
      longitude: lonRef == 'W' ? -longitude : longitude,
    );
  }

  /// EXIF 의 GPS 는 도/분/초 세 개의 분수로 들어온다. 십진 도수로 바꾼다.
  double? _degrees(IfdTag? tag) {
    final values = tag?.values.toList();
    if (values == null || values.length < 3) return null;
    final parts = values.whereType<Ratio>().map((r) => r.toDouble()).toList();
    if (parts.length < 3) return null;
    return parts[0] + parts[1] / 60 + parts[2] / 3600;
  }
}
