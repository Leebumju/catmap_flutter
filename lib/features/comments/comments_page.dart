import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/comment.dart';
import '../profile/profile_page.dart' show BadgeChip;
import 'bloc/comments_bloc.dart';

/// 댓글 화면. iOS 의 `CommentsView` 와 같은 구성이다 —
/// 위에 목록, 아래에 입력칸. 답글은 댓글 아래에 접었다 편다.
class CommentsPage extends StatefulWidget {
  const CommentsPage({super.key, required this.onLoginRequired});

  final VoidCallback onLoginRequired;

  /// 신고 사유. 피드와 같은 네 가지다.
  static const reportReasons = [
    '부적절한 콘텐츠',
    '고양이가 아님',
    '스팸/광고',
    '기타',
  ];

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        context.read<CommentsBloc>().add(const CommentsLoadMoreRequested());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CommentsBloc, CommentsState>(
      listenWhen: (prev, curr) =>
          prev.signal != curr.signal || prev.inputText != curr.inputText,
      listener: (context, state) {
        // 전송에 성공하면 bloc 이 입력값을 비운다. 입력칸도 같이 비운다.
        if (state.inputText.isEmpty && _controller.text.isNotEmpty) {
          _controller.clear();
        }

        final signal = state.signal;
        if (signal == null) return;
        context.read<CommentsBloc>().add(const CommentsSignalConsumed());

        if (signal == CommentsSignal.loginRequired) {
          widget.onLoginRequired();
          return;
        }

        final message = switch (signal) {
          CommentsSignal.accountBanned => '이용이 제한된 계정입니다.',
          CommentsSignal.submitFailed => '댓글을 남기지 못했습니다.',
          CommentsSignal.deleted => '댓글이 삭제되었습니다.',
          CommentsSignal.deleteFailed => '삭제 중 오류가 발생했습니다.',
          CommentsSignal.reported => '신고가 접수되었습니다. 검토 후 조치하겠습니다.',
          CommentsSignal.reportFailed => '신고 처리 중 오류가 발생했습니다.',
          CommentsSignal.blocked => '해당 유저가 차단되었습니다.',
          CommentsSignal.blockFailed => '차단 처리 중 오류가 발생했습니다.',
          CommentsSignal.loadFailed => '댓글을 불러오지 못했습니다.',
          CommentsSignal.loginRequired => '',
        };
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: Text('댓글 ${state.loadedCount}')),
          body: Column(
            children: [
              Expanded(child: _list(context, state)),
              if (state.replyingTo != null) _ReplyBanner(target: state.replyingTo!),
              _InputBar(controller: _controller, state: state),
            ],
          ),
        );
      },
    );
  }

  Widget _list(BuildContext context, CommentsState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.comments.isEmpty) {
      return const Center(
        child: Text(
          '첫 댓글을 남겨보세요',
          style: TextStyle(fontSize: 14, color: Color(0xFFAAAAAA)),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: state.comments.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.comments.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final comment = state.comments[index];
        final isExpanded = state.expandedReplies.contains(comment.id);
        final replies = state.replies[comment.id] ?? const <Comment>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CommentRow(
              comment: comment,
              isMine: comment.userId == state.currentUserId,
              onReply: () => context
                  .read<CommentsBloc>()
                  .add(CommentsReplyTargetChanged(comment)),
              onMore: () => _showMore(context, comment, state),
            ),
            if (comment.replyCount > 0 || replies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 52, bottom: 4),
                child: TextButton(
                  onPressed: () => context
                      .read<CommentsBloc>()
                      .add(CommentsRepliesToggled(comment.id)),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    isExpanded
                        ? '답글 숨기기'
                        : '답글 ${comment.replyCount > 0 ? comment.replyCount : replies.length}개 보기',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF888888),
                    ),
                  ),
                ),
              ),
            if (state.loadingReplies.contains(comment.id))
              const Padding(
                padding: EdgeInsets.only(left: 52, bottom: 8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (isExpanded)
              for (final reply in replies)
                Padding(
                  padding: const EdgeInsets.only(left: 40),
                  child: _CommentRow(
                    comment: reply,
                    isMine: reply.userId == state.currentUserId,
                    // 답글에는 답글을 달 수 없다. 서버가 막는다.
                    onReply: null,
                    onMore: () => _showMore(context, reply, state),
                  ),
                ),
          ],
        );
      },
    );
  }

  Future<void> _showMore(
    BuildContext context,
    Comment comment,
    CommentsState state,
  ) async {
    final bloc = context.read<CommentsBloc>();
    final isMine = comment.userId == state.currentUserId;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: isMine
              ? [
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text('삭제하기',
                        style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      bloc.add(CommentsDeleted(comment.id));
                    },
                  ),
                ]
              : [
                  for (final reason in CommentsPage.reportReasons)
                    ListTile(
                      title: Text('신고 — $reason'),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        bloc.add(CommentsReported(
                          commentId: comment.id,
                          reason: reason,
                        ));
                      },
                    ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.block),
                    title: const Text('이 유저 차단하기'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      bloc.add(CommentsUserBlocked(comment.userId));
                    },
                  ),
                ],
        ),
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({
    required this.comment,
    required this.isMine,
    required this.onReply,
    required this.onMore,
  });

  final Comment comment;
  final bool isMine;
  final VoidCallback? onReply;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final badge = comment.userRepresentativeBadge;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundColor: Color(0xFFFAEEDA),
            child: Text('🐱', style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.userNickname ?? '알 수 없는 사용자',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      BadgeChip(badge: badge),
                    ],
                    const SizedBox(width: 6),
                    Text(
                      _timeAgo(comment.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFAAAAAA),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.content, style: const TextStyle(fontSize: 14)),
                if (onReply != null)
                  TextButton(
                    onPressed: onReply,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '답글 달기',
                      style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onMore,
            icon: const Icon(Icons.more_horiz, size: 18, color: Color(0xFFAAAAAA)),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  /// 피드 팝업과 같은 규칙 — 분, 시간, 일.
  static String _timeAgo(DateTime date) {
    final minutes = DateTime.now().toUtc().difference(date.toUtc()).inMinutes;
    if (minutes < 1) return '방금';
    if (minutes < 60) return '$minutes분 전';
    final hours = minutes ~/ 60;
    if (hours < 24) return '$hours시간 전';
    return '${hours ~/ 24}일 전';
  }
}

class _ReplyBanner extends StatelessWidget {
  const _ReplyBanner({required this.target});

  final Comment target;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F5F5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${target.userNickname ?? '사용자'}님에게 답글 남기는 중',
              style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
            ),
          ),
          GestureDetector(
            onTap: () => context
                .read<CommentsBloc>()
                .add(const CommentsReplyTargetChanged(null)),
            child: const Icon(Icons.close, size: 16, color: Color(0xFF888888)),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.state});

  final TextEditingController controller;
  final CommentsState state;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: 4,
                minLines: 1,
                maxLength: CommentsState.maxLength,
                onChanged: (value) =>
                    context.read<CommentsBloc>().add(CommentsInputChanged(value)),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: state.replyingTo == null ? '댓글 남기기' : '답글 남기기',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: state.canSubmit
                  ? () => context.read<CommentsBloc>().add(const CommentsSubmitted())
                  : null,
              icon: const Icon(Icons.send),
              color: const Color(0xFFE8734A),
            ),
          ],
        ),
      ),
    );
  }
}
