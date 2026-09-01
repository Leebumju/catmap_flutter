import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/coordinate.dart';
import '../../../domain/models/shelter_animal.dart';
import '../../../domain/repositories/location_repository.dart';
import '../../../domain/repositories/nearby_repository.dart';

sealed class ShelterAnimalEvent extends Equatable {
  const ShelterAnimalEvent();

  @override
  List<Object?> get props => [];
}

final class ShelterAnimalStarted extends ShelterAnimalEvent {
  const ShelterAnimalStarted();
}

final class ShelterAnimalKindSelected extends ShelterAnimalEvent {
  const ShelterAnimalKindSelected(this.kind);

  /// null 이면 종 구분 없이 전부.
  final ShelterAnimalKind? kind;

  @override
  List<Object?> get props => [kind];
}

final class ShelterAnimalSidoSelected extends ShelterAnimalEvent {
  const ShelterAnimalSidoSelected(this.sido);

  /// null 이면 전국.
  final SidoCode? sido;

  @override
  List<Object?> get props => [sido];
}

final class ShelterAnimalSigunguSelected extends ShelterAnimalEvent {
  const ShelterAnimalSigunguSelected(this.sigungu);

  final SigunguCode? sigungu;

  @override
  List<Object?> get props => [sigungu];
}

/// "내 위치로" — 자동으로 시도를 다시 잡는다.
final class ShelterAnimalUseMyLocationRequested extends ShelterAnimalEvent {
  const ShelterAnimalUseMyLocationRequested();
}

final class ShelterAnimalRefreshRequested extends ShelterAnimalEvent {
  const ShelterAnimalRefreshRequested();
}

final class ShelterAnimalLoadMoreRequested extends ShelterAnimalEvent {
  const ShelterAnimalLoadMoreRequested();
}

class ShelterAnimalState extends Equatable {
  const ShelterAnimalState({
    this.animals = const [],
    this.totalCount = 0,
    this.currentPage = 1,
    this.hasMorePages = true,
    this.isInitialLoading = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.hasLoadedInitial = false,
    this.hasError = false,
    this.selectedKind,
    this.selectedSido,
    this.selectedSigungu,
    this.sidoList = const [],
    this.sigunguList = const [],
    this.manualRegionSelected = false,
    this.locationMappingFallback = false,
  });

  static const pageSize = 20;

  /// 위치를 시도로 못 바꿨을 때 쓰는 기본값. iOS 와 같은 서울특별시다.
  static const fallbackSido = SidoCode(id: '6110000', name: '서울특별시');

  final List<ShelterAnimal> animals;
  final int totalCount;
  final int currentPage;
  final bool hasMorePages;

  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool isRefreshing;
  final bool hasLoadedInitial;
  final bool hasError;

  final ShelterAnimalKind? selectedKind;
  final SidoCode? selectedSido;
  final SigunguCode? selectedSigungu;

  final List<SidoCode> sidoList;
  final List<SigunguCode> sigunguList;

  /// 사용자가 지역을 직접 골랐다. 그러면 위치를 자동으로 다시 잡지 않는다.
  final bool manualRegionSelected;

  /// 위치를 시도로 못 바꿔서 기본값(서울)으로 시작했다. 화면에 안내를 띄운다.
  final bool locationMappingFallback;

  ShelterAnimalState copyWith({
    List<ShelterAnimal>? animals,
    int? totalCount,
    int? currentPage,
    bool? hasMorePages,
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? isRefreshing,
    bool? hasLoadedInitial,
    bool? hasError,
    ShelterAnimalKind? selectedKind,
    SidoCode? selectedSido,
    SigunguCode? selectedSigungu,
    List<SidoCode>? sidoList,
    List<SigunguCode>? sigunguList,
    bool? manualRegionSelected,
    bool? locationMappingFallback,
    bool clearKind = false,
    bool clearSido = false,
    bool clearSigungu = false,
  }) {
    return ShelterAnimalState(
      animals: animals ?? this.animals,
      totalCount: totalCount ?? this.totalCount,
      currentPage: currentPage ?? this.currentPage,
      hasMorePages: hasMorePages ?? this.hasMorePages,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      hasLoadedInitial: hasLoadedInitial ?? this.hasLoadedInitial,
      hasError: hasError ?? this.hasError,
      selectedKind: clearKind ? null : (selectedKind ?? this.selectedKind),
      selectedSido: clearSido ? null : (selectedSido ?? this.selectedSido),
      selectedSigungu:
          clearSigungu ? null : (selectedSigungu ?? this.selectedSigungu),
      sidoList: sidoList ?? this.sidoList,
      sigunguList: sigunguList ?? this.sigunguList,
      manualRegionSelected: manualRegionSelected ?? this.manualRegionSelected,
      locationMappingFallback:
          locationMappingFallback ?? this.locationMappingFallback,
    );
  }

