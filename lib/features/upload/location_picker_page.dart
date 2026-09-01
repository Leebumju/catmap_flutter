import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/models/coordinate.dart';
import '../../domain/repositories/location_repository.dart';
import '../map/widgets/address_search_sheet.dart';
import '../map/widgets/osm_map.dart';
import 'widgets/upload_colors.dart';

/// 위치 조정 화면. iOS 의 `LocationPickerView` 와 같다 —
/// 핀은 화면 중앙에 고정되어 있고, 지도를 움직여서 위치를 맞춘다.
///
/// 확인을 누르면 고른 좌표를 결과로 돌려주고 닫힌다.
class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({
    super.key,
    required this.initialCoordinate,
    required this.locationRepository,
  });

  final Coordinate initialCoordinate;
  final LocationRepository locationRepository;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final _mapController = MapController();
  late Coordinate _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialCoordinate;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _openSearch() async {
    final place = await showAddressSearchSheet(
      context: context,
      locationRepository: widget.locationRepository,
      around: _selected,
    );
    if (place == null || !mounted) return;
    setState(() => _selected = place.coordinate);
    _mapController.move(
      LatLng(place.coordinate.latitude, place.coordinate.longitude),
      16,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          OsmMap(
            controller: _mapController,
            initialCenter: widget.initialCoordinate,
            initialZoom: 16,
            onPositionChanged: (center, _) => _selected = center,
          ),
          // 중앙 고정 핀 — 지도를 움직여도 핀은 가운데 있다.
          const IgnorePointer(child: Center(child: _CenterPin())),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _RoundButton(
                    icon: Icons.close,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  const Text(
                    '위치 조정',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF222222),
                    ),
                  ),
                  const Spacer(),
                  _RoundButton(icon: Icons.search, onPressed: _openSearch),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UploadColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '이 위치로 설정',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

class _CenterPin extends StatelessWidget {
  const _CenterPin();

  @override
  Widget build(BuildContext context) {
    // 핀의 뾰족한 끝이 지도 중심에 오도록 아이콘 높이의 절반만큼 올린다.
    return Padding(
      padding: const EdgeInsets.only(bottom: 36),
      child: Icon(
        Icons.location_on,
        size: 44,
        color: UploadColors.accent,
        shadows: [
          Shadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF555555)),
      ),
    );
  }
}
