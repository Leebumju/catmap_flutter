import 'package:equatable/equatable.dart';

import '../../../domain/models/sighting.dart';

/// 게시물에 누를 수 있는 반응. 좋아요와 "저도 봤어요" 는 켜고 끄는 방식이 같아서
/// 종류만 다른 하나의 개념으로 다룬다. 새 반응이 생기면 여기 한 줄만 추가하면 된다.
enum ReactionKind {
  like,
  confirmation;

  /// 서버가 내려준 목격 기록에서 "내가 눌렀는지" 를 꺼낸다.
  bool activeIn(Sighting sighting) => switch (this) {
        ReactionKind.like => sighting.isLiked,
        ReactionKind.confirmation => sighting.isConfirmed,
      };

  /// 서버가 내려준 목격 기록에서 누른 사람 수를 꺼낸다.
  int countIn(Sighting sighting) => switch (this) {
        ReactionKind.like => sighting.likeCount,
        ReactionKind.confirmation => sighting.confirmationCount,
      };
}

/// 한 종류의 반응에 대한 집계 — 내가 누른 글 묶음과 글별 누른 사람 수.
///
/// 서버가 준 목록과 따로 들고 있는 이유는, 다음 페이지를 받아와도 방금 누른 결과가
/// 덮이지 않게 하기 위해서다.
class ReactionTally extends Equatable {
  const ReactionTally({this.activeIds = const {}, this.counts = const {}});

  final Set<String> activeIds;
  final Map<String, int> counts;

  bool isActive(String sightingId) => activeIds.contains(sightingId);

  int count(String sightingId) => counts[sightingId] ?? 0;

  /// 서버가 준 목격 기록들로 집계를 다시 세운다.
  ReactionTally seeded(Iterable<Sighting> sightings, ReactionKind kind) {
    final nextActive = {...activeIds};
    final nextCounts = {...counts};
    for (final sighting in sightings) {
      nextCounts[sighting.id] = kind.countIn(sighting);
      if (kind.activeIn(sighting)) {
        nextActive.add(sighting.id);
      } else {
        nextActive.remove(sighting.id);
      }
    }
    return ReactionTally(activeIds: nextActive, counts: nextCounts);
  }

  /// 서버가 돌려준 토글 결과를 반영한다.
  ReactionTally toggled(String sightingId, {required bool isActive}) {
    final nextActive = {...activeIds};
    final nextCounts = {...counts};
    if (isActive) {
      nextActive.add(sightingId);
      nextCounts[sightingId] = (nextCounts[sightingId] ?? 0) + 1;
    } else {
      nextActive.remove(sightingId);
      nextCounts[sightingId] = (nextCounts[sightingId] ?? 0) - 1;
    }
    return ReactionTally(activeIds: nextActive, counts: nextCounts);
  }

  @override
  List<Object?> get props => [activeIds, counts];
}
