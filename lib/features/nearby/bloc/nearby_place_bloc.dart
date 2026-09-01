import 'dart:math' as math;

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/coordinate.dart';
import '../../../domain/models/nearby_place.dart';
import '../../../domain/repositories/nearby_repository.dart';

sealed class NearbyPlaceEvent extends Equatable {
  const NearbyPlaceEvent();

  @override
  List<Object?> get props => [];
}

/// 기준 좌표가 정해졌다 — 첫 페이지를 받는다.
final class NearbyPlaceLoadRequested extends NearbyPlaceEvent {
  const NearbyPlaceLoadRequested(this.coordinate);

  final Coordinate coordinate;

  @override
  List<Object?> get props => [coordinate];
}

final class NearbyPlaceLoadMoreRequested extends NearbyPlaceEvent {
  const NearbyPlaceLoadMoreRequested();
}

final class NearbyPlaceRadiusChanged extends NearbyPlaceEvent {
  const NearbyPlaceRadiusChanged(this.radiusMeters);

  final int radiusMeters;

  @override
  List<Object?> get props => [radiusMeters];
}

final class NearbyPlaceSelected extends NearbyPlaceEvent {
  const NearbyPlaceSelected(this.placeId);

  final String? placeId;

  @override
  List<Object?> get props => [placeId];
}

/// 지도를 움직였다. 검색한 자리에서 충분히 멀어지면 재검색 버튼이 뜬다.
final class NearbyPlaceMapMoved extends NearbyPlaceEvent {
  const NearbyPlaceMapMoved(this.center);

  final Coordinate center;

  @override
  List<Object?> get props => [center];
}

final class NearbyPlaceResearchHereRequested extends NearbyPlaceEvent {
  const NearbyPlaceResearchHereRequested();
}

final class NearbyPlaceRetryRequested extends NearbyPlaceEvent {
  const NearbyPlaceRetryRequested();
}

class NearbyPlaceState extends Equatable {
  const NearbyPlaceState({
    required this.query,
    this.places = const [],
    this.coordinate,
    this.mapCenter,
    this.radiusMeters = defaultRadius,
    this.currentPage = 1,
    this.isLoading = false,
    this.hasLoadedInitial = false,
    this.isEnd = false,
    this.hasError = false,
    this.showResearchButton = false,
    this.selectedPlaceId,
  });

  /// 반경 선택지(미터). iOS 와 같은 네 가지다.
  static const radiusOptions = [1000, 3000, 5000, 10000];
  static const defaultRadius = 3000;

  static const pageSize = 15;

  /// 검색한 자리에서 이만큼(미터) 멀어지면 재검색 버튼을 띄운다.
  static const researchDistanceMeters = 200.0;

  final String query;
  final List<NearbyPlace> places;

  /// 마지막으로 검색한 기준 좌표.
  final Coordinate? coordinate;

  final Coordinate? mapCenter;
  final int radiusMeters;
  final int currentPage;
  final bool isLoading;
  final bool hasLoadedInitial;

  /// 서버가 마지막 페이지라고 알려줬다.
  final bool isEnd;

  final bool hasError;
  final bool showResearchButton;
  final String? selectedPlaceId;

  NearbyPlaceState copyWith({
    List<NearbyPlace>? places,
    Coordinate? coordinate,
    Coordinate? mapCenter,
    int? radiusMeters,
    int? currentPage,
    bool? isLoading,
    bool? hasLoadedInitial,
    bool? isEnd,
    bool? hasError,
    bool? showResearchButton,
    String? selectedPlaceId,
    bool clearSelectedPlace = false,
  }) {
    return NearbyPlaceState(
      query: query,
      places: places ?? this.places,
      coordinate: coordinate ?? this.coordinate,
      mapCenter: mapCenter ?? this.mapCenter,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      currentPage: currentPage ?? this.currentPage,
      isLoading: isLoading ?? this.isLoading,
      hasLoadedInitial: hasLoadedInitial ?? this.hasLoadedInitial,
      isEnd: isEnd ?? this.isEnd,
      hasError: hasError ?? this.hasError,
      showResearchButton: showResearchButton ?? this.showResearchButton,
      selectedPlaceId:
          clearSelectedPlace ? null : (selectedPlaceId ?? this.selectedPlaceId),
    );
  }

  @override
  List<Object?> get props => [
        query,
        places,
        coordinate,
        mapCenter,
        radiusMeters,
        currentPage,
        isLoading,
        hasLoadedInitial,
        isEnd,
        hasError,
        showResearchButton,
        selectedPlaceId,
      ];
}

/// 동물병원·펫샵 목록. iOS 의 `NearbyPlaceFeature` 를 옮긴 것이다.
/// 두 카테고리가 같은 로직을 쓰고 검색어만 다르다.
class NearbyPlaceBloc extends Bloc<NearbyPlaceEvent, NearbyPlaceState> {
  NearbyPlaceBloc({
    required NearbyPlaceRepository repository,
    required String query,
  })  : _repository = repository,
        super(NearbyPlaceState(query: query)) {
    on<NearbyPlaceLoadRequested>(_onLoad, transformer: restartable());
    // 목록 끝에 닿을 때마다 이벤트가 여러 번 들어온다. 진행 중이면 버린다.
    on<NearbyPlaceLoadMoreRequested>(_onLoadMore, transformer: droppable());
    on<NearbyPlaceRadiusChanged>(_onRadiusChanged, transformer: restartable());
    on<NearbyPlaceResearchHereRequested>(_onResearchHere, transformer: restartable());
    on<NearbyPlaceRetryRequested>(_onRetry, transformer: restartable());
    on<NearbyPlaceMapMoved>(_onMapMoved);
    on<NearbyPlaceSelected>((e, emit) => emit(state.copyWith(
          selectedPlaceId: e.placeId,
          clearSelectedPlace: e.placeId == null,
        )));
  }

