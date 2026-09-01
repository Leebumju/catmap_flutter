import 'package:catmap_flutter/features/upload/crop_geometry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('크롭 창에 사진 맞추기', () {
    test('가로 사진은 높이를 창에 맞춘다 — 좌우로 움직일 여유가 생긴다', () {
      final fitted = CropGeometry.fittedSize(
        source: const Size(4000, 2000),
        cropSide: 300,
      );

      expect(fitted.height, 300);
      expect(fitted.width, 600);
    });

    test('세로 사진은 너비를 창에 맞춘다', () {
      final fitted = CropGeometry.fittedSize(
        source: const Size(2000, 4000),
        cropSide: 300,
      );

      expect(fitted.width, 300);
      expect(fitted.height, 600);
    });

    test('크기를 못 읽은 사진은 정사각형으로 둔다 — 0으로 나누지 않는다', () {
      final fitted = CropGeometry.fittedSize(
        source: const Size(0, 0),
        cropSide: 300,
      );

      expect(fitted, const Size(300, 300));
    });
  });

  group('처음 보여줄 자리', () {
    test('가로 사진은 가운데가 창에 오도록 밀어 놓는다 — iOS 도 가운데에서 시작한다', () {
      final transform = CropGeometry.initialTransform(
        fitted: const Size(600, 300),
        cropSide: 300,
      );

      final rect = CropGeometry.visibleSourceRect(
        transform: transform,
        source: const Size(4000, 2000),
        fitted: const Size(600, 300),
        cropSide: 300,
      );

      // 원본 4000 폭에서 가운데 2000 폭(1000~3000)이 잡힌다.
      expect(rect.left, 1000);
      expect(rect.right, 3000);
    });
  });

  group('보이는 영역을 원본 좌표로 옮기기', () {
    test('움직이지 않았으면 가로 사진의 가운데가 아니라 왼쪽 끝부터 잡힌다', () {
      // 4000x2000 사진을 300 창에 맞추면 600x300 으로 놓인다.
      // 변환이 없으면 창에는 왼쪽 300(=원본 2000px)만 보인다.
      final rect = CropGeometry.visibleSourceRect(
        transform: Matrix4.identity(),
        source: const Size(4000, 2000),
        fitted: const Size(600, 300),
        cropSide: 300,
      );

      expect(rect.left, 0);
      expect(rect.top, 0);
      expect(rect.width, 2000);
      expect(rect.height, 2000);
    });

    test('두 배로 확대하면 원본에서 잡히는 영역이 절반으로 줄어든다', () {
      final rect = CropGeometry.visibleSourceRect(
        transform: Matrix4.identity()..scaleByDouble(2, 2, 1, 1),
        source: const Size(4000, 2000),
        fitted: const Size(600, 300),
        cropSide: 300,
      );

      expect(rect.width, 1000);
      expect(rect.height, 1000);
    });

    test('사진 밖으로 나간 영역은 원본 경계로 잘라낸다', () {
      // 오른쪽으로 크게 끌어서 창이 사진 밖을 보게 만든다.
      final rect = CropGeometry.visibleSourceRect(
        transform: Matrix4.identity()..translateByDouble(-2000, 0, 0, 1),
        source: const Size(4000, 2000),
        fitted: const Size(600, 300),
        cropSide: 300,
      );

      expect(rect.right, lessThanOrEqualTo(4000));
      expect(rect.left, greaterThanOrEqualTo(0));
    });

    test('계산이 어긋나 폭이 0이 되면 원본 전체를 쓴다', () {
      // 지나치게 축소해 창에 사진이 거의 안 잡히는 극단적인 경우.
      final rect = CropGeometry.visibleSourceRect(
        transform: Matrix4.identity()..scaleByDouble(100000, 100000, 1, 1),
        source: const Size(4000, 2000),
        fitted: const Size(600, 300),
        cropSide: 300,
      );

      expect(rect, const Rect.fromLTWH(0, 0, 4000, 2000));
    });
  });
}
