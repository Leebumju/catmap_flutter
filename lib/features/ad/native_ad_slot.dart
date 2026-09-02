import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 앱에서 쓰는 광고 단위 주소.
///
/// **아직 안드로이드용 실제 주소가 없다.** iOS 는 애플용으로 따로 발급받은 것을 쓰는데,
/// 안드로이드는 AdMob 콘솔에서 안드로이드 앱을 새로 만들고 광고 단위를 발급받아야 한다.
/// 그때까지는 구글이 공개한 테스트 주소로 돌아간다 — 수익은 없지만 화면과 동작은 같다.
///
/// 발급받으면 빌드할 때 넘긴다:
///   --dart-define=ADMOB_NATIVE_UNIT_ID=ca-app-pub-XXXX/YYYY
class AdUnits {
  const AdUnits._();

  /// 구글 공식 테스트용 네이티브 광고 주소(안드로이드).
  static const testNative = 'ca-app-pub-3940256099942544/2247696110';

  static const _configured =
      String.fromEnvironment('ADMOB_NATIVE_UNIT_ID');

  /// 실제 주소가 없으면 테스트 주소를 쓴다.
  static String get native => _configured.isEmpty ? testNative : _configured;

  /// 실제 주소로 돌고 있는지. 화면에 표시하지는 않고 판단용으로만 쓴다.
  static bool get isUsingTestUnit => _configured.isEmpty;
}

/// 목록 사이에 끼우는 네이티브 광고 한 칸.
///
/// 구글이 제공하는 기본 틀(NativeTemplateStyle)로 그린다. 광고 요소를 직접 그리면
/// 노출·클릭이 제대로 집계되지 않고 AdMob 정책에도 어긋난다 —
/// iOS 가 GADNativeAdView 에 에셋을 묶어 쓰는 것과 같은 이유다.
class NativeAdSlot extends StatefulWidget {
  const NativeAdSlot({super.key, this.height = 320});

  final double height;

  @override
  State<NativeAdSlot> createState() => _NativeAdSlotState();
}

class _NativeAdSlotState extends State<NativeAdSlot>
    with AutomaticKeepAliveClientMixin {
  NativeAd? _ad;
  bool _isLoaded = false;
  bool _failed = false;

  // 스크롤로 화면 밖에 나가도 광고를 버리지 않는다. 다시 받으면 그만큼 요청이 늘고
  // 같은 자리에 다른 광고가 튀어 보인다.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final ad = NativeAd(
      adUnitId: AdUnits.native,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: Colors.white,
      ),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          // 광고가 안 나와도 목록은 그대로 보여야 한다. 자리만 접는다.
          setState(() => _failed = true);
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ad = _ad;
    if (_failed || ad == null || !_isLoaded) return const SizedBox.shrink();
    return Container(
      height: widget.height,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: AdWidget(ad: ad),
    );
  }
}
