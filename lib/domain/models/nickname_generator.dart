import 'dart:math';

/// 닉네임 자동 생성. iOS 의 `NicknameGenerator` 와 **같은 단어 목록**을 쓴다.
///
/// 목록이 갈라지면 두 플랫폼에서 만들어지는 닉네임의 성격이 달라지므로,
/// 형용사/명사 배열은 iOS 원본에서 그대로 옮긴 것이다.
class NicknameGenerator {
  NicknameGenerator._();

  static final _random = Random();

  static const List<String> _adjectives = [
  '깔깔대는', '졸린', '배고픈', '점프하는', '숨어있는',
  '장난치는', '뒹구는', '기지개켜는', '몰래다가오는', '꾹꾹이하는',
  '야옹하는', '골골대는', '냥냥펀치하는', '박스좋아하는', '창밖보는',
  '도망치는', '어슬렁대는', '캣닢먹은', '그루밍하는', '하품하는',
  '꼬리흔드는', '앞발모으는', '쓰다듬받는', '털날리는', '낮잠자는',
  '몰래훔치는', '높이올라간', '빠르게뛰는', '살금살금걷는', '드러누운',
  '츄르먹는', '간식훔친', '이불속', '냥냥거리는', '코골며자는',
  '도도한', '심심한', '귀여운', '호기심많은', '느긋한',
  '새침한', '다정한', '엉뚱한', '용감한', '수줍은',
  '당당한', '까칠한', '순둥이', '개구쟁이', '먹보',
  '겁쟁이', '소심한', '활발한', '조용한', '사나운',
  '애교많은', '쿨한', '매력적인', '신비로운', '자유로운',
  '여유로운', '씩씩한', '재빠른', '똑똑한', '멍때리는',
  '동글동글', '폭신폭신', '반짝반짝', '보들보들', '통통한',
  '날씬한', '작은', '큰', '긴꼬리', '짧은꼬리',
  '큰눈의', '쫑긋귀', '분홍코', '하얀배', '검은발',
  '노란눈', '초록눈', '파란눈', '줄무늬', '점박이',
  ];

  static const List<String> _nouns = [
  '고양이', '냥이', '치즈냥', '턱시도냥', '삼색냥',
  '고등어냥', '코숏', '러시안블루', '먼치킨', '스코티시폴드',
  '페르시안', '샴냥이', '랙돌', '벵갈', '아비시니안',
  '메인쿤', '노르웨이숲', '터키시앙고라', '브리티시숏헤어', '아메리칸숏헤어',
  '길냥이', '아깽이', '냥아치', '냥스타', '츄르도둑',
  '참치캔오프너', '캣타워지기', '박스냥', '햇살냥', '창문냥',
  '옥상냥', '골목냥', '공원냥', '지붕냥', '담장냥',
  '집사', '냥집사', '캣대디', '캣맘', '간식셔틀',
  '츄르배달부', '캣시터', '고양이친구', '냥덕후', '냥바보',
  ];

  /// 기본 닉네임 (숫자 없음).
  static String generate() {
    final adjective = _adjectives[_random.nextInt(_adjectives.length)];
    final noun = _nouns[_random.nextInt(_nouns.length)];
    return '$adjective$noun';
  }

  /// 이미 쓰이는 닉네임이면 뒤에 숫자를 붙여 비어 있는 것을 찾는다.
  static String resolveUnique({
    required String base,
    required List<String> existingNicknames,
  }) {
    if (!existingNicknames.contains(base)) return base;
    var suffix = 1;
    while (existingNicknames.contains('$base$suffix')) {
      suffix += 1;
    }
    return '$base$suffix';
  }
}
