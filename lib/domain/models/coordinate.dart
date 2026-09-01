import 'package:equatable/equatable.dart';

/// 위도·경도 한 쌍. 지도 SDK 의 타입을 앱 안쪽으로 들이지 않기 위한 자리다.
///
/// iOS 가 `Coordinate` 를 둔 이유와 같다 — 지도를 갈아끼울 때 이 타입만
/// 새 SDK 의 좌표 타입으로 바꿔주면 화면 로직은 그대로 쓴다.
class Coordinate extends Equatable {
  const Coordinate({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  List<Object?> get props => [latitude, longitude];
}

/// 위치 권한 상태. iOS 의 `LocationPermission` 과 같은 세 가지로 좁혔다.
enum LocationPermissionStatus {
  authorized,
  denied,
  notDetermined,
}

/// 주소·장소 검색 결과 한 건.
class SearchedPlace extends Equatable {
  const SearchedPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.coordinate,
  });

  final String id;
  final String name;
  final String address;
  final Coordinate coordinate;

  @override
  List<Object?> get props => [id, name, address, coordinate];
}

/// 시·군·구·동 단위로 끊어 받은 주소. 역지오코딩 결과를 담는다.
class AdministrativeAddress extends Equatable {
  const AdministrativeAddress({
    this.administrativeArea,
    this.locality,
    this.subLocality,
  });

  /// 서울특별시
  final String? administrativeArea;

  /// 마포구
  final String? locality;

  /// 서교동
  final String? subLocality;

  /// 화면에 쓰는 문자열. iOS 와 같은 규칙으로 동 단위까지만 이어 붙인다.
  /// 상세 주소(번지)는 목격 위치가 그대로 드러나므로 쓰지 않는다.
  String get display {
    final parts = <String>[];
    for (final candidate in [administrativeArea, locality, subLocality]) {
      if (candidate != null && candidate.isNotEmpty && !parts.contains(candidate)) {
        parts.add(candidate);
      }
    }
    return parts.isEmpty ? '알 수 없는 위치' : parts.join(' ');
  }

  @override
  List<Object?> get props => [administrativeArea, locality, subLocality];
}
