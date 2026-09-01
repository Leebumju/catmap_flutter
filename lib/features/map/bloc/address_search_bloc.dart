import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/coordinate.dart';
import '../../../domain/repositories/location_repository.dart';

sealed class AddressSearchEvent extends Equatable {
  const AddressSearchEvent();

  @override
  List<Object?> get props => [];
}

final class AddressSearchQueryChanged extends AddressSearchEvent {
  const AddressSearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

class AddressSearchState extends Equatable {
  const AddressSearchState({
    this.query = '',
    this.results = const [],
    this.isSearching = false,
  });

  final String query;
  final List<SearchedPlace> results;
  final bool isSearching;

  /// 두 글자 미만은 검색하지 않는다. iOS 와 같은 기준이다.
  bool get isQueryTooShort => query.length < 2;

  @override
  List<Object?> get props => [query, results, isSearching];
}

/// 주소·장소 검색. 지도와 위치 조정 화면이 같이 쓴다.
class AddressSearchBloc extends Bloc<AddressSearchEvent, AddressSearchState> {
  AddressSearchBloc({
    required LocationRepository locationRepository,
    Coordinate? around,
  })  : _location = locationRepository,
        _around = around,
        super(const AddressSearchState()) {
    // 글자를 칠 때마다 요청이 날아가지 않게 300ms 기다리고, 그 사이 새 글자가
    // 들어오면 앞의 요청을 버린다. iOS 가 Task 를 cancel 해서 하던 일과 같다.
    on<AddressSearchQueryChanged>(_onQueryChanged, transformer: restartable());
  }

  static const _debounce = Duration(milliseconds: 300);

  final LocationRepository _location;
  final Coordinate? _around;

  Future<void> _onQueryChanged(
    AddressSearchQueryChanged event,
    Emitter<AddressSearchState> emit,
  ) async {
    final query = event.query;
    if (query.length < 2) {
      emit(AddressSearchState(query: query));
      return;
    }

    emit(AddressSearchState(
      query: query,
      results: state.results,
      isSearching: true,
    ));

    await Future<void>.delayed(_debounce);

    try {
      final results = await _location.searchAddress(query, _around);
      emit(AddressSearchState(query: query, results: results));
    } catch (_) {
      // 검색 실패는 "결과 없음" 으로 보여준다. iOS 와 같다.
      emit(AddressSearchState(query: query));
    }
  }
}
