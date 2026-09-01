import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/app_error.dart';
import '../domain/repositories/storage_repository.dart';

/// iOS 의 `StorageClientLive` 와 같은 버킷에 같은 방식으로 올린다.
class SupabaseStorageRepository implements StorageRepository {
  SupabaseStorageRepository(this._client);

  final SupabaseClient _client;

  /// iOS 와 같은 버킷 이름. 여기가 갈라지면 사진이 서로 안 보인다.
  static const bucketId = 'sighting-photos';

  @override
  Future<String> uploadPhoto(Uint8List bytes, String path) async {
    try {
      await _client.storage.from(bucketId).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      return _client.storage.from(bucketId).getPublicUrl(path);
    } catch (error) {
      throw AppError.from(error);
    }
  }

  @override
  Future<void> deletePhoto(String path) async {
    try {
      await _client.storage.from(bucketId).remove([path]);
    } catch (error) {
      throw AppError.from(error);
    }
  }
}