  final NearbyPlaceRepository _repository;

  Future<void> _onLoad(
    NearbyPlaceLoadRequested event,
    Emitter<NearbyPlaceState> emit,
  ) async {
    emit(state.copyWith(
      coordinate: event.coordinate,
      isLoading: true,
      currentPage: 1,
      hasError: false,
    ));
    await _search(emit, page: 1, isAppend: false);
  }

  Future<void> _onLoadMore(
    NearbyPlaceLoadMoreRequested event,
    Emitter<NearbyPlaceState> emit,
  ) async {
    if (state.isLoading || state.isEnd || state.coordinate == null) return;
    emit(state.copyWith(isLoading: true));
    await _search(emit, page: state.currentPage + 1, isAppend: true);
  }

  Future<void> _onRadiusChanged(
    NearbyPlaceRadiusChanged event,
    Emitter<NearbyPlaceState> emit,
  ) async {
    if (state.radiusMeters == event.radiusMeters) return;
    emit(state.copyWith(
      radiusMeters: event.radiusMeters,
      places: const [],
      currentPage: 1,
      isLoading: state.coordinate != null,
      hasError: false,
      clearSelectedPlace: true,
    ));
    if (state.coordinate == null) return;
    await _search(emit, page: 1, isAppend: false);
  }

  Future<void> _onResearchHere(
    NearbyPlaceResearchHereRequested event,
    Emitter<NearbyPlaceState> emit,
  ) async {
    final center = state.mapCenter;
    if (center == null) return;
    emit(state.copyWith(
      coordinate: center,
      places: const [],
      currentPage: 1,
      isLoading: true,
      hasError: false,
      showResearchButton: false,
      clearSelectedPlace: true,
    ));
    await _search(emit, page: 1, isAppend: false);
  }

  Future<void> _onRetry(
    NearbyPlaceRetryRequested event,
    Emitter<NearbyPlaceState> emit,
  ) async {
    if (state.coordinate == null) return;
    emit(state.copyWith(isLoading: true, currentPage: 1, hasError: false));
    await _search(emit, page: 1, isAppend: false);
  }

  void _onMapMoved(NearbyPlaceMapMoved event, Emitter<NearbyPlaceState> emit) {
    final searched = state.coordinate;
    if (searched == null) {
      emit(state.copyWith(mapCenter: event.center));
      return;
    }
    final distance = haversineMeters(searched, event.center);
    emit(state.copyWith(
      mapCenter: event.center,
      // 다시 가까워지면 버튼을 도로 숨긴다. iOS 와 같은 토글이다.
      showResearchButton: distance > NearbyPlaceState.researchDistanceMeters,
    ));
  }

  Future<void> _search(
    Emitter<NearbyPlaceState> emit, {
    required int page,
    required bool isAppend,
  }) async {
    final coordinate = state.coordinate;
    if (coordinate == null) return;

    try {
      final result = await _repository.search(
        query: state.query,
        latitude: coordinate.latitude,
        longitude: coordinate.longitude,
        radiusMeters: state.radiusMeters,
        page: page,
        size: NearbyPlaceState.pageSize,
      );

      if (isAppend) {
        // 페이지 경계에서 같은 곳이 두 번 올 수 있다. id 로 걸러낸다.
        final existing = state.places.map((p) => p.id).toSet();
        final unique =
            result.places.where((p) => !existing.contains(p.id)).toList();
        emit(state.copyWith(
          places: [...state.places, ...unique],
          currentPage: page,
          isLoading: false,
          hasLoadedInitial: true,
          isEnd: result.isEnd,
        ));
      } else {
        emit(state.copyWith(
          places: result.places,
          currentPage: page,
          isLoading: false,
          hasLoadedInitial: true,
          isEnd: result.isEnd,
        ));
      }
    } catch (_) {
      emit(state.copyWith(
        isLoading: false,
        hasLoadedInitial: true,
        hasError: true,
      ));
    }
  }
}

/// 두 좌표 사이 거리(미터). 지구를 공으로 보고 재는 방식이다.
/// iOS 가 쓰는 것과 같은 식이라 재검색 버튼이 뜨는 지점도 같다.
double haversineMeters(Coordinate a, Coordinate b) {
  const earthRadius = 6371000.0;
  double toRadians(double degree) => degree * math.pi / 180;

  final lat1 = toRadians(a.latitude);
  final lat2 = toRadians(b.latitude);
  final dLat = toRadians(b.latitude - a.latitude);
  final dLng = toRadians(b.longitude - a.longitude);

  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * earthRadius * math.asin(math.min(1, math.sqrt(h)));
}
