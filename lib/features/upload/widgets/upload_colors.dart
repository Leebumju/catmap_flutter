import 'package:flutter/painting.dart';

/// 업로드 화면에서 쓰는 색. iOS 쪽 hex 값을 그대로 옮긴 것이다.
class UploadColors {
  const UploadColors._();

  /// 0xE8734A — 강조색(버튼, 뷰파인더 괄호)
  static const accent = Color(0xFFE8734A);

  /// 0x111111 — 화면 배경
  static const background = Color(0xFF111111);

  /// 0x2A2A2A — 입력창·썸네일 칸 배경
  static const surface = Color(0xFF2A2A2A);
}
