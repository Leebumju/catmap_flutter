import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/auth_provider.dart';
import 'bloc/auth_bloc.dart';
import 'bloc/auth_event.dart';
import 'bloc/auth_state.dart';
import 'web_page.dart';

/// 로그인 화면. iOS 의 `AuthView` 와 같은 구성이다.
///
/// 애플 로그인 버튼은 안드로이드에서 뺐다. 눌러도 되는 것처럼 보여주고
/// 안 되는 것보다, 아예 없는 편이 낫다.
class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  /// iOS 의 배경색 Color(red: 1.0, green: 0.95, blue: 0.93)
  static const _background = Color(0xFFFFF2ED);

  /// 카카오 노란색 Color(red: 0.996, green: 0.898, blue: 0.0)
  static const _kakaoYellow = Color(0xFFFEE500);

  static const _termsUrl = 'https://sambonge.tistory.com/2';
  static const _privacyUrl = 'https://sambonge.tistory.com/1';

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthPageState>(
      listenWhen: (prev, curr) => prev.signal != curr.signal,
      listener: (context, state) {
        final signal = state.signal;
        if (signal == null) return;
        final message = switch (signal) {
          AuthSignal.loginFailed => '로그인에 실패했습니다. 다시 시도해주세요.',
          AuthSignal.providerUnavailable => '안드로이드에서는 아직 지원하지 않는 로그인 방식입니다.',
        };
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
        context.read<AuthBloc>().add(const AuthSignalConsumed());
      },
      child: const Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Spacer(),
                _LogoSection(),
                Spacer(),
                _LoginButtons(),
                SizedBox(height: 16),
                _TermsText(termsUrl: _termsUrl, privacyUrl: _privacyUrl),
                SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoSection extends StatelessWidget {
  const _LogoSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            'assets/app-logo.png',
            width: 80,
            height: 80,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '봤냥',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '우리 동네 길고양이 지도',
          style: TextStyle(fontSize: 15, color: Colors.grey),
        ),
      ],
    );
  }
}

class _LoginButtons extends StatelessWidget {
  const _LoginButtons();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthPageState>(
      builder: (context, state) {
        return Column(
          children: [
            if (state.lastLoginProvider == AuthProvider.kakao)
              const _RecentLoginTooltip(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: state.isLaunching
                    ? null
                    : () => context
                        .read<AuthBloc>()
                        .add(const AuthLoginPressed(AuthProvider.kakao)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AuthPage._kakaoYellow,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: AuthPage._kakaoYellow,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: state.isLaunching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black54,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble, size: 18),
                          SizedBox(width: 8),
                          Text(
                            '카카오로 로그인하기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecentLoginTooltip extends StatelessWidget {
  const _RecentLoginTooltip();

  static const _color = Color(0xFFE8734A);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: const BoxDecoration(
            color: _color,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
          child: const Text(
            '최근 로그인',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
        CustomPaint(
          size: const Size(10, 5),
          painter: _TrianglePainter(),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

/// 말풍선 꼬리. iOS 의 `Triangle` Shape 과 같은 모양(아래를 향한 삼각형)이다.
class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _RecentLoginTooltip._color;
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TermsText extends StatelessWidget {
  const _TermsText({required this.termsUrl, required this.privacyUrl});

  final String termsUrl;
  final String privacyUrl;

  @override
  Widget build(BuildContext context) {
    const plain = TextStyle(fontSize: 12, color: Colors.grey);
    const link = TextStyle(
      fontSize: 12,
      color: Colors.grey,
      decoration: TextDecoration.underline,
      decorationColor: Colors.grey,
    );

    void open(String title, String url) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WebPage(title: title, url: url),
        ),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('시작하면 ', style: plain),
            GestureDetector(
              onTap: () => open('이용약관', termsUrl),
              child: const Text('서비스 이용약관', style: link),
            ),
            const Text(' 및', style: plain),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => open('개인정보 처리방침', privacyUrl),
              child: const Text('개인정보 처리방침', style: link),
            ),
            const Text('에 동의하는 것으로 간주합니다', style: plain),
          ],
        ),
      ],
    );
  }
}
