import '../models/comment.dart';

/// 댓글. 구현(Supabase)은 data 계층에만 둔다.
abstract class CommentRepository {
  /// 게시물의 최상위 댓글. 차단·숨김은 서버가 걸러 준다. 비로그인도 볼 수 있다.
  Future<List<Comment>> fetch({
    required String sightingId,
    CommentCursor? cursor,
    required int limit,
  });

  /// 한 댓글에 달린 답글 전부(오래된 순). 비로그인도 볼 수 있다.
  Future<List<Comment>> fetchReplies(String parentId);

  /// 댓글 또는 답글 작성. [parentId] 가 있으면 답글이다.
  Future<Comment> add({
    required String sightingId,
    required String content,
    String? parentId,
  });

  /// 본인 댓글 삭제. 남의 것은 서버가 막는다.
  Future<void> delete(String commentId);

  /// 댓글 신고. 5건 쌓이면 서버가 자동으로 숨긴다.
  Future<void> report({required String commentId, required String reason});
}
