import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 스토어 리뷰 요청. iOS 의 `ReviewClientLive` 와 같은 조건으로 띄운다.
///
/// 사진을 3번 올렸거나 좋아요를 5번 눌렀을 때 한 번 물어보고,
/// 한 번 물어본 뒤에는 30일 동안 다시 묻지 않는다.
class ReviewPrompt {
  const ReviewPrompt();

  static const _uploadCountKey = 'review_upload_count';
  static const _likeCountKey = 'review_like_count';
  static const _lastRequestKey = 'review_last_request_date';

  static const uploadThreshold = 3;
  static const likeThreshold = 5;
  static const minInterval = Duration(days: 30);

  Future<void> trackUpload() => _increase(_uploadCountKey);

  Future<void> trackLike() => _increase(_likeCountKey);

  /// 조건이 되면 시스템 리뷰 창을 띄운다.
  Future<void> requestIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();

    final lastMillis = prefs.getInt(_lastRequestKey);
    if (lastMillis != null) {
      final last = DateTime.fromMillisecondsSinceEpoch(lastMillis);
      if (DateTime.now().difference(last) < minInterval) return;
    }

    final uploads = prefs.getInt(_uploadCountKey) ?? 0;
    final likes = prefs.getInt(_likeCountKey) ?? 0;
    if (uploads < uploadThreshold && likes < likeThreshold) return;

    final review = InAppReview.instance;
    if (!await review.isAvailable()) return;
    await review.requestReview();

    // 물어봤으면 세던 것을 0 으로 돌리고 날짜를 남긴다.
    await prefs.setInt(_uploadCountKey, 0);
    await prefs.setInt(_likeCountKey, 0);
    await prefs.setInt(_lastRequestKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _increase(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
  }
}