  /// 화면 위쪽에 보여줄 현재 지역 문구.
  String get regionLabel {
    final sido = selectedSido;
    if (sido == null) return '전국';
    final sigungu = selectedSigungu;
    return sigungu == null ? sido.name : '${sido.name} ${sigungu.name}';
  }

  @override
  List<Object?> get props => [
        animals,
        totalCount,
        currentPage,
        hasMorePages,
        isInitialLoading,
        isLoadingMore,
        isRefreshing,
        hasLoadedInitial,
        hasError,
        selectedKind,
        selectedSido,
        selectedSigungu,
        sidoList,
        sigunguList,
        manualRegionSelected,
        locationMappingFallback,
      ];
}

/// 유기동물 목록. iOS 의 `ShelterAnimalFeature` 를 옮긴 것이다.
class ShelterAnimalBloc extends Bloc<ShelterAnimalEvent, ShelterAnimalState> {
  ShelterAnimalBloc({
    required ShelterAnimalRepository repository,
    required LocationRepository locationRepository,
  })  : _repository = repository,
        _location = locationRepository,
        super(const ShelterAnimalState()) {
    on<ShelterAnimalStarted>(_onStarted, transformer: droppable());
    on<ShelterAnimalKindSelected>(_onKindSelected, transformer: restartable());
    on<ShelterAnimalSidoSelected>(_onSidoSelected, transformer: restartable());
    on<ShelterAnimalSigunguSelected>(_onSigunguSelected, transformer: restartable());
    on<ShelterAnimalUseMyLocationRequested>(_onUseMyLocation, transformer: restartable());
    on<ShelterAnimalRefreshRequested>(_onRefresh, transformer: droppable());
    on<ShelterAnimalLoadMoreRequested>(_onLoadMore, transformer: droppable());
  }

  final ShelterAnimalRepository _repository;
  final LocationRepository _location;

  Future<void> _onStarted(
    ShelterAnimalStarted event,
    Emitter<ShelterAnimalState> emit,
  ) async {
    if (state.hasLoadedInitial) return;
    emit(state.copyWith(hasLoadedInitial: true, isInitialLoading: true));

    // 시도 목록을 먼저 받아야 위치를 시도로 바꿀 수 있다.
    List<SidoCode> sidoList = const [];
    try {
      sidoList = await _repository.fetchSidoList();
      emit(state.copyWith(sidoList: sidoList));
    } catch (_) {
      // 시도 목록을 못 받아도 기본값으로 진행한다.
    }

    await _resolveRegionFromLocation(emit, sidoList);
  }

  /// 현재 위치를 시도로 바꿔 고른다. 실패하면 서울로 시작하고 안내를 켠다.
  Future<void> _resolveRegionFromLocation(
    Emitter<ShelterAnimalState> emit,
    List<SidoCode> sidoList,
  ) async {
    SidoCode? matched;
    try {
      final coordinate = await _location.currentLocation();
      final address = await _location.reverseGeocode(coordinate);
      matched = matchSido(address, sidoList);
    } catch (_) {
      matched = null;
    }

    final resolved = matched ?? ShelterAnimalState.fallbackSido;
    emit(state.copyWith(
      selectedSido: resolved,
      clearSigungu: true,
      manualRegionSelected: false,
      locationMappingFallback: matched == null,
    ));

    await _loadSigunguList(emit, resolved.id);
    await _reload(emit);
  }

  Future<void> _onKindSelected(
    ShelterAnimalKindSelected event,
    Emitter<ShelterAnimalState> emit,
  ) async {
    if (state.selectedKind == event.kind) return;
    emit(state.copyWith(
      selectedKind: event.kind,
      clearKind: event.kind == null,
    ));
    await _reload(emit);
  }

  Future<void> _onSidoSelected(
    ShelterAnimalSidoSelected event,
    Emitter<ShelterAnimalState> emit,
  ) async {
    emit(state.copyWith(
      selectedSido: event.sido,
      clearSido: event.sido == null,
      clearSigungu: true,
      sigunguList: const [],
      manualRegionSelected: true,
      locationMappingFallback: false,
    ));
    final sido = event.sido;
    if (sido != null) await _loadSigunguList(emit, sido.id);
    await _reload(emit);
  }

