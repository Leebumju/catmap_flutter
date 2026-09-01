import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/sighting.dart';
import 'bloc/feed_bloc.dart';
import 'bloc/feed_event.dart';
import 'bloc/feed_state.dart';

/// 목격 피드 — 세로로 넘기면 다음 게시물, 가로로 넘기면 같은 게시물의 다음 사진.
class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<FeedBloc, FeedState>(
      // 일회성 신호만 듣는다. 목록이 바뀔 때마다 스낵바가 뜨면 안 되므로
      // signal 값이 실제로 바뀐 순간에만 반응한다.
      listenWhen: (prev, curr) => prev.signal != curr.signal,
      listener: (context, state) {
        final signal = state.signal;
        if (signal == null) return;
        final message = switch (signal) {
          FeedSignal.loginRequired => '로그인이 필요합니다.',
          FeedSignal.accountBanned => '이용이 제한된 계정입니다.',
          FeedSignal.reported => '신고가 접수되었습니다. 검토 후 조치하겠습니다.',
          FeedSignal.reportFailed => '신고 처리 중 오류가 발생했습니다.',
          FeedSignal.blocked => '해당 유저가 차단되었습니다.',
          FeedSignal.blockFailed => '차단 처리 중 오류가 발생했습니다.',
          FeedSignal.deleted => '게시물이 삭제되었습니다.',
          FeedSignal.deleteFailed => '삭제 중 오류가 발생했습니다.',
        };
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
        context.read<FeedBloc>().add(const FeedSignalConsumed());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: BlocBuilder<FeedBloc, FeedState>(
            builder: (context, state) {
              if (state.isLoading && state.sightings.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.sightings.isEmpty) {
                return const Center(
                  child: Text(
                    '아직 목격 기록이 없어요',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async =>
                    context.read<FeedBloc>().add(const FeedRefreshed()),
                child: _FeedPager(state: state),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FeedPager extends StatefulWidget {
  const _FeedPager({required this.state});

  final FeedState state;

  @override
  State<_FeedPager> createState() => _FeedPagerState();
}

class _FeedPagerState extends State<_FeedPager> {
  late final PageController _controller = PageController();

  @override
  void dispose() {
    // bloc 은 화면 단위 인스턴스라 컨트롤러는 여기서 직접 푼다.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return PageView.builder(
      controller: _controller,
      scrollDirection: Axis.vertical,
      itemCount: state.sightings.length,
      onPageChanged: (index) {
        final bloc = context.read<FeedBloc>();
        bloc.add(FeedIndexChanged(index));
        // 끝에서 세 장 남으면 다음 페이지를 당겨온다.
        // 여러 번 튀어도 bloc 쪽 droppable 이 중복 요청을 버린다.
        if (index >= state.sightings.length - 3) {
          bloc.add(const FeedLoadMoreRequested());
        }
      },
      itemBuilder: (context, index) =>
          _SightingCard(sighting: state.sightings[index], state: state),
    );
  }
}

class _SightingCard extends StatelessWidget {
  const _SightingCard({required this.sighting, required this.state});

  final Sighting sighting;
  final FeedState state;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _PhotoPager(sighting: sighting),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC000000)],
              ),
            ),
            child: _Overlay(sighting: sighting, state: state),
          ),
        ),
      ],
    );
  }
}

class _PhotoPager extends StatelessWidget {
  const _PhotoPager({required this.sighting});

  final Sighting sighting;

  @override
  Widget build(BuildContext context) {
    if (sighting.photoUrls.isEmpty) {
      return const ColoredBox(color: Colors.black26);
    }
    return PageView.builder(
      itemCount: sighting.photoUrls.length,
      onPageChanged: (index) =>
          context.read<FeedBloc>().add(FeedPhotoIndexChanged(index)),
      itemBuilder: (context, index) => Image.network(
        sighting.photoUrls[index],
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const Center(child: CircularProgressIndicator()),
        errorBuilder: (context, error, stack) => const ColoredBox(
          color: Colors.black26,
          child: Center(
            child: Icon(Icons.broken_image, color: Colors.white54),
          ),
        ),
      ),
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({required this.sighting, required this.state});

  final Sighting sighting;
  final FeedState state;

  @override
  Widget build(BuildContext context) {
    final liked = state.isLiked(sighting.id);
    final confirmed = state.isConfirmed(sighting.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: sighting.userProfileImageUrl != null
                  ? NetworkImage(sighting.userProfileImageUrl!)
                  : null,
              child: sighting.userProfileImageUrl == null
                  ? const Icon(Icons.person, size: 16)
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      sighting.userNickname ?? '알 수 없음',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (sighting.userRepresentativeBadge != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      sighting.userRepresentativeBadge!.displayName,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.orangeAccent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_horiz, color: Colors.white),
              onPressed: () => _showMore(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _Chip(label: sighting.catType.label),
            if (sighting.displayAddress != null) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  sighting.displayAddress!,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        if (sighting.memo != null && sighting.memo!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            sighting.memo!,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            _ActionButton(
              icon: liked ? Icons.favorite : Icons.favorite_border,
              color: liked ? Colors.redAccent : Colors.white,
              count: state.likeCount(sighting.id),
              onPressed: () =>
                  context.read<FeedBloc>().add(FeedLikeToggled(sighting.id)),
            ),
            const SizedBox(width: 16),
            _ActionButton(
              icon: confirmed ? Icons.visibility : Icons.visibility_outlined,
              color: confirmed ? Colors.lightBlueAccent : Colors.white,
              count: state.confirmationCount(sighting.id),
              label: '저도 봤어요',
              onPressed: () => context
                  .read<FeedBloc>()
                  .add(FeedConfirmationToggled(sighting.id)),
            ),
          ],
        ),
      ],
    );
  }

  void _showMore(BuildContext context) {
    final bloc = context.read<FeedBloc>();
    final mine = state.isMine(sighting);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: mine
              ? [
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('삭제하기'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      bloc.add(FeedSightingDeleted(sighting.id));
                    },
                  ),
                ]
              : [
                  for (final reason in const [
                    '부적절한 콘텐츠',
                    '고양이가 아님',
                    '스팸/광고',
                    '기타',
                  ])
                    ListTile(
                      title: Text('신고 — $reason'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        bloc.add(FeedReported(
                          sightingId: sighting.id,
                          reason: reason,
                        ));
                      },
                    ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.block),
                    title: const Text('이 유저 차단하기'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      bloc.add(FeedUserBlocked(sighting.userId));
                    },
                  ),
                ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.count,
    required this.onPressed,
    this.label,
  });

  final IconData icon;
  final Color color;
  final int count;
  final String? label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 4),
          Text(
            label == null ? '$count' : '${label!} $count',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
