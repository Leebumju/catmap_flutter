import 'package:equatable/equatable.dart';

import 'badge.dart';
import 'cat_type.dart';

/// 길고양이 목격 기록.
class Sighting extends Equatable {
  const Sighting({
    required this.id,
    required this.userId,
    required this.photoUrls,
    required this.latitude,
    required this.longitude,
    required this.catType,
    required this.createdAt,
    this.address,
    this.memo,
    this.reportCount = 0,
    this.isHidden = false,
    this.userNickname,
    this.userProfileImageUrl,
    this.userRole,
    this.userRepresentativeBadge,
    this.likeCount = 0,
    this.isLiked = false,
    this.confirmationCount = 0,
    this.isConfirmed = false,
  });

  final String id;
  final String userId;
  final List<String> photoUrls;
  final double latitude;
  final double longitude;
  final String? address;
  final String? memo;
  final int reportCount;
  final bool isHidden;
  final CatType catType;
  final DateTime createdAt;
  final String? userNickname;
  final String? userProfileImageUrl;
  final String? userRole;
  final Badge? userRepresentativeBadge;
  final int likeCount;
  final bool isLiked;
  final int confirmationCount;
  final bool isConfirmed;

  /// 표시용 주소 — 동/읍/면/리/가 단위까지만 노출한다.
  /// 목격 위치가 그대로 드러나면 안 되기 때문에 뒤쪽 번지를 자른다.
  String? get displayAddress {
    final value = address;
    if (value == null || value.isEmpty) return null;
    final parts = value.split(' ');
    const suffixes = ['동', '읍', '면', '리', '가'];
    var cut = -1;
    for (var i = 0; i < parts.length; i++) {
      if (suffixes.any(parts[i].endsWith)) cut = i;
    }
    if (cut < 0) return value;
    return parts.sublist(0, cut + 1).join(' ');
  }

  /// 썸네일 URL — 업로드 때 원본 옆에 같이 올려둔 `_thumb` 파일 경로를 유추한다.
  /// 목록에서 원본을 받으면 스크롤이 버벅인다.
  List<String> get thumbnailUrls {
    return photoUrls.map((url) {
      final index = url.lastIndexOf('.jpg');
      if (index < 0) return url;
      return url.replaceRange(index, index + 4, '_thumb.jpg');
    }).toList();
  }

  /// RPC `get_sightings_feed_v3` 의 한 행 → 모델.
  ///
  /// `created_at` 은 timestamptz 라 오프셋이 붙어 온다. 커서 페이징이 이 값으로
  /// 이어지므로 UTC 로 고정해 둔다 — 로컬 시간으로 두면 페이지 경계에서 글이
  /// 빠지거나 겹친다.
  factory Sighting.fromRpcRow(Map<String, dynamic> row) {
    return Sighting(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      photoUrls: (row['photo_urls'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
      address: row['address'] as String?,
      memo: row['memo'] as String?,
      reportCount: (row['report_count'] as num?)?.toInt() ?? 0,
      isHidden: row['is_hidden'] as bool? ?? false,
      catType: CatType.fromRawValue(row['cat_type'] as String?),
      createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
      userNickname: row['user_nickname'] as String?,
      userProfileImageUrl: row['user_profile_image_url'] as String?,
      userRole: row['user_role'] as String?,
      userRepresentativeBadge:
          Badge.fromRawValue(row['user_representative_badge'] as String?),
      // like_count / confirmation_count 는 bigint 라 num 으로 받는다.
      likeCount: (row['like_count'] as num?)?.toInt() ?? 0,
      isLiked: row['is_liked'] as bool? ?? false,
      confirmationCount: (row['confirmation_count'] as num?)?.toInt() ?? 0,
      isConfirmed: row['is_confirmed'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        photoUrls,
        latitude,
        longitude,
        address,
        memo,
        reportCount,
        isHidden,
        catType,
        createdAt,
        userNickname,
        userProfileImageUrl,
        userRole,
        userRepresentativeBadge,
        likeCount,
        isLiked,
        confirmationCount,
        isConfirmed,
      ];
}
