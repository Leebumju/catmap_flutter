import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/models/shelter_animal.dart';

/// 유기동물 상세. iOS 의 `ShelterAnimalDetailView` 와 같은 항목을 보여준다.
class ShelterAnimalDetailPage extends StatelessWidget {
  const ShelterAnimalDetailPage({super.key, required this.animal});

  final ShelterAnimal animal;

  @override
  Widget build(BuildContext context) {
    final imminent = animal.imminentEndLabel;

    return Scaffold(
      appBar: AppBar(title: Text(animal.kind)),
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 사진을 받는 동안에도 빈 화면이 아니라 자리표시가 보이게 한다.
                const ColoredBox(
                  color: Color(0xFFF2F2F2),
                  child: Icon(Icons.pets, size: 48, color: Color(0xFFCCCCCC)),
                ),
                if (animal.imageUrl != null)
                  Image.network(
                    animal.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
          if (imminent != null)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFEBEE),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                '공고 종료가 임박했어요 — $imminent',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFD32F2F),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  animal.kind,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  [animal.sex.label, animal.age, animal.weight]
                      .where((s) => s.isNotEmpty)
                      .join(' · '),
                  style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
                ),
                const SizedBox(height: 20),
                _Row(label: '색상', value: animal.color),
                _Row(label: '중성화', value: _neuterText(animal.neuterYn)),
                _Row(
                  label: '공고기간',
                  value: _noticePeriod(animal),
                ),
                _Row(label: '발견장소', value: animal.happenPlace),
                if (animal.specialMark.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    '특징',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    animal.specialMark,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ],
                const SizedBox(height: 20),
                const Text(
                  '보호소',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                _Row(label: '이름', value: animal.shelterName),
                _Row(label: '주소', value: animal.shelterAddress),
                _Row(label: '전화', value: animal.shelterPhone),
                if (animal.shelterPhone.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _call(animal.shelterPhone),
                      icon: const Icon(Icons.call, size: 18),
                      label: const Text('보호소에 전화하기'),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 공공데이터의 중성화 표시(Y/N/U)를 사람 말로.
  static String _neuterText(String raw) {
    return switch (raw) {
      'Y' => '완료',
      'N' => '안 함',
      _ => '미상',
    };
  }

  /// "yyyyMMdd" 두 개를 "2026.01.01 ~ 2026.01.15" 로.
  static String _noticePeriod(ShelterAnimal animal) {
    final start = _formatDate(animal.noticeStartDate);
    final end = _formatDate(animal.noticeEndDate);
    if (start.isEmpty && end.isEmpty) return '';
    return '$start ~ $end';
  }

  static String _formatDate(String raw) {
    if (raw.length != 8) return raw;
    return '${raw.substring(0, 4)}.${raw.substring(4, 6)}.${raw.substring(6, 8)}';
  }

  static Future<void> _call(String phone) async {
    final cleaned = phone.replaceAll('-', '').trim();
    if (cleaned.isEmpty) return;
    await launchUrl(Uri.parse('tel:$cleaned'));
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
