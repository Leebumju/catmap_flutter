import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/models/nearby_place.dart';

/// 장소 한 줄. iOS 의 `NearbyPlaceCard` 와 같은 내용이다 —
/// 이름, 분류·거리, 도로명 주소, 그리고 전화·길찾기 버튼.
class NearbyPlaceCard extends StatelessWidget {
  const NearbyPlaceCard({
    super.key,
    required this.place,
    required this.isSelected,
    required this.onTap,
  });

  final NearbyPlace place;
  final bool isSelected;
  final VoidCallback onTap;

  static const _accent = Color(0xFFE8734A);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected ? _accent.withValues(alpha: 0.06) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              place.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              '${place.category} · ${place.distanceText}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
            ),
            if (place.roadAddress.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                place.roadAddress,
                style: const TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (place.phone.isNotEmpty)
                  _ActionButton(
                    icon: Icons.call,
                    label: '전화',
                    color: const Color(0xFF2E7D32),
                    onPressed: () => _call(place.phone),
                  ),
                if (place.phone.isNotEmpty) const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.directions,
                  label: '길찾기',
                  color: const Color(0xFF555555),
                  onPressed: () => _openDirections(place),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _call(String phone) async {
    final cleaned = phone.replaceAll('-', '').trim();
    if (cleaned.isEmpty) return;
    final uri = Uri.parse('tel:$cleaned');
    await launchUrl(uri);
  }

  /// 길찾기. iOS 는 애플 지도를 열지만 안드로이드에는 없어서,
  /// 안드로이드 표준인 `geo:` 주소로 연다 — 기기에 깔린 지도 앱이 받는다.
  Future<void> _openDirections(NearbyPlace place) async {
    final label = Uri.encodeComponent(place.name);
    final uri = Uri.parse(
      'geo:${place.latitude},${place.longitude}?q=${place.latitude},${place.longitude}($label)',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    // 지도 앱이 없으면 브라우저 지도로 넘긴다.
    await launchUrl(
      Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${place.latitude},${place.longitude}',
      ),
      mode: LaunchMode.externalApplication,
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14, color: color),
      label: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: color.withValues(alpha: 0.3)),
        shape: const StadiumBorder(),
      ),
    );
  }
}
