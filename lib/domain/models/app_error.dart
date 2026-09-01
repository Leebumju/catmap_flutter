/// 앱이 구분해서 다뤄야 하는 에러만 타입으로 세운다.
/// 나머지는 그냥 던지고 화면에서 "오류" 로 묶는다 — iOS 쪽 AppError 와 같은 방침.
enum AppError implements Exception {
  /// 서버 RPC 가 raise 하는 'AUTH_REQUIRED'
  authRequired,

  /// 서버 RPC 가 raise 하는 'ACCOUNT_BANNED'
  accountBanned,

  /// 사용자가 로그인 창을 스스로 닫았다. 실패가 아니므로 알리지 않는다 — iOS 와 같다.
  loginCancelled,

  /// 로그인이 실제로 실패했다.
  loginFailed,

  /// 그 외 네트워크/DB 오류
  unknown;

  /// Supabase(PostgREST) 예외 메시지에서 서버가 raise 한 신호를 골라낸다.
  ///
  /// plpgsql 의 `raise exception 'ACCOUNT_BANNED'` 가 그대로 메시지에 실려 오기 때문에
  /// 문자열로 판별한다. 코드로 내려주지 않는 건 서버 쪽 한계라 여기서 흡수한다.
  static AppError from(Object error) {
    final message = error.toString();
    if (message.contains('ACCOUNT_BANNED')) return AppError.accountBanned;
    if (message.contains('AUTH_REQUIRED')) return AppError.authRequired;
    return AppError.unknown;
  }
}
