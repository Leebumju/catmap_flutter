import 'package:equatable/equatable.dart';

/// 둘러보기 탭의 세 갈래. iOS 의 `NearbyCategory` 와 같다.
enum NearbyCategory {
  animalHospital('동물병원', '동물병원'),
  petShop('펫샵/용품', '펫샵'),
  shelterAnimal('유기동물', '');

  const NearbyCategory(this.title, this.searchQuery);

  /// 탭에 보이는 이름.
  final String title;

  /// 카카오 로컬에 보낼 검색어. 유기동물은 검색이 아니라 공공데이터라 비어 있다.
  final String searchQuery;
}

/// 카카오 로컬에서 찾은 장소 한 곳 (동물병원·펫샵 공통).
class NearbyPlace extends Equatable {
  const NearbyPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.roadAddress,
    required this.phone,
    required this.distance,
    required this.latitude,
    required this.longitude,
    this.placeUrl,
  });

  final String id;
  final String name;
  final String category;
  final String address;
  final String roadAddress;
  final String phone;

  /// 검색 기준점에서의 거리(미터).
  final int distance;

  final double latitude;
  final double longitude;
  final String? placeUrl;

  /// 화면에 쓰는 거리 문자열. iOS 와 같은 규칙 — 1km 미만은 미터로.
  String get distanceText {
    if (distance < 1000) return '${distance}m';
    return '${(distance / 1000).toStringAsFixed(1)}km';
  }

  /// 카카오 로컬 응답 한 건.
  factory NearbyPlace.fromJson(Map<String, dynamic> json) {
    final address = json['address_name'] as String? ?? '';
    return NearbyPlace(
      id: json['id'] as String? ?? '$address${json['place_name']}',
      name: json['place_name'] as String? ?? '',
      // 카카오 분류는 ">" 로 이어진 계층이다. 마지막 단계만 보여준다.
      // 예: "의료,건강 > 동물병원" → "동물병원"
      category: _lastCategory(json['category_name'] as String? ?? ''),
      address: address,
      roadAddress: json['road_address_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      distance: int.tryParse(json['distance'] as String? ?? '') ?? 0,
      latitude: double.tryParse(json['y'] as String? ?? '') ?? 0,
      longitude: double.tryParse(json['x'] as String? ?? '') ?? 0,
      placeUrl: json['place_url'] as String?,
    );
  }

  static String _lastCategory(String raw) {
    if (!raw.contains('>')) return raw.trim();
    return raw.split('>').last.trim();
  }

  @override
  List<Object?> get props => [id, name, category, address, distance];
}

/// 한 페이지 조회 결과.
class NearbyPlaceResult extends Equatable {
  const NearbyPlaceResult({
    required this.places,
    required this.isEnd,
    required this.totalCount,
  });

  final List<NearbyPlace> places;

  /// 더 받을 페이지가 없으면 true.
  final bool isEnd;

  final int totalCount;

  @override
  List<Object?> get props => [places, isEnd, totalCount];
}
