import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/app_error.dart';
import '../domain/models/comment.dart';
import '../domain/repositories/comment_repository.dart';

/// iOS 의 `CommentClientLive` 와 같은 RPC 를 그대로 부른다.
class SupabaseCommentRepository implements CommentRepository {
  SupabaseCommentRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Comment>> fetch({
    required String sightingId,
    CommentCursor? cursor,
    required int limit,
  }) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'get_comments',
        params: {
          'p_sighting_id': sightingId,
          'p_current_user_id': _client.auth.currentUser?.id,
          'p_cursor_created_at': cursor?.createdAt.toUtc().toIso8601String(),
          'p_cursor_id': cursor?.id,
          'p_limit': limit,
        },
      );
      return rows
          .map((r) => Comment.fromRpcRow(r as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw AppError.from(error);
    }
  }

  @override
  Future<List<Comment>> fetchReplies(String parentId) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'get_replies',
        params: {
          'p_parent_id': parentId,
          'p_current_user_id': _client.auth.currentUser?.id,
        },
      );
      return rows
          .map((r) => Comment.fromRpcRow(r as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw AppError.from(error);
    }
  }

  @override
  Future<Comment> add({
    required String sightingId,
    required String content,
    String? parentId,
  }) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'add_comment',
        params: {
          'p_sighting_id': sightingId,
          'p_content': content,
          'p_parent_id': parentId,
        },
      );
      if (rows.isEmpty) throw AppError.unknown;
      return Comment.fromRpcRow(rows.first as Map<String, dynamic>);
    } catch (error) {
      if (error is AppError) rethrow;
      throw AppError.from(error);
    }
  }

  @override
  Future<void> delete(String commentId) async {
    try {
      await _client.from('comments').delete().eq('id', commentId);
    } catch (error) {
      throw AppError.from(error);
    }
  }

  @override
  Future<void> report({
    required String commentId,
    required String reason,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AppError.authRequired;

    try {
      await _client.from('reports').insert({
        'reporter_id': userId,
        'target_type': 'comment',
        'target_id': commentId,
        'reason': reason,
      });
    } catch (error) {
      throw AppError.from(error);
    }
  }
}