  Future<void> _onSigunguSelected(
    ShelterAnimalSigunguSelected event,
    Emitter<ShelterAnimalState> emit,
  ) async {
    emit(state.copyWith(
      selectedSigungu: event.sigungu,
      clearSigungu: event.sigungu == null,
      manualRegionSelected: true,
    ));
    await _reload(emit);
  }

  Future<void> _onUseMyLocation(
    ShelterAnimalUseMyLocationRequested event,
    Emitter<ShelterAnimalState> emit,
  ) async {
    emit(state.copyWith(manualRegionSelected: false, isInitialLoading: true));
    await _resolveRegionFromLocation(emit, state.sidoList);
  }

  Future<void> _onRefresh(
    ShelterAnimalRefreshRequested event,
    Emitter<ShelterAnimalState> emit,
  ) async {
    if (state.isRefreshing) return;
    emit(state.copyWith(
      isRefreshing: true,
      currentPage: 1,
      hasMorePages: true,
      hasError: false,
    ));
    await _fetch(emit, page: 1, isAppend: false);
  }

  Future<void> _onLoadMore(
    ShelterAnimalLoadMoreRequested event,
    Emitter<ShelterAnimalState> emit,
  ) async {
    if (state.isLoadingMore || state.isInitialLoading || !state.hasMorePages) {
      return;
    }
    emit(state.copyWith(isLoadingMore: true));
    await _fetch(emit, page: state.currentPage + 1, isAppend: true);
  }

  Future<void> _loadSigunguList(
    Emitter<ShelterAnimalState> emit,
    String sidoCode,
  ) async {
    try {
      final list = await _repository.fetchSigunguList(sidoCode);
      emit(state.copyWith(sigunguList: list));
    } catch (_) {
      // 구 목록을 못 받아도 시도 단위 조회는 된다.
    }
  }

  /// 필터가 바뀌었을 때 첫 페이지부터 다시 받는다.
  Future<void> _reload(Emitter<ShelterAnimalState> emit) async {
    emit(state.copyWith(
      animals: const [],
      currentPage: 1,
      hasMorePages: true,
      hasError: false,
      isInitialLoading: true,
    ));
    await _fetch(emit, page: 1, isAppend: false);
  }

  Future<void> _fetch(
    Emitter<ShelterAnimalState> emit, {
    required int page,
    required bool isAppend,
  }) async {
    try {
      final result = await _repository.fetchAnimals(
        sidoCode: state.selectedSido?.id,
        sigunguCode: state.selectedSigungu?.id,
        kind: state.selectedKind,
        page: page,
        size: ShelterAnimalState.pageSize,
      );

      // 받은 수가 한 페이지보다 적으면 마지막 장이다. iOS 와 같은 판정이다.
      final hasMore = result.animals.length >= ShelterAnimalState.pageSize;

      if (isAppend) {
        final existing = state.animals.map((a) => a.id).toSet();
        final unique =
            result.animals.where((a) => !existing.contains(a.id)).toList();
        emit(state.copyWith(
          animals: [...state.animals, ...unique],
          currentPage: page,
          totalCount: result.totalCount,
          hasMorePages: hasMore,
          isInitialLoading: false,
          isLoadingMore: false,
          isRefreshing: false,
        ));
      } else {
        emit(state.copyWith(
          animals: result.animals,
          currentPage: page,
          totalCount: result.totalCount,
          hasMorePages: hasMore,
          isInitialLoading: false,
          isLoadingMore: false,
          isRefreshing: false,
        ));
      }
    } catch (_) {
      emit(state.copyWith(
        isInitialLoading: false,
        isLoadingMore: false,
        isRefreshing: false,
        hasError: true,
      ));
    }
  }
}

/// 역지오코딩으로 얻은 시도 이름을 공공데이터의 시도 코드에 맞춘다.
///
/// 이름이 정확히 같지 않은 경우가 많다("서울" vs "서울특별시"). 그래서
/// 정확히 같은 것을 먼저 찾고, 없으면 한쪽이 다른 쪽을 품고 있는지 본다.
/// iOS 의 `matchSido` 와 같은 규칙이다.
SidoCode? matchSido(AdministrativeAddress address, List<SidoCode> sidoList) {
  final raw = address.administrativeArea;
  if (raw == null || raw.isEmpty) return null;

  for (final sido in sidoList) {
    if (sido.name == raw) return sido;
  }
  for (final sido in sidoList) {
    if (sido.name.contains(raw) || raw.contains(sido.name)) return sido;
  }
  return null;
}
