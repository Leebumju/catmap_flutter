import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/coordinate.dart';
import '../../../domain/models/nearby_place.dart';
import '../../../domain/repositories/location_repository.dart';

sealed class NearbyEvent extends Equatable {
  const NearbyEvent();

  @override
  List<Object?> get props => [];
}

final class NearbyStarted extends NearbyEvent {
  const NearbyStarted();
}

final class NearbyCategorySelected extends NearbyEvent {
  const NearbyCategorySelected(this.category);

  final NearbyCategory category;

  @override
  List<Object?> get props => [category];
}

/// 위치를 다시 잡는다.
final class NearbyRefreshRequested extends NearbyEvent {
  const NearbyRefreshRequested();
}

class NearbyState extends Equatable {
  const NearbyState({
    this.selectedCategory = NearbyCategory.animalHospital,
    this.coordinate,
    this.address,
    this.locationDenied = false,
    this.isLocating = false,
  });

  final NearbyCategory selectedCategory;

  /// 검색 기준이 되는 내 위치.
  final Coordinate? coordinate;

  /// 그 위치를 사람이 읽는 주소로 바꾼 것. 화면 위쪽에 보여준다.
  final String? address;

  final bool locationDenied;
  final bool isLocating;

  NearbyState copyWith({
    NearbyCategory? selectedCategory,
    Coordinate? coordinate,
    String? address,
    bool? locationDenied,
    bool? isLocating,
    bool clearCoordinate = false,
  }) {
    return NearbyState(
      selectedCategory: selectedCategory ?? this.selectedCategory,
      coordinate: clearCoordinate ? null : (coordinate ?? this.coordinate),
      address: address ?? this.address,
      locationDenied: locationDenied ?? this.locationDenied,
      isLocating: isLocating ?? this.isLocating,
    );
  }

  @override
  List<Object?> get props =>
      [selectedCategory, coordinate, address, locationDenied, isLocating];
}

/// 둘러보기 탭의 바깥 껍데기. iOS 의 `NearbyFeature` 에 대응한다.
///
/// 하는 일은 두 가지다 — 지금 어느 갈래(동물병원/펫샵/유기동물)를 보고 있는지,
/// 그리고 검색 기준이 될 내 위치가 어디인지.
class NearbyBloc extends Bloc<NearbyEvent, NearbyState> {
  NearbyBloc({required LocationRepository locationRepository})
      : _location = locationRepository,
        super(const NearbyState()) {
    on<NearbyStarted>(_onStarted);
    on<NearbyCategorySelected>((e, emit) =>
        emit(state.copyWith(selectedCategory: e.category)));
    on<NearbyRefreshRequested>(_onRefresh);
  }

  final LocationRepository _location;

  Future<void> _onStarted(
    NearbyStarted event,
    Emitter<NearbyState> emit,
  ) async {
    // 이미 위치를 잡아뒀으면 다시 잡지 않는다. iOS 와 같은 가드다.
    if (state.coordinate != null) return;
    await _locate(emit);
  }

  Future<void> _onRefresh(
    NearbyRefreshRequested event,
    Emitter<NearbyState> emit,
  ) async {
    emit(state.copyWith(clearCoordinate: true));
    await _locate(emit);
  }

  Future<void> _locate(Emitter<NearbyState> emit) async {
    emit(state.copyWith(isLocating: true, locationDenied: false));

    final permission = await _location.requestPermission();
    if (permission != LocationPermissionStatus.authorized) {
      emit(state.copyWith(isLocating: false, locationDenied: true));
      return;
    }

    try {
      final coordinate = await _location.currentLocation();
      emit(state.copyWith(coordinate: coordinate, isLocating: false));

      // 주소는 없어도 목록은 뜬다. 실패해도 넘어간다.
      final address = await _location.reverseGeocode(coordinate);
      emit(state.copyWith(address: address.display));
    } catch (_) {
      emit(state.copyWith(isLocating: false, locationDenied: true));
    }
  }
}
