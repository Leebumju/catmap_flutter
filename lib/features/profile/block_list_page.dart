import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/block_list_bloc.dart';

/// 차단 목록 관리. iOS 의 `BlockListView` 와 같다.
class BlockListPage extends StatelessWidget {
  const BlockListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('차단 목록')),
      body: BlocConsumer<BlockListBloc, BlockListState>(
        listenWhen: (prev, curr) => prev.signal != curr.signal,
        listener: (context, state) {
          final signal = state.signal;
          if (signal == null) return;
          context.read<BlockListBloc>().add(const BlockListSignalConsumed());
          final message = switch (signal) {
            BlockListSignal.loadFailed => '차단 목록을 불러오지 못했습니다.',
            BlockListSignal.unblockFailed => '차단 해제 중 오류가 발생했습니다.',
          };
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        },
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.users.isEmpty) {
            return const Center(
              child: Text(
                '차단한 사용자가 없습니다',
                style: TextStyle(fontSize: 14, color: Color(0xFFAAAAAA)),
              ),
            );
          }
          return ListView.separated(
            itemCount: state.users.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = state.users[index];
              return ListTile(
                title: Text(user.nickname ?? '알 수 없는 사용자'),
                trailing: TextButton(
                  onPressed: () => context
                      .read<BlockListBloc>()
                      .add(BlockListUnblockPressed(user.blockedUserId)),
                  child: const Text('차단 해제'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
