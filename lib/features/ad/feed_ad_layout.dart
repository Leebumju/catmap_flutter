/// 피드 사이에 광고를 끼우는 자리 계산.
///
/// iOS 와 같은 규칙이다 — 목격 기록 7개마다 광고 한 장이 그다음 장으로 들어간다.
/// 7개가 다 차지 않은 마지막 묶음 뒤에는 광고를 넣지 않는다.
///
/// 화면과 떼어 둔 이유는 계산이 어긋나면 엉뚱한 글이 보이기 때문이다 —
/// 화면 없이 검사할 수 있어야 한다.
class FeedAdLayout {
  const FeedAdLayout({required this.sightingCount, this.interval = defaultInterval});

  /// iOS 와 같은 간격.
  static const defaultInterval = 7;

  final int sightingCount;
  final int interval;

  /// 한 묶음(목격 기록 [interval] 개 + 광고 1장)의 길이.
  int get _blockSize => interval + 1;

  /// 끼워 넣을 광고 수. 7개가 다 찬 묶음 뒤에만 들어간다.
  int get adCount => sightingCount ~/ interval;

  /// 화면에 넘길 전체 장수.
  int get pageCount => sightingCount + adCount;

  /// [page] 번째 장이 광고인지.
  bool isAd(int page) {
    if (page < 0 || page >= pageCount) return false;
    return page % _blockSize == interval;
  }

  /// [page] 번째 장이 보여줄 목격 기록의 번호. 광고 장이면 null.
  int? sightingIndex(int page) {
    if (isAd(page)) return null;
    if (page < 0 || page >= pageCount) return null;
    final block = page ~/ _blockSize;
    return block * interval + (page % _blockSize);
  }

  /// [page] 번째 광고 장의 순번(0부터). 광고 장이 아니면 null.
  /// 같은 자리에 늘 같은 광고를 물리기 위해 쓴다.
  int? adSlot(int page) {
    if (!isAd(page)) return null;
    return page ~/ _blockSize;
  }
}
