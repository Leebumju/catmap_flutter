import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models/app_error.dart';
import '../domain/models/nearby_place.dart';
import '../domain/repositories/nearby_repository.dart';

/// 카카오 로컬 키워드 검색. iOS 의 `NearbyPlaceClientLive` 와 같은 요청을 보낸다.
///
/// 같은 조건을 5분 동안 기억한다. 탭을 오갈 때마다 같은 요청을 다시 보내면
/// 카카오 쪽 하루 사용량이 금방 찬다 — iOS 도 같은 캐시를 둔다.
class KakaoNearbyPlaceRepository implements NearbyPlaceRepository {
  KakaoNearbyPlaceRepository({
    required String restApiKey,
    http.Client? httpClient,
    Duration cacheTtl = const Duration(minutes: 5),
  })  : _key = restApiKey,
        _http = httpClient ?? http.Client(),
        _cacheTtl = cacheTtl;

  final String _key;
  final http.Client _http;
  final Duration _cacheTtl;

  final Map<String, _CacheEntry> _cache = {};

  @override
  Future<NearbyPlaceResult> search({
    required String query,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required int page,
    required int size,
  }) async {
    final cacheKey = '$query|$latitude|$longitude|$radiusMeters|$page|$size';
    final cached = _cache[cacheKey];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return cached.value;
    }

    final uri = Uri.https('dapi.kakao.com', '/v2/local/search/keyword.json', {
      'query': query,
      'x': longitude.toString(),
      'y': latitude.toString(),
      'radius': radiusMeters.toString(),
      'page': page.toString(),
      'size': size.toString(),
      'sort': 'distance',
    });

    final http.Response response;
    try {
      response = await _http.get(
        uri,
        headers: {'Authorization': 'KakaoAK $_key'},
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      throw AppError.unknown;
    }

    if (response.statusCode != 200) {
      // 401 은 키 문제, 429 는 하루 사용량 초과. 화면에서는 둘 다 "불러오지 못함" 이다.
      throw AppError.unknown;
    }

    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final documents = (body['documents'] as List<dynamic>? ?? []);
    final meta = body['meta'] as Map<String, dynamic>? ?? const {};

    final result = NearbyPlaceResult(
      places: documents
          .map((d) => NearbyPlace.fromJson(d as Map<String, dynamic>))
          .toList(),
      isEnd: meta['is_end'] as bool? ?? true,
      totalCount: (meta['total_count'] as num?)?.toInt() ?? 0,
    );

    _cache[cacheKey] = _CacheEntry(result, DateTime.now().add(_cacheTtl));
    return result;
  }
}

class _CacheEntry {
  _CacheEntry(this.value, this.expiresAt);

  final NearbyPlaceResult value;
  final DateTime expiresAt;
}
