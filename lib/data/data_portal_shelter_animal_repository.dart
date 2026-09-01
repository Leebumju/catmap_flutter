import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models/app_error.dart';
import '../domain/models/shelter_animal.dart';
import '../domain/repositories/nearby_repository.dart';

/// 공공데이터포털 유기동물 조회. iOS 의 `ShelterAnimalClientLive` 와 같은 주소·같은 인자다.
///
/// 시도·시군구 목록은 거의 바뀌지 않으므로 10분 기억한다. iOS 와 같다.
class DataPortalShelterAnimalRepository implements ShelterAnimalRepository {
  DataPortalShelterAnimalRepository({
    required String serviceKey,
    http.Client? httpClient,
    Duration cacheTtl = const Duration(minutes: 10),
  })  : _serviceKey = serviceKey,
        _http = httpClient ?? http.Client(),
        _cacheTtl = cacheTtl;

  static const _host = 'apis.data.go.kr';
  static const _basePath = '/1543061/abandonmentPublicService_v2';

  final String _serviceKey;
  final http.Client _http;
  final Duration _cacheTtl;

  final Map<String, _CacheEntry> _cache = {};

  @override
  Future<ShelterAnimalResult> fetchAnimals({
    String? sidoCode,
    String? sigunguCode,
    ShelterAnimalKind? kind,
    required int page,
    required int size,
  }) async {
    final params = <String, String>{
      '_type': 'json',
      // 종료된 공고는 아예 받지 않는다.
      'state': 'protect',
      'pageNo': '$page',
      'numOfRows': '$size',
      if (sidoCode != null) 'upr_cd': sidoCode,
      if (sidoCode != null && sigunguCode != null) 'org_cd': sigunguCode,
      if (kind != null) 'upkind': kind.rawValue,
    };

    final body = await _get('$_basePath/abandonmentPublic_v2', params);
    final content = _bodyContent(body);
    final items = _items(content);

    return ShelterAnimalResult(
      animals: items
          .map((e) => ShelterAnimal.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: (content['totalCount'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<List<SidoCode>> fetchSidoList() async {
    final body = await _get('$_basePath/sido_v2', {
      '_type': 'json',
      'numOfRows': '100',
      'pageNo': '1',
    }, cacheKey: 'sido');

    return _items(_bodyContent(body)).map((e) {
      final item = e as Map<String, dynamic>;
      return SidoCode(
        id: item['orgCd']?.toString() ?? '',
        name: item['orgdownNm']?.toString() ?? '',
      );
    }).toList();
  }

  @override
  Future<List<SigunguCode>> fetchSigunguList(String sidoCode) async {
    final body = await _get('$_basePath/sigungu_v2', {
      '_type': 'json',
      'upr_cd': sidoCode,
      'numOfRows': '100',
      'pageNo': '1',
    }, cacheKey: 'sigungu:$sidoCode');

    return _items(_bodyContent(body)).map((e) {
      final item = e as Map<String, dynamic>;
      return SigunguCode(
        id: item['orgCd']?.toString() ?? '',
        name: item['orgdownNm']?.toString() ?? '',
      );
    }).toList();
  }

  // MARK: - 내부

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> params, {
    String? cacheKey,
  }) async {
    if (cacheKey != null) {
      final cached = _cache[cacheKey];
      if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
        return cached.value;
      }
    }

    // 서비스 키는 이미 인코딩된 상태로 오는 경우가 있어 직접 이어 붙인다.
    // Uri 의 자동 인코딩에 맡기면 키 안의 특수문자가 두 번 인코딩돼 인증이 깨진다.
    final query = params.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final uri = Uri.parse('https://$_host$path?serviceKey=$_serviceKey&$query');

    final http.Response response;
    try {
      response = await _http.get(uri).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw AppError.unknown;
    }

    if (response.statusCode != 200) throw AppError.unknown;

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      // 인증 실패는 JSON 이 아니라 평문으로 온다.
      throw AppError.unknown;
    }

    if (cacheKey != null) {
      _cache[cacheKey] = _CacheEntry(body, DateTime.now().add(_cacheTtl));
    }
    return body;
  }

  /// response → body 까지 파고든다. 모양이 다르면 빈 것으로 본다.
  Map<String, dynamic> _bodyContent(Map<String, dynamic> json) {
    final response = json['response'] as Map<String, dynamic>?;
    return response?['body'] as Map<String, dynamic>? ?? const {};
  }

  /// items 는 결과가 없을 때 빈 문자열로 오기도 한다. 그래서 타입을 확인하고 꺼낸다.
  List<dynamic> _items(Map<String, dynamic> body) {
    final items = body['items'];
    if (items is! Map<String, dynamic>) return const [];
    final item = items['item'];
    if (item is List) return item;
    // 한 건일 때 배열이 아니라 객체로 오는 경우가 있다.
    if (item is Map<String, dynamic>) return [item];
    return const [];
  }
}

class _CacheEntry {
  _CacheEntry(this.value, this.expiresAt);

  final Map<String, dynamic> value;
  final DateTime expiresAt;
}
