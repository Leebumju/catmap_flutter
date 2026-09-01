import '../models/nearby_place.dart';
import '../models/shelter_animal.dart';

/// 주변 장소 검색(동물병원·펫샵). 카카오 로컬을 쓴다.
abstract class NearbyPlaceRepository {
  /// [query] 를 [latitude]/[longitude] 주변 [radiusMeters] 안에서 찾는다.
  /// 가까운 순으로 [page] 쪽을 [size] 개 준다.
  Future<NearbyPlaceResult> search({
    required String query,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required int page,
    required int size,
  });
}

/// 유기동물 조회. 공공데이터포털을 쓴다.
///
/// 종료된 공고는 조회 단계에서 뺀다(`state=protect`) — iOS 와 같은 규칙이다.
abstract class ShelterAnimalRepository {
  /// [sidoCode] 가 null 이면 전국, [kind] 가 null 이면 종 구분 없이.
  Future<ShelterAnimalResult> fetchAnimals({
    String? sidoCode,
    String? sigunguCode,
    ShelterAnimalKind? kind,
    required int page,
    required int size,
  });

  Future<List<SidoCode>> fetchSidoList();

  Future<List<SigunguCode>> fetchSigunguList(String sidoCode);
}
