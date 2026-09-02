import 'package:equatable/equatable.dart';

import 'badge.dart';

/// 게시물의 댓글 또는 답글.
///
/// [parentId] 가 없으면 최상위 댓글, 있으면 답글이다. 답글의 답글은 서버가 막으므로
/// 깊이는 항상 0 아니면 1이다.
class Comment extends Equatable {
  const Comment({
    required this.id,
    required this.sightingId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.parentId,
    this.reportCount = 0,
    this.isHidden = false,
    this.userNickname,
    this.userProfileImageUrl,
    this.userRole,
    this.userRepresentativeBadge,
    this.replyCount = 0,
  });

  final String id;
  final String sightingId;
  final String userId;
  final String? parentId;
  final String content;
  final int reportCount;
  final bool isHidden;
  final DateTime createdAt;

  final String? userNickname;
  final String? userProfileImageUrl;
  final String? userRole;
  final Badge? userRepresentativeBadge;

  /// 답글 수. 최상위 댓글에서만 뜻이 있고 답글이면 0 이다.
  final int replyCount;

  bool get isReply => parentId != null;

  /// RPC(`get_comments` / `get_replies` / `add_comment`)가 주는 한 줄.
  ///
  /// created_at 은 커서 페이징의 이음새라 UTC 로 고정한다 — 피드에서 겪은 것과 같은 문제다.
  /// reply_count 는 bigint 라 num 으로 받는다.
  factory Comment.fromRpcRow(Map<String, dynamic> row) {
    return Comment(
      id: row['id'] as String,
      sightingId: row['sighting_id'] as String,
      userId: row['user_id'] as String,
      parentId: row['parent_id'] as String?,
      content: row['content'] as String? ?? '',
      reportCount: (row['report_count'] as num?)?.toInt() ?? 0,
      isHidden: row['is_hidden'] as bool? ?? false,
      createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
      userNickname: row['user_nickname'] as String?,
      userProfileImageUrl: row['user_profile_image_url'] as String?,
      userRole: row['user_role'] as String?,
      userRepresentativeBadge:
          Badge.fromRawValue(row['user_representative_badge'] as String?),
      replyCount: (row['reply_count'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        id,
        sightingId,
        userId,
        parentId,
        content,
        reportCount,
        isHidden,
        createdAt,
        userNickname,
        userProfileImageUrl,
        userRole,
        userRepresentativeBadge,
        replyCount,
      ];
}

/// 댓글 목록 페이징 커서. 피드와 같은 방식(작성 시각 + id)이다.
class CommentCursor {
  const CommentCursor({required this.createdAt, required this.id});

  final DateTime createdAt;
  final String id;
}
