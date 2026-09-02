import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 시작 화면. iOS 의 `SplashView` 와 같은 색·같은 구성이다.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  static const accent = Color(0xFFE8734A);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: accent,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Logo(),
            SizedBox(height: 20),
            Text(
              '봤냥',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 20),
            Text(
              '우리 동네 길고양이 지도',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Image.asset(
        'assets/cat-marker.png',
        width: 120,
        height: 120,
        fit: BoxFit.contain,
      ),
    );
  }
}

/// 업데이트해야 앱을 쓸 수 있는 화면. iOS 의 `ForceUpdateView` 와 같다.
class ForceUpdatePage extends StatelessWidget {
  const ForceUpdatePage({super.key});

  /// Play 스토어의 이 앱 페이지.
  static const _storeUrl =
      'https://play.google.com/store/apps/details?id=com.bumjun.catmap';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.system_update, size: 56, color: SplashPage.accent),
              const SizedBox(height: 20),
              const Text(
                '업데이트가 필요합니다',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text(
                '새로운 버전이 출시되었습니다.\n최신 버전으로 업데이트해주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF888888)),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => launchUrl(
                  Uri.parse(_storeUrl),
                  mode: LaunchMode.externalApplication,
                ),
                style: FilledButton.styleFrom(backgroundColor: SplashPage.accent),
                child: const Text('업데이트'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 점검 중 화면. iOS 의 `MaintenanceView` 와 같다.
class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.build_outlined, size: 56, color: SplashPage.accent),
              const SizedBox(height: 20),
              const Text(
                '시스템 점검 중',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                message ?? '더 나은 서비스를 위해 점검 중입니다.\n잠시 후 다시 시도해주세요.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF888888)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
