import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/shelter_animal.dart';
import '../../ad/native_ad_slot.dart';
import '../bloc/shelter_animal_bloc.dart';
import '../shelter_animal_detail_page.dart';
import 'shelter_animal_card.dart';

/// 유기동물 목록. iOS 의 `ShelterAnimalGridView` 와 같은 구성이다 —
/// 위에 지역·종 필터, 아래에 2열 격자.
class ShelterAnimalView extends StatelessWidget {
  const ShelterAnimalView({super.key});

  /// 광고 하나가 들어가는 묶음 크기. iOS 와 같은 6장(2열 × 3줄)이다.
  static const _groupSize = 6;

  static int _groupCount(ShelterAnimalState state) =>
      (state.animals.length + _groupSize - 1) ~/ _groupSize;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShelterAnimalBloc, ShelterAnimalState>(
      builder: (context, state) {
        return Column(
          children: [
            _RegionBar(state: state),
            _KindFilter(state: state),
            if (state.locationMappingFallback)
              const _FallbackNotice(),
            const Divider(height: 1),
            Expanded(child: _body(context, state)),
          ],
        );
      },
    );
  }

  Widget _body(BuildContext context, ShelterAnimalState state) {
    if (state.isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.hasError && state.animals.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '유기동물 정보를 불러오지 못했어요',
              style: TextStyle(fontSize: 14, color: Color(0xFF888888)),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context
                  .read<ShelterAnimalBloc>()
                  .add(const ShelterAnimalRefreshRequested()),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    if (state.animals.isEmpty) {
      return const Center(
        child: Text(
          '이 지역에 보호 중인 동물이 없어요',
          style: TextStyle(fontSize: 14, color: Color(0xFF888888)),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => context
          .read<ShelterAnimalBloc>()
          .add(const ShelterAnimalRefreshRequested()),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >=
              notification.metrics.maxScrollExtent - 300) {
            context
                .read<ShelterAnimalBloc>()
                .add(const ShelterAnimalLoadMoreRequested());
          }
          return false;
        },
        // 6장(2열 × 3줄)씩 묶고, 다 찬 묶음 뒤에만 광고를 넣는다. iOS 와 같은 규칙이다.
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _groupCount(state) + (state.isLoadingMore ? 1 : 0),
          itemBuilder: (context, groupIndex) {
            if (groupIndex >= _groupCount(state)) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final start = groupIndex * _groupSize;
            final end = (start + _groupSize).clamp(0, state.animals.length);
            final group = state.animals.sublist(start, end);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.62,
                  ),
                  itemCount: group.length,
                  itemBuilder: (context, index) {
                    final animal = group[index];
                    return ShelterAnimalCard(
                      animal: animal,
                      regionLabel: state.regionLabel,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ShelterAnimalDetailPage(animal: animal),
                        ),
                      ),
                    );
                  },
                ),
                // 6장이 다 찬 묶음 뒤에만. 마지막 덜 찬 묶음에는 안 붙인다.
                if (group.length == _groupSize) const NativeAdSlot(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RegionBar extends StatelessWidget {
  const _RegionBar({required this.state});

  final ShelterAnimalState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _openRegionPicker(context),
              child: Row(
                children: [
                  const Icon(Icons.place, size: 14, color: Color(0xFFE8734A)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      state.regionLabel,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, size: 18),
                ],
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => context
                .read<ShelterAnimalBloc>()
                .add(const ShelterAnimalUseMyLocationRequested()),
            icon: const Icon(Icons.my_location, size: 14),
            label: const Text('내 위치', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _openRegionPicker(BuildContext context) async {
    final bloc = context.read<ShelterAnimalBloc>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: const _RegionPickerSheet(),
      ),
    );
  }
}

/// 시도·시군구를 고르는 시트. iOS 의 `RegionPickerSheet` 와 같다.
class _RegionPickerSheet extends StatelessWidget {
  const _RegionPickerSheet();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShelterAnimalBloc, ShelterAnimalState>(
      builder: (context, state) {
        final bloc = context.read<ShelterAnimalBloc>();
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '지역 선택',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                ListTile(
                  title: const Text('전국'),
                  trailing: state.selectedSido == null
                      ? const Icon(Icons.check, color: Color(0xFFE8734A))
                      : null,
                  onTap: () {
                    bloc.add(const ShelterAnimalSidoSelected(null));
                    Navigator.of(context).pop();
                  },
                ),
                const Divider(height: 1),
                for (final sido in state.sidoList)
                  ListTile(
                    title: Text(sido.name),
                    trailing: state.selectedSido?.id == sido.id
                        ? const Icon(Icons.check, color: Color(0xFFE8734A))
                        : null,
                    onTap: () => bloc.add(ShelterAnimalSidoSelected(sido)),
                  ),
                if (state.sigunguList.isNotEmpty) ...[
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      '시·군·구',
                      style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
                    ),
                  ),
                  ListTile(
                    title: const Text('전체'),
                    trailing: state.selectedSigungu == null
                        ? const Icon(Icons.check, color: Color(0xFFE8734A))
                        : null,
                    onTap: () {
                      bloc.add(const ShelterAnimalSigunguSelected(null));
                      Navigator.of(context).pop();
                    },
                  ),
                  for (final sigungu in state.sigunguList)
                    ListTile(
                      title: Text(sigungu.name),
                      trailing: state.selectedSigungu?.id == sigungu.id
                          ? const Icon(Icons.check, color: Color(0xFFE8734A))
                          : null,
                      onTap: () {
                        bloc.add(ShelterAnimalSigunguSelected(sigungu));
                        Navigator.of(context).pop();
                      },
                    ),
                ],
                const SizedBox(height: 24),
              ],
            );
          },
        );
      },
    );
  }
}

class _KindFilter extends StatelessWidget {
  const _KindFilter({required this.state});

  final ShelterAnimalState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ShelterAnimalBloc>();

    Widget chip(String label, ShelterAnimalKind? kind) {
      final selected = state.selectedKind == kind;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => bloc.add(ShelterAnimalKindSelected(kind)),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          chip('전체', null),
          for (final kind in ShelterAnimalKind.values) chip(kind.label, kind),
        ],
      ),
    );
  }
}

/// 위치를 시도로 못 바꿨을 때의 안내.
class _FallbackNotice extends StatelessWidget {
  const _FallbackNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF8E1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Text(
        '현재 위치를 지역으로 바꾸지 못해 서울특별시로 보여드려요. 위에서 지역을 바꿀 수 있어요.',
        style: TextStyle(fontSize: 12, color: Color(0xFF8D6E00)),
      ),
    );
  }
}
