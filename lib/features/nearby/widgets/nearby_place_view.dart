import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../domain/models/coordinate.dart';
import '../../map/widgets/osm_map.dart';
import '../bloc/nearby_place_bloc.dart';
import 'nearby_place_card.dart';

/// 동물병원·펫샵 화면. 지도 위에 목록 시트가 올라간 구조로, iOS 와 같다.
class NearbyPlaceView extends StatefulWidget {
  const NearbyPlaceView({super.key, required this.emptyKindLabel});

  /// 결과가 없을 때 문구에 넣을 말 ("동물병원" / "펫샵").
  final String emptyKindLabel;

  @override
  State<NearbyPlaceView> createState() => _NearbyPlaceViewState();
}

class _NearbyPlaceViewState extends State<NearbyPlaceView> {
  final _mapController = MapController();
  Coordinate? _movedTo;

  static const _accent = Color(0xFFE8734A);

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NearbyPlaceBloc, NearbyPlaceState>(
      builder: (context, state) {
        final center = state.coordinate;
        if (center == null) {
          return const Center(child: CircularProgressIndicator());
        }

        // 기준 좌표가 바뀌면(재검색·반경 변경) 지도를 그 자리로 옮긴다.
        if (_movedTo != center) {
          _movedTo = center;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _mapController.move(
                LatLng(center.latitude, center.longitude),
                15,
              );
            }
          });
        }

        return Stack(
          children: [
            OsmMap(
              controller: _mapController,
              initialCenter: center,
              markers: _markers(context, state),
              onPositionChanged: (c, hasGesture) {
                if (!hasGesture) return;
                context.read<NearbyPlaceBloc>().add(NearbyPlaceMapMoved(c));
              },
            ),
            if (state.showResearchButton)
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: _ResearchButton(
                    onPressed: () => context
                        .read<NearbyPlaceBloc>()
                        .add(const NearbyPlaceResearchHereRequested()),
                  ),
                ),
              ),
            _PlaceSheet(state: state, emptyKindLabel: widget.emptyKindLabel),
          ],
        );
      },
    );
  }

  List<Marker> _markers(BuildContext context, NearbyPlaceState state) {
    return state.places.map((place) {
      final isSelected = state.selectedPlaceId == place.id;
      return Marker(
        point: LatLng(place.latitude, place.longitude),
        width: 32,
        height: 32,
        child: GestureDetector(
          onTap: () =>
              context.read<NearbyPlaceBloc>().add(NearbyPlaceSelected(place.id)),
          child: Icon(
            Icons.place,
            size: isSelected ? 32 : 26,
            color: isSelected ? _accent : const Color(0xFF777777),
          ),
        ),
      );
    }).toList();
  }
}

class _ResearchButton extends StatelessWidget {
  const _ResearchButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE8734A),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE8734A).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh, size: 12, color: Colors.white),
            SizedBox(width: 6),
            Text(
              '이 지역에서 재검색',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 아래에서 끌어올리는 목록. iOS 의 detent 시트와 같은 역할이다.
class _PlaceSheet extends StatelessWidget {
  const _PlaceSheet({required this.state, required this.emptyKindLabel});

  final NearbyPlaceState state;
  final String emptyKindLabel;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.3,
      minChildSize: 0.15,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _SheetHeader(state: state),
              const Divider(height: 1),
              Expanded(child: _body(context, scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, ScrollController controller) {
    if (state.isLoading && state.places.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.hasError && state.places.isEmpty) {
      return _Retry(
        onRetry: () => context
            .read<NearbyPlaceBloc>()
            .add(const NearbyPlaceRetryRequested()),
      );
    }
    if (state.places.isEmpty) {
      return _Empty(state: state, kindLabel: emptyKindLabel);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // 끝에 가까워지면 다음 쪽을 받는다.
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 200) {
          context
              .read<NearbyPlaceBloc>()
              .add(const NearbyPlaceLoadMoreRequested());
        }
        return false;
      },
      child: ListView.separated(
        controller: controller,
        itemCount: state.places.length + (state.isLoading ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= state.places.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final place = state.places[index];
          return NearbyPlaceCard(
            place: place,
            isSelected: state.selectedPlaceId == place.id,
            onTap: () => context
                .read<NearbyPlaceBloc>()
                .add(NearbyPlaceSelected(place.id)),
          );
        },
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.state});

  final NearbyPlaceState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          _RadiusDropdown(
            radiusMeters: state.radiusMeters,
            onChanged: (value) => context
                .read<NearbyPlaceBloc>()
                .add(NearbyPlaceRadiusChanged(value)),
          ),
          const Spacer(),
          Text(
            '${state.places.length}곳',
            style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
          ),
        ],
      ),
    );
  }
}

class _RadiusDropdown extends StatelessWidget {
  const _RadiusDropdown({required this.radiusMeters, required this.onChanged});

  final int radiusMeters;
  final ValueChanged<int> onChanged;

  /// 1000 → "1km". iOS 의 `RadiusDropdown.label` 과 같은 규칙이다.
  static String label(int meters) {
    if (meters < 1000) return '${meters}m';
    final km = meters / 1000;
    return km == km.roundToDouble()
        ? '${km.round()}km'
        : '${km.toStringAsFixed(1)}km';
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      initialValue: radiusMeters,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in NearbyPlaceState.radiusOptions)
          PopupMenuItem(value: option, child: Text(label(option))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label(radiusMeters),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 16),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.state, required this.kindLabel});

  final NearbyPlaceState state;
  final String kindLabel;

  @override
  Widget build(BuildContext context) {
    // 다음으로 큰 반경을 제안한다. iOS 와 같은 안내다.
    final next = NearbyPlaceState.radiusOptions
        .where((r) => r > state.radiusMeters)
        .firstOrNull;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 40, color: Color(0xFFCCCCCC)),
            const SizedBox(height: 14),
            Text(
              '주변 ${_RadiusDropdown.label(state.radiusMeters)} 안에 $kindLabel이 없어요',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF888888)),
            ),
            if (next != null) ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => context
                    .read<NearbyPlaceBloc>()
                    .add(NearbyPlaceRadiusChanged(next)),
                child: Text('반경 늘리기 (${_RadiusDropdown.label(next)})'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '주변 정보를 불러오지 못했어요',
            style: TextStyle(fontSize: 14, color: Color(0xFF888888)),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
