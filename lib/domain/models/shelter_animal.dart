import 'package:equatable/equatable.dart';

/// 성별. 공공데이터의 sexCd 값과 매핑한다.
enum ShelterAnimalSex {
  male('M', '수컷'),
  female('F', '암컷'),
  unknown('Q', '미상');

  const ShelterAnimalSex(this.rawValue, this.label);

  final String rawValue;
  final String label;

  static ShelterAnimalSex fromRawValue(String? raw) {
    for (final s in ShelterAnimalSex.values) {
      if (s.rawValue == raw) return s;
    }
    return ShelterAnimalSex.unknown;
  }
}

/// 종 필터. 값은 공공데이터의 upkind 코드다.
enum ShelterAnimalKind {
  dog('417000', '강아지'),
  cat('422400', '고양이');

  const ShelterAnimalKind(this.rawValue, this.label);

  final String rawValue;
  final String label;
}

/// 보호 상태 묶음. 공공데이터의 processState 문자열을 몇 갈래로 정리한다.
enum ProcessStateKind {
  protecting('보호중'),
  noticing('공고중'),
  treating('치료중'),
  other('');

  const ProcessStateKind(this.label);

  final String label;

  static ProcessStateKind fromRaw(String raw) {
    if (raw.contains('보호')) return ProcessStateKind.protecting;
    if (raw.contains('공고')) return ProcessStateKind.noticing;
    if (raw.contains('치료')) return ProcessStateKind.treating;
    return ProcessStateKind.other;
  }
}

/// 보호소에 있는 유기동물 한 마리.
class ShelterAnimal extends Equatable {
  const ShelterAnimal({
    required this.id,
    required this.kind,
    required this.color,
    required this.age,
    required this.weight,
    required this.sex,
    required this.neuterYn,
    required this.happenPlace,
    required this.specialMark,
    required this.processState,
    required this.shelterName,
    required this.shelterPhone,
    required this.shelterAddress,
    required this.noticeStartDate,
    required this.noticeEndDate,
    this.imageUrl,
  });

  /// 유기번호(desertionNo).
  final String id;

  final String? imageUrl;
  final String kind;
  final String color;
  final String age;
  final String weight;
  final ShelterAnimalSex sex;
  final String neuterYn;

  /// 발견 장소.
  final String happenPlace;

  /// 특징.
  final String specialMark;

  final String processState;
  final String shelterName;
  final String shelterPhone;
  final String shelterAddress;

  /// 공고 시작·종료일. 공공데이터에서 "yyyyMMdd" 로 온다.
  final String noticeStartDate;
  final String noticeEndDate;

  ProcessStateKind get processStateKind => ProcessStateKind.fromRaw(processState);

  /// 오늘부터 공고 종료일까지 남은 날수. 못 읽으면 null.
  int? get daysUntilEnd => daysUntilEndFrom(noticeEndDate, DateTime.now());

  /// 종료가 코앞일 때만 붙이는 라벨. 그 밖에는 null 이라 카드에 안 뜬다.
  String? get imminentEndLabel {
    final days = daysUntilEnd;
    if (days == null) return null;
    if (days == 0) return '오늘 종료';
    if (days >= 1 && days <= 3) return 'D-$days';
    return null;
  }

  /// "yyyyMMdd" 를 날짜로 읽어 남은 날수를 센다.
  ///
  /// 공고 종료는 한국 날짜 기준이다. 기기 시간대가 달라도 같은 답이 나오도록
  /// 한국 시간(UTC+9)의 날짜 경계로 계산한다 — iOS 도 Asia/Seoul 로 고정한다.
  static int? daysUntilEndFrom(String noticeEndDate, DateTime now) {
    if (noticeEndDate.length != 8) return null;
    final year = int.tryParse(noticeEndDate.substring(0, 4));
    final month = int.tryParse(noticeEndDate.substring(4, 6));
    final day = int.tryParse(noticeEndDate.substring(6, 8));
    if (year == null || month == null || day == null) return null;

    const koreaOffset = Duration(hours: 9);
    final endInKorea = DateTime.utc(year, month, day);
    final nowInKorea = now.toUtc().add(koreaOffset);
    final todayInKorea =
        DateTime.utc(nowInKorea.year, nowInKorea.month, nowInKorea.day);

    return endInKorea.difference(todayInKorea).inDays;
  }

  /// 공공데이터 응답 한 건.
  factory ShelterAnimal.fromJson(Map<String, dynamic> json) {
    return ShelterAnimal(
      id: json['desertionNo']?.toString() ?? '',
      imageUrl: _secureUrl(
        (json['popfile1'] as String?) ?? (json['popfile2'] as String?) ?? '',
      ),
      kind: (json['kindNm'] as String?) ?? (json['upKindNm'] as String?) ?? '정보 없음',
      color: json['colorCd'] as String? ?? '',
      age: json['age'] as String? ?? '',
      weight: json['weight'] as String? ?? '',
      sex: ShelterAnimalSex.fromRawValue(json['sexCd'] as String?),
      neuterYn: json['neuterYn'] as String? ?? '',
      happenPlace: json['happenPlace'] as String? ?? '',
      specialMark: json['specialMark'] as String? ?? '',
      processState: json['processState']?.toString() ?? '',
      shelterName: json['careNm'] as String? ?? '',
      shelterPhone: json['careTel'] as String? ?? '',
      shelterAddress: json['careAddr'] as String? ?? '',
      noticeStartDate: json['noticeSdt']?.toString() ?? '',
      noticeEndDate: json['noticeEdt']?.toString() ?? '',
    );
  }

  /// 공공데이터 이미지 주소는 http 로 온다. 안드로이드는 기본적으로 http 를 막으므로
  /// https 로 바꿔서 쓴다 — iOS 도 같은 이유로 치환한다.
  static String? _secureUrl(String raw) {
    if (raw.isEmpty) return null;
    return raw.replaceFirst('http://', 'https://');
  }

  @override
  List<Object?> get props => [id, processState, noticeEndDate];
}

/// 유기동물 목록 한 페이지.
class ShelterAnimalResult extends Equatable {
  const ShelterAnimalResult({required this.animals, required this.totalCount});

  final List<ShelterAnimal> animals;
  final int totalCount;

  @override
  List<Object?> get props => [animals, totalCount];
}

/// 시도 코드 (예: 6110000 서울특별시).
class SidoCode extends Equatable {
  const SidoCode({required this.id, required this.name});

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

/// 시군구 코드.
class SigunguCode extends Equatable {
  const SigunguCode({required this.id, required this.name});

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}
