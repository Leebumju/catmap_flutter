import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/badge.dart';
import '../../domain/models/sighting.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/repositories/sighting_repository.dart';
import 'bloc/profile_bloc.dart';
import 'bloc/profile_edit_bloc.dart';
import 'bloc/profile_event.dart';
import 'bloc/profile_state.dart';
import 'profile_edit_page.dart';
import 'settings_page.dart';

/// 내 정보 화면. iOS 의 `ProfileView` 와 같은 구성이다.
class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.authRepository,
    required this.badgeRepository,
    required this.blockRepository,
    required this.notificationSettingsRepository,
    required this.sightingRepository,
    required this.onLoginRequired,
  });

  final AuthRepository authRepository;
  final BadgeRepository badgeRepository;
  final BlockRepository blockRepository;
  final NotificationSettingsRepository notificationSettingsRepository;
  final SightingRepository sightingRepository;

  /// 로그인 화면을 띄운다. 닫히면 프로필을 다시 읽는다.
  final Future<void> Function() onLoginRequired;

  static const _accent = Color(0xFFE8734A);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileBloc, ProfileState>(
      listenWhen: (prev, curr) => prev.signal != curr.signal,
      listener: (context, state) {
        final signal = state.signal;
        if (signal == null) return;
        context.read<ProfileBloc>().add(const ProfileSignalConsumed());

        if (signal == ProfileSignal.accountDeleted) {
          showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('탈퇴 완료'),
              content: const Text('회원탈퇴가 완료되었습니다.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
          return;
        }

        final message = switch (signal) {
          ProfileSignal.logoutFailed => '로그아웃에 실패했습니다.',
          ProfileSignal.deleteAccountFailed => '탈퇴 처리 중 오류가 발생했습니다.',
          ProfileSignal.loadFailed => '내 정보를 불러오지 못했습니다.',
          ProfileSignal.accountDeleted => '',
        };
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _NavBar(onSettingsPressed: () => _openSettings(context)),
                    if (state.isLoggedIn)
                      ..._loggedIn(context, state)
                    else
                      Expanded(child: _LoggedOut(onLoginPressed: () => _login(context))),
                  ],
                ),
                if (state.isWorking)
                  const ColoredBox(
                    color: Colors.black26,
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _loggedIn(BuildContext context, ProfileState state) {
    return [
      _Header(
        nickname: state.user?.nickname ?? '닉네임 없음',
        representativeBadge: state.user?.representativeBadge,
        sightingCount: state.sightingCount,
        onEditPressed: () => _openEdit(context, state),
      ),
      Expanded(child: _PhotoGrid(sightings: state.sightings)),
    ];
  }

  Future<void> _login(BuildContext context) async {
    final bloc = context.read<ProfileBloc>();
    await onLoginRequired();
    // 로그인하고 돌아왔을 수 있으니 다시 읽는다.
    bloc.add(const ProfileStarted(force: true));
  }

  Future<void> _openEdit(BuildContext context, ProfileState state) async {
    final user = state.user;
    if (user == null) return;
    final bloc = context.read<ProfileBloc>();

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => ProfileEditBloc(
            authRepository: authRepository,
            badgeRepository: badgeRepository,
            user: user,
          )..add(const ProfileEditStarted()),
          child: const ProfileEditPage(),
        ),
      ),
    );
    if (updated == true) bloc.add(const ProfileStarted(force: true));
  }

  Future<void> _openSettings(BuildContext context) async {
    final bloc = context.read<ProfileBloc>();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          profileBloc: bloc,
          blockRepository: blockRepository,
          notificationSettingsRepository: notificationSettingsRepository,
        ),
      ),
    );
    bloc.add(const ProfileStarted(force: true));
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.onSettingsPressed});

  final VoidCallback onSettingsPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          const Text(
            '내 정보',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: Color(0xFF222222),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onSettingsPressed,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.settings_outlined,
                  size: 18, color: Color(0xFF555555)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoggedOut extends StatelessWidget {
  const _LoggedOut({required this.onLoginPressed});

  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset('assets/app-logo.png',
                width: 80, height: 80, fit: BoxFit.cover),
          ),
          const SizedBox(height: 16),
          const Text(
            '로그인하고\n나만의 목격 기록을 시작하세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF555555),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 200,
            height: 48,
            child: ElevatedButton(
              onPressed: onLoginPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: ProfilePage._accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '로그인하기',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.nickname,
    required this.representativeBadge,
    required this.sightingCount,
    required this.onEditPressed,
  });

  final String nickname;
  final Badge? representativeBadge;
  final int sightingCount;
  final VoidCallback onEditPressed;

  @override
  Widget build(BuildContext context) {
    final badge = representativeBadge;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 20, bottom: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x4DBDBDBD))),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAEEDA),
                  shape: BoxShape.circle,
                  border: Border.all(color: ProfilePage._accent, width: 2.5),
                ),
                child: const Center(
                  child: Text('🐱', style: TextStyle(fontSize: 32)),
                ),
              ),
              GestureDetector(
                onTap: onEditPressed,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: ProfilePage._accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.edit, size: 9, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            nickname,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF222222),
            ),
          ),
          if (badge != null) ...[
            const SizedBox(height: 6),
            BadgeChip(badge: badge),
          ],
          const SizedBox(height: 6),
          Text(
            '목격 기록 $sightingCount건',
            style: const TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onEditPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                '프로필 편집',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF555555),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 칭호 캡슐. 색은 iOS 의 값을 그대로 쓴다.
class BadgeChip extends StatelessWidget {
  const BadgeChip({super.key, required this.badge});

  final Badge badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badge.backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        badge.displayName,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: badge.textColor,
        ),
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.sightings});

  final List<Sighting> sightings;

  @override
  Widget build(BuildContext context) {
    if (sightings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined, size: 40, color: Color(0xFFAAAAAA)),
            SizedBox(height: 12),
            Text('아직 올린 사진이 없어요',
                style: TextStyle(fontSize: 14, color: Color(0xFFAAAAAA))),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
      ),
      itemCount: sightings.length,
      itemBuilder: (context, index) {
        final sighting = sightings[index];
        final thumb = sighting.thumbnailUrls.isEmpty
            ? null
            : sighting.thumbnailUrls.first;
        if (thumb == null) return const _GridPlaceholder();
        return Image.network(
          thumb,
          fit: BoxFit.cover,
          // 썸네일이 없는 예전 게시물은 원본으로 되돌린다.
          errorBuilder: (context, _, __) => sighting.photoUrls.isEmpty
              ? const _GridPlaceholder()
              : Image.network(
                  sighting.photoUrls.first,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _GridPlaceholder(),
                ),
        );
      },
    );
  }
}

class _GridPlaceholder extends StatelessWidget {
  const _GridPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF5F5F5),
      child: Icon(Icons.pets, color: Color(0xFFCCCCCC)),
    );
  }
}
