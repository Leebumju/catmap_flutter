import 'package:equatable/equatable.dart';

import '../../../domain/models/coordinate.dart';
import '../../../domain/models/earned_badge.dart';
import '../../../domain/models/sighting.dart';

/// 화면이 한 번만 반응해야 하는 신호.
enum MapSignal {
  /// 위치 권한이 거부됨
  locationDenied,

  /// 목격 기록 조회 실패
  loadFailed,
}

/// 지도를 특정 좌표로 옮기라는 요청.
///
/// 좌표만 두면 같은 좌표로 두 번 옮길 수 없다(상태가 안 바뀌어서 화면이 반응하지
/// 않는다). iOS 가 `locateTrigger` 를 토글하던 것과 같은 이유로 일련번호를 붙인다.
class MapMoveRequest extends Equatable {
  const MapMoveRequest({required this.coordinate, required this.sequence});

  final Coordinate coordinate;
  final int sequence;

  @override
  List<Object?> get props => [coordinate, sequence];
}

class MapPageState extends Equatable {
  const MapPageState({
    this.userLocation,
    this.sightings = const [],
    this.selectedSighting,
    this.mapCenter,
    this.moveRequest,
    this.searchText = '',
    this.showResearchButton = false,
    this.isLoading = false,
    this.unlockedBadges = const [],
    this.signal,
  });

  /// 조회 반경. iOS 와 같은 5km.
  static const searchRadiusMeters = 5000.0;

  /// 지도 중심이 이만큼(위도+경도 절대값 합) 움직이면 재검색 버튼을 띄운다.
  /// iOS 와 같은 값이고, 대략 200m 에 해당한다.
  static const researchThreshold = 0.002;

  /// 조회를 이 간격 안에 다시 하지 않는다. iOS 와 같은 2초.
  static const fetchThrottle = Duration(seconds: 2);

  final Coordinate? userLocation;
  final List<Sighting> sightings;

  /// 마커를 눌러 띄운 팝업의 대상.
  final Sighting? selectedSighting;

  final Coordinate? mapCenter;
  final MapMoveRequest? moveRequest;
  final String searchText;
  final bool showResearchButton;
  final bool isLoading;

  /// 새로 딴 칭호. 비어 있지 않으면 축하 창을 띄운다.
  final List<EarnedBadge> unlockedBadges;

  final MapSignal? signal;

  MapPageState copyWith({
    Coordinate? userLocation,
    List<Sighting>? sightings,
    Sighting? selectedSighting,
    Coordinate? mapCenter,
    MapMoveRequest? moveRequest,
    String? searchText,
    bool? showResearchButton,
    bool? isLoading,
    List<EarnedBadge>? unlockedBadges,
    MapSignal? signal,
    bool clearSelectedSighting = false,
    bool clearSignal = false,
  }) {
    return MapPageState(
      userLocation: userLocation ?? this.userLocation,
      sightings: sightings ?? this.sightings,
      selectedSighting: clearSelectedSighting
          ? null
          : (selectedSighting ?? this.selectedSighting),
      mapCenter: mapCenter ?? this.mapCenter,
      moveRequest: moveRequest ?? this.moveRequest,
      searchText: searchText ?? this.searchText,
      showResearchButton: showResearchButton ?? this.showResearchButton,
      isLoading: isLoading ?? this.isLoading,
      unlockedBadges: unlockedBadges ?? this.unlockedBadges,
      signal: clearSignal ? null : (signal ?? this.signal),
    );
  }

  @override
  List<Object?> get props => [
        userLocation,
        sightings,
        selectedSighting,
        mapCenter,
        moveRequest,
        searchText,
        showResearchButton,
        isLoading,
        unlockedBadges,
        signal,
      ];
}
