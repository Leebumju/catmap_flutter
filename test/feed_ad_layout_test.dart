import 'package:catmap_flutter/features/ad/feed_ad_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('피드 광고 자리', () {
    test('7개가 안 되면 광고가 없다', () {
      const layout = FeedAdLayout(sightingCount: 6);
      expect(layout.adCount, 0);
      expect(layout.pageCount, 6);
      expect(layout.isAd(5), isFalse);
    });

    test('7개가 차면 여덟 번째 장이 광고다', () {
      const layout = FeedAdLayout(sightingCount: 7);
      expect(layout.adCount, 1);
      expect(layout.pageCount, 8);
      expect(layout.isAd(7), isTrue);
      expect(layout.sightingIndex(7), isNull);
    });

    test('광고를 건너뛰고 목격 기록 번호가 이어진다', () {
      const layout = FeedAdLayout(sightingCount: 20);

      // 앞 일곱 장은 0~6 번 글
      for (var page = 0; page < 7; page++) {
        expect(layout.sightingIndex(page), page);
      }
      // 여덟 번째는 광고
      expect(layout.isAd(7), isTrue);
      // 그다음은 7번 글부터 이어진다 — 여기가 어긋나면 글 하나가 통째로 안 보인다
      expect(layout.sightingIndex(8), 7);
      expect(layout.sightingIndex(14), 13);
      expect(layout.isAd(15), isTrue);
      expect(layout.sightingIndex(16), 14);
    });

    test('모든 목격 기록이 정확히 한 번씩 나온다', () {
      const count = 50;
      const layout = FeedAdLayout(sightingCount: count);

      final seen = <int>[];
      for (var page = 0; page < layout.pageCount; page++) {
        final index = layout.sightingIndex(page);
        if (index != null) seen.add(index);
      }

      expect(seen.length, count);
      expect(seen.toSet().length, count);
      expect(seen, List.generate(count, (i) => i));
    });

    test('광고 순번은 자리마다 하나씩 매겨진다 — 같은 자리엔 같은 광고가 붙는다', () {
      const layout = FeedAdLayout(sightingCount: 21);
      expect(layout.adSlot(7), 0);
      expect(layout.adSlot(15), 1);
      expect(layout.adSlot(23), 2);
      expect(layout.adSlot(0), isNull);
    });

    test('범위 밖 장 번호는 광고도 글도 아니다', () {
      const layout = FeedAdLayout(sightingCount: 7);
      expect(layout.isAd(99), isFalse);
      expect(layout.sightingIndex(99), isNull);
      expect(layout.sightingIndex(-1), isNull);
    });
  });
}
