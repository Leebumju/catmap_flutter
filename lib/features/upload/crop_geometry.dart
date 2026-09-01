import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// 사진을 정사각형으로 자르는 데 필요한 좌표 계산.
///
/// iOS 는 UIScrollView 의 zoomScale·contentOffset 으로 보이는 영역을 구했다.
/// Flutter 는 InteractiveViewer 의 변환 행렬을 뒤집어서 같은 값을 얻는다.
/// 계산만 떼어 둔 이유는 화면 없이 검사할 수 있게 하기 위함이다.
class CropGeometry {
  const CropGeometry._();

  /// 정사각형 크롭 창 안에 사진이 꽉 차도록(cover) 배치할 때의 사진 표시 크기.
  ///
  /// iOS 의 layoutCrop 과 같은 규칙 — 가로 사진은 높이를, 세로 사진은 너비를
  /// 크롭 창에 맞춘다. 그래야 어느 방향으로 움직여도 빈틈이 안 생긴다.
  static Size fittedSize({required Size source, required double cropSide}) {
    if (source.width <= 0 || source.height <= 0) {
      return Size(cropSide, cropSide);
    }
    final aspect = source.width / source.height;
    if (aspect > 1) {
      return Size(cropSide * aspect, cropSide);
    }
    return Size(cropSide, cropSide / aspect);
  }

  /// 처음 보여줄 변환. 사진의 가운데가 크롭 창에 오도록 밀어 놓는다.
  ///
  /// iOS 는 contentOffset 을 (fitWidth - cropSize)/2 로 잡아 가운데에서 시작한다.
  /// 이걸 안 하면 가로 사진이 왼쪽 끝부터 보여서, 가운데를 쓰려면 매번 끌어야 한다.
  static Matrix4 initialTransform({
    required Size fitted,
    required double cropSide,
  }) {
    final dx = -(fitted.width - cropSide) / 2;
    final dy = -(fitted.height - cropSide) / 2;
    return Matrix4.identity()..translateByDouble(dx, dy, 0, 1);
  }

  /// 크롭 창에 지금 보이는 부분을 **원본 사진의 픽셀 좌표**로 돌려준다.
  ///
  /// [transform] 은 InteractiveViewer 가 자식에 적용한 행렬이다.
  /// 결과는 원본 경계 안으로 자른다 — 밖으로 나간 값을 그대로 쓰면 크롭이 터진다.
  static Rect visibleSourceRect({
    required Matrix4 transform,
    required Size source,
    required Size fitted,
    required double cropSide,
  }) {
    final inverse = Matrix4.inverted(transform);

    // 크롭 창의 두 꼭짓점을 자식 좌표계로 되돌린다.
    final topLeft = MatrixUtils.transformPoint(inverse, Offset.zero);
    final bottomRight =
        MatrixUtils.transformPoint(inverse, Offset(cropSide, cropSide));

    final scaleX = source.width / fitted.width;
    final scaleY = source.height / fitted.height;

    final left = topLeft.dx * scaleX;
    final top = topLeft.dy * scaleY;
    final right = bottomRight.dx * scaleX;
    final bottom = bottomRight.dy * scaleY;

    final clampedLeft = left.clamp(0.0, source.width);
    final clampedTop = top.clamp(0.0, source.height);
    final clampedRight = right.clamp(0.0, source.width);
    final clampedBottom = bottom.clamp(0.0, source.height);

    // 폭이나 높이가 0 이 되면(계산이 어긋난 경우) 원본 전체를 쓴다.
    if (clampedRight - clampedLeft < 1 || clampedBottom - clampedTop < 1) {
      return Rect.fromLTWH(0, 0, source.width, source.height);
    }
    return Rect.fromLTRB(clampedLeft, clampedTop, clampedRight, clampedBottom);
  }
}

/// 사진 바이트를 [sourceRect] 만큼 잘라 PNG 바이트로 돌려준다.
///
/// JPEG 로 바로 인코딩하지 않는 이유: Flutter 기본 API 는 JPEG 인코딩을 못 한다.
/// 어차피 업로드 직전에 [ImageProcessor] 가 1024px JPEG 로 다시 인코딩하므로,
/// 중간 단계는 무손실인 PNG 로 두는 편이 화질에 낫다.
Future<Uint8List> cropImageBytes(Uint8List bytes, Rect sourceRect) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;

  final width = sourceRect.width.round();
  final height = sourceRect.height.round();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImageRect(
    image,
    sourceRect,
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..filterQuality = FilterQuality.high,
  );
  final picture = recorder.endRecording();
  final cropped = await picture.toImage(math.max(1, width), math.max(1, height));
  final data = await cropped.toByteData(format: ui.ImageByteFormat.png);

  image.dispose();
  picture.dispose();
  cropped.dispose();
  codec.dispose();

  return data!.buffer.asUint8List();
}
