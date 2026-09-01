import '../models/cat_type.dart';
import '../models/sighting.dart';

/// 피드 페이징 커서 (최신순, created_at + id 복합 커서).
///
/// created_at 만으로는 같은 시각에 올라온 글이 밀리기 때문에 id 를 tie-breaker 로 같이 쓴다.
class FeedCursor {
  const FeedCursor({required this.createdAt, required this.id});

  final DateTime createdAt;
  final String id;
}

/// 목격 기록 데이터 접근. 구현(Supabase)은 data 계층에만 둔다.
abstract class SightingRepository {
  /// 최신순 피드 (차단/숨김 필터 + 커서 페이징). 비로그인 조회 허용.
  Future<List<Sighting>> fetchFeed({FeedCursor? cursor, required int limit});

  /// 좋아요 토글. 토글 뒤의 상태(true = 좋아요됨)를 서버가 돌려준다.
  Future<bool> toggleLike(String sightingId);

  /// "저도 봤어요" 토글. 토글 뒤의 상태를 서버가 돌려준다.
  Future<bool> toggleConfirmation(String sightingId);

  /// 게시물 신고. 5건 누적 시 서버에서 자동 숨김.
  Future<void> report({required String sightingId, required String reason});

  /// 본인 게시물 삭제. 사진 파일은 best-effort 로 같이 지운다.
  Future<void> delete(String sightingId, {List<String> photoUrls});

  /// 유저 차단.
  Future<void> blockUser(String blockedUserId);

  /// 지도용 — 한 지점 반경 안의 목격 기록. 서버가 거리로 걸러서 준다.
  Future<List<Sighting>> fetchNearby({
    required double latitude,
    required double longitude,
    required double radiusMeters,
  });

  /// 내가 올린 게시물 수. 업로드 개수 제한(30개) 판정에 쓴다.
  Future<int> fetchMyCount();

  /// 목격 기록 등록. 사진은 이미 스토리지에 올라가 있어야 한다.
  Future<Sighting> create({
    required String userId,
    required List<String> photoUrls,
    required double latitude,
    required double longitude,
    required CatType catType,
    String? address,
    String? memo,
  });
}
