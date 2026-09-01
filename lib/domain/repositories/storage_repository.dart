import 'dart:typed_data';

/// 사진 파일 저장소. 구현(Supabase Storage)은 data 계층에만 둔다.
abstract class StorageRepository {
  /// 사진 한 장을 올리고 공개 URL 을 돌려준다.
  Future<String> uploadPhoto(Uint8List bytes, String path);

  /// 사진 삭제. 업로드 도중 실패했을 때 되돌리는 데 쓴다.
  Future<void> deletePhoto(String path);
}
