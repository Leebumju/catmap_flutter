import '../models/coordinate.dart';

/// 위치·주소. 구현은 data 계층에만 둔다 (geolocator / geocoding / 카카오 로컬).
///
/// iOS 의 `LocationClient` 와 같은 경계다. 지도 SDK 를 바꿔도 이 인터페이스는
/// 그대로 남는다.
abstract class LocationRepository {
  /// 위치 권한 요청. 이미 정해져 있으면 물어보지 않고 그 값을 돌려준다.
  Future<LocationPermissionStatus> requestPermission();

  /// 현재 위치 한 번 가져오기. 권한이 없거나 못 잡으면 예외를 던진다.
  Future<Coordinate> currentLocation();

  /// 위치 변화 스트림. 지도의 내 위치 점을 따라 움직이게 하는 데 쓴다.
  Stream<Coordinate> locationStream();

  /// 좌표 → 표시용 주소(동 단위까지).
  Future<AdministrativeAddress> reverseGeocode(Coordinate coordinate);

  /// 주소·장소 검색. [around] 가 있으면 그 주변을 우선한다.
  Future<List<SearchedPlace>> searchAddress(String query, Coordinate? around);
}
