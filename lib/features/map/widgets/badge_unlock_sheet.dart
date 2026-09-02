import 'package:flutter/material.dart' hide Badge;

import '../../../domain/models/earned_badge.dart';
import '../../profile/profile_page.dart' show BadgeChip;

/// 칭호를 새로 땄을 때 뜨는 축하 창. iOS 의 `BadgeUnlockModalView` 와 같다.
///
/// 이 창은 서버를 부르지 않는다. 닫힌 뒤 "마지막으로 본 시각" 을 올리는 건
/// 지도 쪽 몫이다 — iOS 도 같은 방식으로 나눠 뒀다.
Future<void> showBadgeUnlockSheet({
  required BuildContext context,
  required List<EarnedBadge> badges,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _BadgeUnlockSheet(badges: badges),
  );
}

class _BadgeUnlockSheet extends StatelessWidget {
  const _BadgeUnlockSheet({required this.badges});

  final List<EarnedBadge> badges;

  @override
  Widget build(BuildContext context) {
    final subtitle = badges.length == 1
        ? '새로운 칭호를 획득했어요'
        : '새로운 칭호 ${badges.length}개를 획득했어요';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 8),
            const Text(
              '축하합니다!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 14, color: Color(0xFF888888)),
            ),
            const SizedBox(height: 24),
            for (final earned in badges)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  children: [
                    BadgeChip(badge: earned.badge),
                    const SizedBox(height: 4),
                    Text(
                      earned.badge.conditionDescription,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE8734A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
