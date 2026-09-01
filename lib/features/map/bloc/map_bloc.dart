import 'dart:math' as math;

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/coordinate.dart';
import '../../../domain/models/sighting.dart';
import '../../../domain/repositories/location_repository.dart';
import '../../../domain/repositories/sighting_repository.dart';
import 'map_event.dart';
import 'map_state.dart';

/// 지도 화면. iOS 의 `MapFeature` 를 옮긴 것이다.
///
/// 칭호(뱃지) 달성 모달은 옮기지 않았다 — 이번 이식 범위(지도·업로드) 밖이다.
class MapBloc extends Bloc<MapEvent, MapPageState> {
  MapBloc({
    required LocationRepository locationRepository,
    required SightingRepository sightingRepository,
  })  : _location = locationRepository,
        _sightings = sightingRepository,
        super(const MapPageState()) {
    on<MapStarted>(_onStarted);
    on<MapMoved>(_onMoved);
    // 조회 요청은 앞의 것을 버리고 마지막 것만 살린다. 지도를 연달아 움직였을 때
    // 낡은 응답이 뒤늦게 도착해 화면을 되돌리는 일을 막는다.
    on<MapResearchHereRequested>(_onResearchHere, transformer: restartable());
    on<MapLocateRequested>(_onLocate, transformer: restartable());
    on<MapPlaceSelected>(_onPlaceSelected, transformer: restartable());
    on<MapUploadCompleted>(_onUploadCompleted, transformer: restartable());
    on<MapMarkerTapped>((e, emit) =>
        emit(state.copyWith(selectedSighting: e.sighting)));
    on<MapPopupDismissed>((e, emit) =>
        emit(state.copyWith(clearSelectedSighting: true)));
    on<MapSignalConsumed>((e, emit) => emit(state.copyWith(clearSignal: true)));
  }

  final LocationRepository _location;
  final SightingRepository _sightings;

  /// 마지막 조회 시각. 쓰로틀 판정에 쓴다.
  DateTime? _lastFetch;

  /// 지도 이동 요청 일련번호.
  int _moveSequence = 0;

  Future<void> _onStarted(MapStarted event, Emitter<MapPageState> emit) async {
    final permission = await _location.requestPermission();
    if (permission != LocationPermissionStatus.authorized) {
      emit(state.copyWith(signal: MapSignal.locationDenied));
      return;
    }

    try {
      final coordinate = await _location.currentLocation();
      emit(state.copyWith(
        userLocation: coordinate,
        mapCenter: coordinate,
        moveRequest: _nextMove(coordinate),
      ));
      await _fetch(coordinate, emit, force: true);
    } catch (_) {
      emit(state.copyWith(signal: MapSignal.locationDenied));
    }
  }

  void _onMoved(MapMoved event, Emitter<MapPageState> emit) {
    final previous = state.mapCenter;
    final moved = previous == null
        ? state.userLocation != null
        : _distanceScore(previous, event.center) > MapPageState.researchThreshold;

    emit(state.copyWith(
      mapCenter: event.center,
      showResearchButton: moved || state.showResearchButton,
    ));
  }

  Future<void> _onResearchHere(
    MapResearchHereRequested event,
    Emitter<MapPageState> emit,
  ) async {
    final center = state.mapCenter;
    if (center == null) return;
    emit(state.copyWith(showResearchButton: false));
    await _fetch(center, emit);
  }

  Future<void> _onLocate(
    MapLocateRequested event,
    Emitter<MapPageState> emit,
  ) async {
    try {
      final coordinate = await _location.currentLocation();
      emit(state.copyWith(
        userLocation: coordinate,
        mapCenter: coordinate,
        moveRequest: _nextMove(coordinate),
        showResearchButton: false,
      ));
      await _fetch(coordinate, emit);
    } catch (_) {
      emit(state.copyWith(signal: MapSignal.locationDenied));
    }
  }

  Future<void> _onPlaceSelected(
    MapPlaceSelected event,
    Emitter<MapPageState> emit,
  ) async {
    emit(state.copyWith(
      searchText: event.name,
      mapCenter: event.coordinate,
      moveRequest: _nextMove(event.coordinate),
      showResearchButton: false,
    ));
    await _fetch(event.coordinate, emit, force: true);
  }

  Future<void> _onUploadCompleted(
    MapUploadCompleted event,
    Emitter<MapPageState> emit,
  ) async {
    final center = state.mapCenter ?? state.userLocation;
    if (center == null) return;
    // 방금 올린 글이 바로 보여야 하므로 쓰로틀을 건너뛴다.
    await _fetch(center, emit, force: true);
  }

  /// 목격 기록 조회. [force] 가 아니면 2초 쓰로틀을 지킨다.
  Future<void> _fetch(
    Coordinate center,
    Emitter<MapPageState> emit, {
    bool force = false,
  }) async {
    final now = DateTime.now();
    if (!force) {
      final last = _lastFetch;
      if (last != null && now.difference(last) < MapPageState.fetchThrottle) {
        return;
      }
    }
    _lastFetch = now;

    emit(state.copyWith(isLoading: true, clearSignal: true));
    try {
      final sightings = await _sightings.fetchNearby(
        latitude: center.latitude,
        longitude: center.longitude,
        radiusMeters: MapPageState.searchRadiusMeters,
      );
      emit(state.copyWith(
        sightings: sightings,
        isLoading: false,
        showResearchButton: false,
      ));
    } catch (_) {
      // 실패하면 이미 보여주던 마커는 그대로 둔다. 지도를 비우면 사용자가
      // "여기엔 아무것도 없다" 로 오해한다.
      emit(state.copyWith(isLoading: false, signal: MapSignal.loadFailed));
    }
  }

  MapMoveRequest _nextMove(Coordinate coordinate) {
    _moveSequence += 1;
    return MapMoveRequest(coordinate: coordinate, sequence: _moveSequence);
  }

  /// iOS 와 같은 거리 근사 — 위도차와 경도차의 절대값 합.
  /// 정확한 거리가 아니라 "충분히 움직였나" 만 보는 값이다.
  double _distanceScore(Coordinate a, Coordinate b) {
    return (a.latitude - b.latitude).abs() + (a.longitude - b.longitude).abs();
  }
}

/// 같은 자리에 여러 글이 있으면 마커가 겹쳐 하나만 보인다.
/// iOS 처럼 원형으로 조금씩 흩어 놓는다.
List<({Sighting sighting, Coordinate coordinate})> spreadOverlappingMarkers(
  List<Sighting> sightings,
) {
  /// 약 5m. iOS 와 같은 값이다.
  const offset = 0.00005;
  const positionsPerRing = 6;
  const sameSpotThreshold = 0.00001;

  final result = <({Sighting sighting, Coordinate coordinate})>[];
  for (var index = 0; index < sightings.length; index++) {
    final sighting = sightings[index];
    final duplicates = sightings
        .take(index)
        .where((other) =>
            (other.latitude - sighting.latitude).abs() < sameSpotThreshold &&
            (other.longitude - sighting.longitude).abs() < sameSpotThreshold)
        .length;

    if (duplicates == 0) {
      result.add((
        sighting: sighting,
        coordinate: Coordinate(
          latitude: sighting.latitude,
          longitude: sighting.longitude,
        ),
      ));
      continue;
    }

    final angle = duplicates * (2 * math.pi / positionsPerRing);
    result.add((
      sighting: sighting,
      coordinate: Coordinate(
        latitude: sighting.latitude + offset * math.cos(angle),
        longitude: sighting.longitude + offset * math.sin(angle),
      ),
    ));
  }
  return result;
}
