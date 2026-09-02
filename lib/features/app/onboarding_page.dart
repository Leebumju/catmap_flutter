import 'package:flutter/material.dart';

/// 첫 실행 안내. iOS 의 `OnboardingView` 와 같은 세 장이다.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;

  static const _accent = Color(0xFFE8734A);

  static const _pages = [
    (
      icon: Icons.pets,
      title: '우리 동네 길고양이를\n발견하세요',
      description: '주변의 길고양이 목격 기록을\n지도에서 확인할 수 있어요',
    ),
    (
      icon: Icons.photo_camera,
      title: '사진을 찍고\n위치를 공유하세요',
      description: '길고양이를 발견하면\n사진과 위치를 기록해 보세요',
    ),
    (
      icon: Icons.visibility,
      title: '목격을 확인하고\n신뢰를 높여요',
      description: "다른 사람의 목격 기록에\n'저도 봤어요'로 신뢰를 더해요",
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _page == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (index) => setState(() => _page = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(page.icon, size: 52, color: _accent),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        page.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        page.description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF888888),
                          height: 1.5,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page
                            ? _accent
                            : _accent.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            // 시작 버튼은 마지막 장에서만 보인다. iOS 와 같다.
            SizedBox(
              height: 52,
              child: isLastPage
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: widget.onFinished,
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '시작하기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
