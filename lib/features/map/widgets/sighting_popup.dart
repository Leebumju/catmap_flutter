import 'package:flutter/material.dart';

import '../../../domain/models/sighting.dart';

/// 마커를 눌렀을 때 지도 아래에 뜨는 카드. iOS 의 `SightingPopup` 과 같다.
///
/// 주소는 게시물에 저장된 값을 쓴다 — 좌표를 다시 주소로 바꾸지 않는다(iOS 와 같다).
class SightingPopup extends StatelessWidget {
  const SightingPopup({
    super.key,
    required this.sighting,
    required this.onDismissed,
  });

  final Sighting sighting;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final address = sighting.displayAddress;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (address == null || address.isEmpty) ? '위치 확인 중...' : address,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF222222),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _timeAgo(sighting.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF888888)),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onDismissed,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0F0F0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close,
                      size: 11, color: Color(0xFF888888)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sighting.thumbnailUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) => _Thumbnail(
                url: sighting.thumbnailUrls[index],
                fallbackUrl: index < sighting.photoUrls.length
                    ? sighting.photoUrls[index]
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// iOS 의 timeAgo 와 같은 규칙 — 분, 시간, 일.
  String _timeAgo(DateTime date) {
    final minutes = DateTime.now().toUtc().difference(date.toUtc()).inMinutes;
    if (minutes < 60) return '$minutes분 전';
    final hours = minutes ~/ 60;
    if (hours < 24) return '$hours시간 전';
    return '${hours ~/ 24}일 전';
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url, this.fallbackUrl});

  final String url;
  final String? fallbackUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        // 썸네일이 아직 안 올라간 예전 게시물이 있다. 그럴 때 원본으로 되돌린다 —
        // iOS 가 alternativeSources 로 하던 것과 같다.
        errorBuilder: (context, _, __) {
          final fallback = fallbackUrl;
          if (fallback == null) return const _ThumbnailPlaceholder();
          return Image.network(
            fallback,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const _ThumbnailPlaceholder(),
          );
        },
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      color: const Color(0xFFF5F5F5),
      child: const Icon(Icons.pets, size: 20, color: Color(0xFFCCCCCC)),
    );
  }
}
