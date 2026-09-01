import 'package:flutter/material.dart';

import '../../../domain/models/shelter_animal.dart';

/// 유기동물 카드. iOS 의 `ShelterAnimalCard` 와 같다 —
/// 4:5 사진 위에 상태 표식, 아래에 품종·성별·나이·지역.
class ShelterAnimalCard extends StatelessWidget {
  const ShelterAnimalCard({
    super.key,
    required this.animal,
    required this.regionLabel,
    required this.onTap,
  });

  final ShelterAnimal animal;
  final String regionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = [animal.sex.label, animal.age]
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _Photo(url: animal.imageUrl),
                ),
                Positioned(top: 6, left: 6, child: _StateChip(animal: animal)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            animal.kind,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          if (meta.isNotEmpty)
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
            ),
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 11, color: Color(0xFFAAAAAA)),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  regionLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final value = url;
    if (value == null) return const _PhotoPlaceholder();
    // 받는 동안에도 자리가 비지 않도록 회색 바탕을 깔아둔다.
    // 바탕이 없으면 사진이 뜨기 전까지 카드에 구멍이 뚫린 것처럼 보인다.
    return Stack(
      fit: StackFit.expand,
      children: [
        const _PhotoPlaceholder(),
        Image.network(
          value,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF2F2F2),
      child: Icon(Icons.pets, size: 28, color: Color(0xFFCCCCCC)),
    );
  }
}

/// 공고 종료가 임박했으면 그걸 먼저 보여주고, 아니면 보호 상태를 보여준다.
/// iOS 와 같은 우선순위다.
class _StateChip extends StatelessWidget {
  const _StateChip({required this.animal});

  final ShelterAnimal animal;

  @override
  Widget build(BuildContext context) {
    final imminent = animal.imminentEndLabel;
    if (imminent != null) {
      return _chip(imminent, const Color(0xFFD32F2F), emphasized: true);
    }

    final kind = animal.processStateKind;
    final color = switch (kind) {
      ProcessStateKind.protecting => const Color(0xFF2E7D32),
      ProcessStateKind.noticing => const Color(0xFFE65100),
      ProcessStateKind.treating => const Color(0xFFF9A825),
      ProcessStateKind.other => null,
    };
    if (color == null || kind.label.isEmpty) return const SizedBox.shrink();
    return _chip(kind.label, color);
  }

  Widget _chip(String text, Color color, {bool emphasized = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: emphasized ? color : color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
