import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/nearby_place.dart';
import 'bloc/nearby_bloc.dart';
import 'bloc/nearby_place_bloc.dart';
import 'widgets/nearby_place_view.dart';
import 'widgets/shelter_animal_view.dart';

/// 둘러보기 탭. iOS 의 `NearbyView` 와 같은 구성이다 —
/// 제목, 세 갈래 선택, 내용, 그리고 아래에 위치 기준 표시.
class NearbyPage extends StatelessWidget {
  const NearbyPage({super.key});

  static const _accent = Color(0xFFE8734A);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NearbyBloc, NearbyState>(
      listenWhen: (prev, curr) => prev.coordinate != curr.coordinate,
      listener: (context, state) {
        final coordinate = state.coordinate;
        if (coordinate == null) return;
        // 위치가 정해지면 두 목록에 기준점을 알려준다.
        context
            .read<HospitalPlaceBloc>()
            .add(NearbyPlaceLoadRequested(coordinate));
        context
            .read<PetShopPlaceBloc>()
            .add(NearbyPlaceLoadRequested(coordinate));
      },
      builder: (context, state) {
        return SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Text(
                      '둘러보기',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _CategorySegment(selected: state.selectedCategory),
              const Divider(height: 1),
              Expanded(child: _content(context, state)),
              // 유기동물은 자체 지역 선택이 있어서 위치 기준 줄을 숨긴다. iOS 와 같다.
              if (state.address != null &&
                  state.selectedCategory != NearbyCategory.shelterAnimal)
                _LocationBasisBar(address: state.address!),
            ],
          ),
        );
      },
    );
  }

  Widget _content(BuildContext context, NearbyState state) {
    // 유기동물은 위치 권한이 없어도 지역을 골라 볼 수 있다. iOS 와 같은 예외다.
    if (state.locationDenied &&
        state.selectedCategory != NearbyCategory.shelterAnimal) {
      return const _LocationDenied();
    }
    if (state.isLocating && state.coordinate == null) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (state.selectedCategory) {
      case NearbyCategory.animalHospital:
        return BlocProvider<NearbyPlaceBloc>.value(
          value: context.read<HospitalPlaceBloc>(),
          child: const NearbyPlaceView(emptyKindLabel: '동물병원'),
        );
      case NearbyCategory.petShop:
        return BlocProvider<NearbyPlaceBloc>.value(
          value: context.read<PetShopPlaceBloc>(),
          child: const NearbyPlaceView(emptyKindLabel: '펫샵'),
        );
      case NearbyCategory.shelterAnimal:
        return const ShelterAnimalView();
    }
  }
}

/// 동물병원과 펫샵은 같은 bloc 을 쓰는데 검색어만 다르다.
/// 한 화면에 둘을 동시에 두려면 타입이 달라야 해서 이름만 다른 두 종류로 나눈다.
class HospitalPlaceBloc extends NearbyPlaceBloc {
  HospitalPlaceBloc({required super.repository})
      : super(query: NearbyCategory.animalHospital.searchQuery);
}

class PetShopPlaceBloc extends NearbyPlaceBloc {
  PetShopPlaceBloc({required super.repository})
      : super(query: NearbyCategory.petShop.searchQuery);
}

class _CategorySegment extends StatelessWidget {
  const _CategorySegment({required this.selected});

  final NearbyCategory selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          for (final category in NearbyCategory.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => context
                    .read<NearbyBloc>()
                    .add(NearbyCategorySelected(category)),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected == category
                        ? const Color(0xFF222222)
                        : const Color(0xFFF2F2F2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    category.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected == category
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: selected == category
                          ? Colors.white
                          : const Color(0xFF666666),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LocationBasisBar extends StatelessWidget {
  const _LocationBasisBar({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF7F7F7),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.my_location, size: 11, color: NearbyPage._accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$address 기준',
              style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
            ),
          ),
          GestureDetector(
            onTap: () =>
                context.read<NearbyBloc>().add(const NearbyRefreshRequested()),
            child: const Icon(Icons.refresh, size: 14, color: Color(0xFF888888)),
          ),
        ],
      ),
    );
  }
}

class _LocationDenied extends StatelessWidget {
  const _LocationDenied();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off, size: 48, color: Color(0xFFAAAAAA)),
            const SizedBox(height: 16),
            const Text(
              '위치 권한이 필요합니다',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF555555),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '주변 정보를 보려면 위치 권한을 허용해주세요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFFAAAAAA)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  context.read<NearbyBloc>().add(const NearbyRefreshRequested()),
              style: FilledButton.styleFrom(backgroundColor: NearbyPage._accent),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}
