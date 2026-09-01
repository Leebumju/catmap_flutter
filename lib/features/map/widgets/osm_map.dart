import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../domain/models/coordinate.dart';

/// OpenStreetMap 타일을 쓰는 지도. 지도 SDK 를 갈아끼울 때 바꾸는 파일은 여기 하나다.
///
/// iOS 는 MapKit 을 쓰는데 안드로이드에는 없다. 구글·네이버 지도는 API 키와 결제
/// 계정이 필요해서, 키 없이 되는 OSM 으로 갔다.
///
/// 주의: OSM 공개 타일 서버는 무료지만 대량 사용을 금지한다
/// (https://operations.osmfoundation.org/policies/tiles/).
/// 사용자가 늘면 타일 서버를 자체 호스팅하거나 상용 지도로 옮겨야 한다.
class OsmMap extends StatelessWidget {
  const OsmMap({
    super.key,
    required this.controller,
    required this.initialCenter,
    this.initialZoom = 15,
    this.markers = const [],
    this.onPositionChanged,
    this.onMapReady,
  });

  /// 타일 요청에 붙는 식별자. OSM 정책상 앱을 알아볼 수 있어야 한다.
  static const userAgentPackageName = 'com.bumjun.catmap';

  static const tileUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  final MapController controller;
  final Coordinate initialCenter;
  final double initialZoom;
  final List<Marker> markers;

  /// 지도 이동이 끝났을 때 중심 좌표. [hasGesture] 는 사용자가 직접 움직였는지다.
  final void Function(Coordinate center, bool hasGesture)? onPositionChanged;

  final VoidCallback? onMapReady;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: LatLng(initialCenter.latitude, initialCenter.longitude),
        initialZoom: initialZoom,
        onMapReady: onMapReady,
        onPositionChanged: (camera, hasGesture) {
          onPositionChanged?.call(
            Coordinate(
              latitude: camera.center.latitude,
              longitude: camera.center.longitude,
            ),
            hasGesture,
          );
        },
      ),
      children: [
        TileLayer(
          urlTemplate: tileUrlTemplate,
          userAgentPackageName: userAgentPackageName,
        ),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
      ],
    );
  }
}
