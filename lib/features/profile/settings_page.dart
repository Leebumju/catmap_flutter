import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/auth_provider.dart';
import '../../domain/repositories/profile_repository.dart';
import '../auth/web_page.dart';
import 'bloc/block_list_bloc.dart';
import 'bloc/profile_bloc.dart';
import 'bloc/profile_event.dart';
import 'bloc/profile_state.dart';
import 'bloc/settings_bloc.dart';
import 'block_list_page.dart';

/// 설정 화면. iOS 의 `SettingsView` 와 같은 구성·같은 순서다.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.profileBloc,
    required this.blockRepository,
    required this.notificationSettingsRepository,
  });

  /// 내 정보 화면의 bloc 을 그대로 쓴다 — 로그아웃·탈퇴가 같은 상태를 건드린다.
  final ProfileBloc profileBloc;

  final BlockRepository blockRepository;
  final NotificationSettingsRepository notificationSettingsRepository;

  static const _termsUrl = 'https://sambonge.tistory.com/2';
  static const _privacyUrl = 'https://sambonge.tistory.com/1';
  static const _noticeUrl = 'https://sambonge.tistory.com/3';

  /// 앱 버전. pubspec 의 version 과 맞춘다.
  static const _appVersion = '0.1.0';

  static const _danger = Color(0xFFE24B4A);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: profileBloc),
        BlocProvider(
          create: (_) =>
              SettingsBloc(repository: notificationSettingsRepository)
                ..add(const SettingsStarted()),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(title: const Text('설정')),
        body: BlocBuilder<ProfileBloc, ProfileState>(
          builder: (context, profile) {
            final isLoggedIn = profile.isLoggedIn;
            return ListView(
              children: [
                if (isLoggedIn) ...[
                  const _SectionHeader('계정'),
                  _Row(label: '이메일', value: _maskEmail(profile.user?.email ?? '')),
                  const _Divider(),
                  _Row(
                    label: '로그인 방식',
                    value: _providerLabel(profile.loginProvider),
                  ),
                ],
                const _SectionHeader('정보'),
                _NavRow(
                  label: '공지사항',
                  onTap: () => _openWeb(context, '공지사항', _noticeUrl),
                ),
                const _Divider(),
                _NavRow(
                  label: '이용약관',
                  onTap: () => _openWeb(context, '이용약관', _termsUrl),
                ),
                const _Divider(),
                _NavRow(
                  label: '개인정보 처리방침',
                  onTap: () => _openWeb(context, '개인정보 처리방침', _privacyUrl),
                ),
                if (isLoggedIn) ...[
                  const _SectionHeader('알림'),
                  const _NotificationToggles(),
                  const _SectionHeader('차단'),
                  _NavRow(
                    label: '차단 목록 관리',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BlocProvider(
                          create: (_) =>
                              BlockListBloc(repository: blockRepository)
                                ..add(const BlockListStarted()),
                          child: const BlockListPage(),
                        ),
                      ),
                    ),
                  ),
                  const _SectionHeader('계정 관리'),
                  _NavRow(
                    label: '로그아웃',
                    onTap: () => _confirmLogout(context),
                  ),
                  const _Divider(),
                  _NavRow(
                    label: '회원탈퇴',
                    color: _danger,
                    onTap: () => _confirmDeleteAccount(context),
                  ),
                ],
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    '봤냥 v$_appVersion',
                    style: TextStyle(fontSize: 11, color: Color(0xFFCCCCCC)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openWeb(BuildContext context, String title, String url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => WebPage(title: title, url: url)),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final bloc = context.read<ProfileBloc>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('로그아웃', style: TextStyle(color: _danger)),
          ),
        ],
      ),
    );
    if (ok == true) bloc.add(const ProfileLogoutConfirmed());
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final bloc = context.read<ProfileBloc>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('회원탈퇴'),
        content: const Text('탈퇴하면 모든 데이터가 삭제되며 복구할 수 없습니다. 정말 탈퇴하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('탈퇴하기', style: TextStyle(color: _danger)),
          ),
        ],
      ),
    );
    if (ok == true) bloc.add(const ProfileDeleteAccountConfirmed());
  }

  /// 이메일 가리기 — 앞 세 글자만 남긴다. iOS 와 같은 규칙이다.
  static String _maskEmail(String email) {
    final at = email.indexOf('@');
    if (at < 0) return email;
    final prefix = email.substring(0, at);
    if (prefix.length <= 3) return email;
    return '${prefix.substring(0, 3)}***${email.substring(at)}';
  }

  static String _providerLabel(AuthProvider? provider) {
    return switch (provider) {
      AuthProvider.kakao => '카카오',
      AuthProvider.apple => 'Apple',
      null => '-',
    };
  }
}

class _NotificationToggles extends StatelessWidget {
  const _NotificationToggles();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        final bloc = context.read<SettingsBloc>();
        return Column(
          children: [
            SwitchListTile(
              title: const Text('좋아요 알림'),
              value: state.settings.likeEnabled,
              onChanged: (v) => bloc
                  .add(SettingsNotificationToggled(NotificationKind.like, v)),
            ),
            const _Divider(),
            SwitchListTile(
              title: const Text('저도 봤어요 알림'),
              value: state.settings.confirmationEnabled,
              onChanged: (v) => bloc.add(
                  SettingsNotificationToggled(NotificationKind.confirmation, v)),
            ),
            const _Divider(),
            SwitchListTile(
              title: const Text('댓글 알림'),
              value: state.settings.commentEnabled,
              onChanged: (v) => bloc
                  .add(SettingsNotificationToggled(NotificationKind.comment, v)),
            ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF888888),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 15)),
      trailing: Text(
        value,
        style: const TextStyle(fontSize: 14, color: Color(0xFF888888)),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.label, required this.onTap, this.color});

  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: TextStyle(fontSize: 15, color: color)),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFFCCCCCC)),
      onTap: onTap,
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 16, endIndent: 16);
  }
}
