import 'package:equatable/equatable.dart';

import '../../../domain/models/coordinate.dart';
import '../../../domain/models/sighting.dart';

sealed class MapEvent extends Equatable {
  const MapEvent();

  @override
  List<Object?> get props => [];
}

/// 화면 진입 — 위치 권한을 묻고, 허용되면 현재 위치부터 잡는다.
final class MapStarted extends MapEvent {
  const MapStarted();
}

/// 지도 이동이 끝났다. 중심이 충분히 움직였으면 "이 위치에서 검색" 버튼이 뜬다.
final class MapMoved extends MapEvent {
  const MapMoved(this.center);

  final Coordinate center;

  @override
  List<Object?> get props => [center];
}

/// "이 위치에서 검색"
final class MapResearchHereRequested extends MapEvent {
  const MapResearchHereRequested();
}

/// 내 위치 버튼
final class MapLocateRequested extends MapEvent {
  const MapLocateRequested();
}

/// 검색에서 장소를 고름 — 그 좌표로 지도를 옮기고 다시 조회한다.
final class MapPlaceSelected extends MapEvent {
  const MapPlaceSelected(this.coordinate, this.name);

  final Coordinate coordinate;
  final String name;

  @override
  List<Object?> get props => [coordinate, name];
}

final class MapMarkerTapped extends MapEvent {
  const MapMarkerTapped(this.sighting);

  final Sighting sighting;

  @override
  List<Object?> get props => [sighting];
}

final class MapPopupDismissed extends MapEvent {
  const MapPopupDismissed();
}

/// 업로드가 끝났다 — 새 글을 지도에 반영하기 위해 다시 조회한다.
final class MapUploadCompleted extends MapEvent {
  const MapUploadCompleted();
}

final class MapSignalConsumed extends MapEvent {
  const MapSignalConsumed();
}
