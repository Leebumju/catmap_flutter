import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/app_error.dart';
import '../domain/models/cat_type.dart';
import '../domain/models/sighting.dart';
import '../domain/repositories/sighting_repository.dart';

/// iOS 앱(v1.1.0)이 쓰는 것과 **똑같은 RPC** 를 그대로 호출한다.
/// 서버는 한 줄도 바뀌지 않았고, 부르는 언어만 Swift → Dart 로 바뀌었다.
class SupabaseSightingRepository implements SightingRepository {
  SupabaseSightingRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Sighting>> fetchFeed({
    FeedCursor? cursor,
    required int limit,
  }) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'get_sightings_feed_v4',
        params: {
          'current_user_id': _client.auth.currentUser?.id,
          'cursor_created_at': cursor?.createdAt.toUtc().toIso8601String(),
          'cursor_id': cursor?.id,
          'page_limit': limit,
        },
      );
      return rows
          .map((r) => Sighting.fromRpcRow(r as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw AppError.from(error);
    }
  }

  @override
  Future<bool> toggleLike(String sightingId) async {
    try {
      final result = await _client.rpc<dynamic>(
        'toggle_like',
        params: {'p_sighting_id': sightingId},
      );
      return result as bool;
    } catch (error) {
      throw AppError.from(error);
    }
  }

  @override
  Future<bool> toggleConfirmation(String sightingId) async {
    try {
      final result = await _client.rpc<dynamic>(
        'toggle_confirmation',
        params: {'p_sighting_id': sightingId},
      );
      return result as bool;
    } catch (error) {
      throw AppError.from(error);
    }
  }

  @override
  Future<void> report({
    required String sightingId,
    required String reason,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw AppError.authRequired;
      await _client.from('reports').insert({
        'reporter_id': userId,
        'target_type': 'sighting',
        'target_id': sightingId,
        'reason': reason,
      });
    } catch (error) {
      throw AppError.from(error);
    }
  }

  static const _bucket = 'sighting-photos';
  static const _bucketBase = '/storage/v1/object/public/$_bucket/';

  @override
  Future<void> delete(String sightingId, {List<String> photoUrls = const []}) async {
    try {
      await _client.from('sightings').delete().eq('id', sightingId);
    } catch (error) {
      throw AppError.from(error);
    }
    // Storage 파일 정리는 best-effort. 실패해도 삭제 자체를 실패로 만들지 않는다
    // — 원본 앱과 같은 방침이다(레코드는 이미 지워졌으므로 되돌릴 수 없다).
    final paths = photoUrls
        .map((url) {
          final index = url.indexOf(_bucketBase);
          if (index < 0) return null;
          return url.substring(index + _bucketBase.length);
        })
        .whereType<String>()
        .toList();
    if (paths.isEmpty) return;
    try {
      await _client.storage.from(_bucket).remove(paths);
    } catch (_) {
      // 무시
    }
  }

  @override
  Future<void> blockUser(String blockedUserId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw AppError.authRequired;
      await _client.from('blocks').insert({
        'blocker_id': userId,
        'blocked_id': blockedUserId,
      });
    } catch (error) {
      throw AppError.from(error);
    }
  }

  @override
  Future<List<Sighting>> fetchNearby({
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) async {
    try {
      // 지도 조회. v3 는 댓글 수까지 같이 준다.
      // 반경 필터·거리 계산은 서버가 한다 — 앱이 전체를 받아 걸러내지 않는다.
      final rows = await _client.rpc<List<dynamic>>(
        'get_sightings_with_like_status_v3',
        params: {
          'user_lat': latitude,
          'user_lon': longitude,
          'radius_meters': radiusMeters,
          'current_user_id': _client.auth.currentUser?.id,
        },
      );
      return rows
          .map((r) => Sighting.fromRpcRow(r as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw AppError.from(error);
    }
  }

  @override
  Future<int> fetchMyCount() async {
    try {
      final result = await _client.rpc<dynamic>('get_my_sighting_count');
      // bigint 로 올 수 있어서 num 으로 받는다.
      return (result as num?)?.toInt() ?? 0;
    } catch (error) {
      throw AppError.from(error);
    }
  }

  @override
  Future<List<Sighting>> fetchByUser(String userId) async {
    try {
      // 내 정보 화면의 사진 격자. v3 는 댓글 수까지 같이 준다.
      final rows = await _client.rpc<List<dynamic>>(
        'get_sightings_by_user_v3',
        params: {
          'target_user_id': userId,
          'current_user_id': _client.auth.currentUser?.id,
        },
      );
      return rows
          .map((r) => Sighting.fromRpcRow(r as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw AppError.from(error);
    }
  }

  @override
  Future<Sighting> create({
    required String userId,
    required List<String> photoUrls,
    required double latitude,
    required double longitude,
    required CatType catType,
    String? address,
    String? memo,
  }) async {
    try {
      final row = await _client
          .from('sightings')
          .insert({
            'user_id': userId,
            'photo_urls': photoUrls,
            'latitude': latitude,
            'longitude': longitude,
            'address': address,
            'memo': memo,
            'cat_type': catType.rawValue,
          })
          .select()
          .single();
      return Sighting.fromRpcRow(row);
    } catch (error) {
      throw AppError.from(error);
    }
  }
}
