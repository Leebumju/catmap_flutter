/// 고양이 종류 — rawValue 는 서버 `sightings.cat_type` 과 매핑.
enum CatType {
  stray('stray', '길냥이'),
  domestic('domestic', '집냥이');

  const CatType(this.rawValue, this.label);

  final String rawValue;
  final String label;

  /// 모르는 값이 오면 길냥이로 떨어뜨린다 — 서버가 종류를 늘려도 구버전이 안 깨진다.
  static CatType fromRawValue(String? raw) {
    for (final t in CatType.values) {
      if (t.rawValue == raw) return t;
    }
    return CatType.stray;
  }
}
