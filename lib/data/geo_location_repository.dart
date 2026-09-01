import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;

import '../domain/models/app_error.dart';
import '../domain/models/coordinate.dart';
import '../domain/repositories/location_repository.dart';

/// 위치는 geolocator, 좌표→주소는 안드로이드 Geocoder, 장소 검색은 카카오 로컬.
///
/// iOS 는 셋 다 애플 것(CoreLocation / CLGeocoder / MKLocalSearch)으로 했다.
/// 안드로이드에는 MKLocalSearch 에 해당하는 게 없어서 검색만 카카오 로컬을 쓴다 —
/// 이 앱이 "내 주변" 기능에서 이미 쓰고 있는 API 라 새로 뚫는 경로가 아니다.
class GeoLocationRepository implements LocationRepository {
  GeoLocationRepository({required String kakaoRestApiKey, http.Client? httpClient})
      : _kakaoKey = kakaoRestApiKey,
        _http = httpClient ?? http.Client();

  final String _kakaoKey;
  final http.Client _http;

  /// geocoding 5 부터는 인스턴스를 만들어 쓴다.
  /// 생성자의 locale 인자는 내부로 전달되지 않아서(패키지 구현 확인) 호출할 때 넘긴다.
  final _geocoder = geocoding.Geocoding();
  static const _korean = Locale('ko', 'KR');

  /// 검색할 때 우선할 반경. iOS 는 20km 사각 영역을 줬다.
  static const _searchRadiusMeters = 20000;

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      return LocationPermissionStatus.denied;
    }

    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }

    switch (permission) {
      case geo.LocationPermission.always:
      case geo.LocationPermission.whileInUse:
        return LocationPermissionStatus.authorized;
      case geo.LocationPermission.denied:
        return LocationPermissionStatus.notDetermined;
      case geo.LocationPermission.deniedForever:
      case geo.LocationPermission.unableToDetermine:
        return LocationPermissionStatus.denied;
    }
  }

  @override
  Future<Coordinate> currentLocation() async {
    final position = await geo.Geolocator.getCurrentPosition(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.best,
      ),
    );
    return Coordinate(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  @override
  Stream<Coordinate> locationStream() {
    return geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.best,
        // 10m 넘게 움직였을 때만 알려준다. 촘촘히 받으면 지도가 계속 다시 그려진다.
        distanceFilter: 10,
      ),
    ).map(
      (p) => Coordinate(latitude: p.latitude, longitude: p.longitude),
    );
  }

  @override
  Future<AdministrativeAddress> reverseGeocode(Coordinate coordinate) async {
    final placemarks = await _geocoder.placemarkFromCoordinates(
      coordinate.latitude,
      coordinate.longitude,
      locale: _korean,
    );
    if (placemarks.isEmpty) return const AdministrativeAddress();

    final p = placemarks.first;
    return AdministrativeAddress(
      administrativeArea: p.administrativeArea,
      locality: p.locality,
      subLocality: p.subLocality,
    );
  }

  @override
  Future<List<SearchedPlace>> searchAddress(
    String query,
    Coordinate? around,
  ) async {
    final uri = Uri.https('dapi.kakao.com', '/v2/local/search/keyword.json', {
      'query': query,
      'size': '15',
      if (around != null) ...{
        'x': around.longitude.toString(),
        'y': around.latitude.toString(),
        'radius': '$_searchRadiusMeters',
        'sort': 'distance',
      },
    });

    final response = await _http.get(
      uri,
      headers: {'Authorization': 'KakaoAK $_kakaoKey'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      // 401 = 키 문제, 429 = 쿼터 초과. 화면에서는 둘 다 "검색 실패" 로 묶는다.
      throw AppError.unknown;
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final documents = (body['documents'] as List<dynamic>? ?? []);

    return documents.map((raw) {
      final doc = raw as Map<String, dynamic>;
      final roadAddress = doc['road_address_name'] as String? ?? '';
      final address = doc['address_name'] as String? ?? '';
      return SearchedPlace(
        id: doc['id'] as String? ?? '$address${doc['place_name']}',
        name: doc['place_name'] as String? ?? '',
        address: roadAddress.isNotEmpty ? roadAddress : address,
        coordinate: Coordinate(
          latitude: double.tryParse(doc['y'] as String? ?? '') ?? 0,
          longitude: double.tryParse(doc['x'] as String? ?? '') ?? 0,
        ),
      );
    }).toList();
  }
}
