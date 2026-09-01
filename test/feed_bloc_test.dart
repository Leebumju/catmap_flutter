import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:catmap_flutter/domain/models/app_error.dart';
import 'package:catmap_flutter/domain/models/cat_type.dart';
import 'package:catmap_flutter/domain/models/sighting.dart';
import 'package:catmap_flutter/domain/repositories/auth_repository.dart';
import 'package:catmap_flutter/domain/repositories/sighting_repository.dart';
import 'package:catmap_flutter/features/feed/bloc/feed_bloc.dart';
import 'package:catmap_flutter/features/feed/bloc/feed_event.dart';
import 'package:catmap_flutter/features/feed/bloc/feed_state.dart';
import 'package:catmap_flutter/features/feed/bloc/reaction_tally.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSightingRepository extends Mock implements SightingRepository {}

/// 피드는 AuthRepository 중 currentUserId 하나만 쓴다. 나머지는 부르면 터지게 두어,
/// 피드가 몰래 다른 인증 기능에 기대기 시작하면 테스트가 알려주도록 한다.
class FakeAuthRepository extends Fake implements AuthRepository {
  FakeAuthRepository(this._userId);

  final String? _userId;

  @override
  String? currentUserId() => _userId;
}

const myUserId = 'U1';

Sighting makeSighting({
  required String id,
  String userId = myUserId,
  int likeCount = 0,
  bool isLiked = false,
  int confirmationCount = 0,
  bool isConfirmed = false,
  DateTime? createdAt,
}) {
  return Sighting(
    id: id,
    userId: userId,
    photoUrls: ['https://example.com/$id.jpg'],
    latitude: 37.5,
    longitude: 127.0,
    catType: CatType.stray,
    createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
    likeCount: likeCount,
    isLiked: isLiked,
    confirmationCount: confirmationCount,
    isConfirmed: isConfirmed,
  );
}

List<Sighting> page(int count, {int startIndex = 0}) {
  return List.generate(
    count,
    (i) => makeSighting(
      id: 'S${startIndex + i}',
      createdAt:
          DateTime.utc(2026, 1, 1).subtract(Duration(minutes: startIndex + i)),
    ),
  );
}

void main() {
  late MockSightingRepository repository;

  setUp(() {
    repository = MockSightingRepository();
  });

  FeedBloc build({String? userId = myUserId}) => FeedBloc(
        sightingRepository: repository,
        authRepository: FakeAuthRepository(userId),
      );

  void stubFeed(List<Sighting> result) {
    when(() => repository.fetchFeed(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => result);
  }

  group('첫 로드', () {
    blocTest<FeedBloc, FeedState>(
      '한 페이지를 다 채워 오면 다음 페이지가 있다고 본다',
      setUp: () => stubFeed(page(FeedState.pageSize)),
      build: build,
      act: (bloc) => bloc.add(const FeedStarted()),
      expect: () => [
        isA<FeedState>().having((s) => s.isLoading, 'isLoading', true),
        isA<FeedState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.sightings.length, '개수', FeedState.pageSize)
            .having((s) => s.hasMorePages, 'hasMorePages', true),
      ],
    );

    blocTest<FeedBloc, FeedState>(
      '서버가 내려준 좋아요 상태를 맵에 심는다',
      setUp: () => stubFeed([
        makeSighting(id: 'S0', likeCount: 3, isLiked: true),
        makeSighting(id: 'S1', confirmationCount: 2, isConfirmed: true),
      ]),
      build: build,
      act: (bloc) => bloc.add(const FeedStarted()),
      skip: 1,
      expect: () => [
        isA<FeedState>()
            .having((s) => s.tally(ReactionKind.like).isActive('S0'),
                'S0 좋아요됨', true)
            .having(
                (s) => s.tally(ReactionKind.like).count('S0'), 'S0 좋아요 수', 3)
            .having((s) => s.tally(ReactionKind.confirmation).isActive('S1'),
                'S1 봤어요됨', true)
            .having((s) => s.tally(ReactionKind.confirmation).count('S1'),
                'S1 봤어요 수', 2),
      ],
    );

    blocTest<FeedBloc, FeedState>(
      '이미 데이터가 있으면 다시 요청하지 않는다 (지도에서 넘어온 경우)',
      build: build,
      seed: () => FeedState(sightings: page(2)),
      act: (bloc) => bloc.add(const FeedStarted()),
      expect: () => <FeedState>[],
      verify: (_) {
        verifyNever(() => repository.fetchFeed(
              cursor: any(named: 'cursor'),
              limit: any(named: 'limit'),
            ));
      },
    );

    blocTest<FeedBloc, FeedState>(
      '새로고침은 데이터가 있어도 처음부터 다시 받는다',
      setUp: () => stubFeed(page(2)),
      build: build,
      seed: () => FeedState(sightings: page(5), currentIndex: 3),
      act: (bloc) => bloc.add(const FeedRefreshed()),
      skip: 1,
      expect: () => [
        isA<FeedState>()
            .having((s) => s.sightings.length, '개수', 2)
            .having((s) => s.currentIndex, '인덱스 초기화', 0),
      ],
    );
  });

  group('추가 페이지', () {
    blocTest<FeedBloc, FeedState>(
      '커서 경계에서 겹쳐 온 게시물은 id 로 걸러낸다',
      setUp: () => stubFeed([makeSighting(id: 'S1'), makeSighting(id: 'S2')]),
      build: build,
      seed: () => FeedState(
        sightings: [makeSighting(id: 'S0'), makeSighting(id: 'S1')],
      ),
      act: (bloc) => bloc.add(const FeedLoadMoreRequested()),
      skip: 1,
      expect: () => [
        isA<FeedState>().having(
          (s) => s.sightings.map((e) => e.id).toList(),
          '중복 제거된 목록',
          ['S0', 'S1', 'S2'],
        ),
      ],
    );

    blocTest<FeedBloc, FeedState>(
      '실패해도 hasMorePages 를 내리지 않는다 — 한 번 실패로 페이징이 막히면 안 된다',
      setUp: () {
        when(() => repository.fetchFeed(
              cursor: any(named: 'cursor'),
              limit: any(named: 'limit'),
            )).thenThrow(AppError.unknown);
      },
      build: build,
      seed: () => FeedState(sightings: page(1)),
      act: (bloc) => bloc.add(const FeedLoadMoreRequested()),
      skip: 1,
      expect: () => [
        isA<FeedState>()
            .having((s) => s.isLoadingMore, 'isLoadingMore', false)
            .having((s) => s.hasMorePages, 'hasMorePages', true),
      ],
    );

    blocTest<FeedBloc, FeedState>(
      '마지막 페이지면 요청하지 않는다',
      build: build,
      seed: () => FeedState(sightings: page(1), hasMorePages: false),
      act: (bloc) => bloc.add(const FeedLoadMoreRequested()),
      expect: () => <FeedState>[],
    );
  });

  group('좋아요', () {
    blocTest<FeedBloc, FeedState>(
      '서버가 돌려준 결과로만 상태를 바꾼다 (낙관적 업데이트 안 함)',
      setUp: () {
        when(() => repository.toggleLike('S0')).thenAnswer((_) async => true);
      },
      build: build,
      seed: () => FeedState(
        sightings: [makeSighting(id: 'S0', likeCount: 2)],
        reactions: const {
          ReactionKind.like: ReactionTally(counts: {'S0': 2}),
        },
      ),
      act: (bloc) => bloc.add(const FeedReactionToggled(
        kind: ReactionKind.like,
        sightingId: 'S0',
      )),
      expect: () => [
        // 먼저 대기 표시만 선다 — 좋아요 수는 아직 그대로다.
        isA<FeedState>()
            .having((s) => s.pendingReactions, '대기 중', {ReactionKind.like})
            .having((s) => s.tally(ReactionKind.like).count('S0'), '아직 그대로', 2),
        isA<FeedState>()
            .having((s) => s.pendingReactions, '대기 없음', <ReactionKind>{})
            .having((s) => s.tally(ReactionKind.like).isActive('S0'), '좋아요됨',
                true)
            .having(
                (s) => s.tally(ReactionKind.like).count('S0'), '좋아요 수', 3),
      ],
    );

    blocTest<FeedBloc, FeedState>(
      '취소하면 수가 하나 준다',
      setUp: () {
        when(() => repository.toggleLike('S0')).thenAnswer((_) async => false);
      },
      build: build,
      seed: () => FeedState(
        sightings: [makeSighting(id: 'S0', likeCount: 3, isLiked: true)],
        reactions: const {
          ReactionKind.like:
              ReactionTally(activeIds: {'S0'}, counts: {'S0': 3}),
        },
      ),
      act: (bloc) => bloc.add(const FeedReactionToggled(
        kind: ReactionKind.like,
        sightingId: 'S0',
      )),
      skip: 1,
      expect: () => [
        isA<FeedState>()
            .having((s) => s.tally(ReactionKind.like).isActive('S0'), '좋아요 해제',
                false)
            .having(
                (s) => s.tally(ReactionKind.like).count('S0'), '좋아요 수', 2),
      ],
    );

    blocTest<FeedBloc, FeedState>(
      '좋아요를 기다리는 중에도 저도봤어요는 눌린다 — 종류별로 따로 막는다',
      setUp: () {
        // 좋아요는 응답이 안 오게 두고, 저도봤어요만 바로 답한다.
        when(() => repository.toggleLike('S0'))
            .thenAnswer((_) => Completer<bool>().future);
        when(() => repository.toggleConfirmation('S0'))
            .thenAnswer((_) async => true);
      },
      build: build,
      seed: () => FeedState(sightings: [makeSighting(id: 'S0')]),
      act: (bloc) async {
        bloc.add(const FeedReactionToggled(
          kind: ReactionKind.like,
          sightingId: 'S0',
        ));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const FeedReactionToggled(
          kind: ReactionKind.confirmation,
          sightingId: 'S0',
        ));
      },
      skip: 2,
      expect: () => [
        isA<FeedState>()
            .having((s) => s.tally(ReactionKind.confirmation).isActive('S0'),
                '저도봤어요 눌림', true)
            // 좋아요는 아직 응답을 기다리는 중이다.
            .having((s) => s.pendingReactions, '좋아요만 대기', {ReactionKind.like}),
      ],
    );

    blocTest<FeedBloc, FeedState>(
      '같은 종류를 연달아 누르면 두 번째는 버린다',
      setUp: () {
        when(() => repository.toggleLike('S0'))
            .thenAnswer((_) => Completer<bool>().future);
      },
      build: build,
      seed: () => FeedState(sightings: [makeSighting(id: 'S0')]),
      act: (bloc) async {
        bloc.add(const FeedReactionToggled(
          kind: ReactionKind.like,
          sightingId: 'S0',
        ));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const FeedReactionToggled(
          kind: ReactionKind.like,
          sightingId: 'S0',
        ));
      },
      expect: () => [
        isA<FeedState>()
            .having((s) => s.pendingReactions, '대기 중', {ReactionKind.like}),
      ],
      verify: (_) {
        verify(() => repository.toggleLike('S0')).called(1);
      },
    );

    blocTest<FeedBloc, FeedState>(
      '비로그인이면 서버를 부르지 않고 로그인 신호를 낸다',
      build: () => build(userId: null),
      seed: () => FeedState(sightings: [makeSighting(id: 'S0')]),
      act: (bloc) => bloc.add(const FeedReactionToggled(
        kind: ReactionKind.like,
        sightingId: 'S0',
      )),
      expect: () => [
        isA<FeedState>()
            .having((s) => s.signal, '신호', FeedSignal.loginRequired),
      ],
      verify: (_) {
        verifyNever(() => repository.toggleLike(any()));
      },
    );

    blocTest<FeedBloc, FeedState>(
      '정지된 계정만 알린다 — 그 밖의 실패는 조용히 넘긴다',
      setUp: () {
        when(() => repository.toggleLike('S0')).thenThrow(AppError.unknown);
      },
      build: build,
      seed: () => FeedState(sightings: [makeSighting(id: 'S0')]),
      act: (bloc) => bloc.add(const FeedReactionToggled(
        kind: ReactionKind.like,
        sightingId: 'S0',
      )),
      skip: 1,
      expect: () => [
        isA<FeedState>()
            .having((s) => s.pendingReactions, '대기 없음', <ReactionKind>{})
            .having((s) => s.signal, '신호 없음', isNull),
      ],
    );
  });

  group('차단', () {
    blocTest<FeedBloc, FeedState>(
      '차단하면 그 유저 게시물을 피드에서 즉시 걷어내고 인덱스를 당긴다',
      setUp: () {
        when(() => repository.blockUser('U2')).thenAnswer((_) async {});
      },
      build: build,
      seed: () => FeedState(
        sightings: [
          makeSighting(id: 'S0', userId: 'U2'),
          makeSighting(id: 'S1', userId: 'U2'),
          makeSighting(id: 'S2', userId: 'U3'),
        ],
        currentIndex: 2,
      ),
      act: (bloc) => bloc.add(const FeedUserBlocked('U2')),
      expect: () => [
        isA<FeedState>()
            .having((s) => s.sightings.map((e) => e.id).toList(), '남은 목록',
                ['S2'])
            .having((s) => s.currentIndex, '인덱스 당김', 0)
            .having((s) => s.signal, '신호', FeedSignal.blocked),
      ],
    );
  });

  group('삭제', () {
    blocTest<FeedBloc, FeedState>(
      '삭제하면 목록에서 빼고 사진 경로를 같이 넘긴다',
      setUp: () {
        when(() => repository.delete(any(),
            photoUrls: any(named: 'photoUrls'))).thenAnswer((_) async {});
      },
      build: build,
      seed: () => FeedState(
        sightings: [makeSighting(id: 'S0'), makeSighting(id: 'S1')],
      ),
      act: (bloc) => bloc.add(const FeedSightingDeleted('S0')),
      expect: () => [
        isA<FeedState>()
            .having((s) => s.sightings.map((e) => e.id).toList(), '남은 목록',
                ['S1'])
            .having((s) => s.signal, '신호', FeedSignal.deleted),
      ],
      verify: (_) {
        verify(() => repository.delete(
              'S0',
              photoUrls: ['https://example.com/S0.jpg'],
            )).called(1);
      },
    );
  });

  group('신고', () {
    blocTest<FeedBloc, FeedState>(
      '실패하면 접수됨으로 끝내지 않는다',
      setUp: () {
        when(() => repository.report(
              sightingId: any(named: 'sightingId'),
              reason: any(named: 'reason'),
            )).thenThrow(AppError.unknown);
      },
      build: build,
      seed: () => FeedState(sightings: [makeSighting(id: 'S0')]),
      act: (bloc) => bloc.add(
        const FeedReported(sightingId: 'S0', reason: '스팸/광고'),
      ),
      expect: () => [
        isA<FeedState>()
            .having((s) => s.signal, '신호', FeedSignal.reportFailed),
      ],
    );
  });

  group('모델', () {
    test('표시용 주소는 동/읍/면/리/가 까지만 남긴다', () {
      const address = '서울특별시 강남구 역삼동 123-45';
      final sighting = Sighting(
        id: 'S0',
        userId: myUserId,
        photoUrls: const [],
        latitude: 0,
        longitude: 0,
        address: address,
        catType: CatType.stray,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      expect(sighting.displayAddress, '서울특별시 강남구 역삼동');
    });

    test('썸네일 URL 은 원본 경로에서 _thumb 을 유추한다', () {
      final sighting = makeSighting(id: 'S0');
      expect(sighting.thumbnailUrls, ['https://example.com/S0_thumb.jpg']);
    });

    test('created_at 은 UTC 로 고정한다 — 커서 페이징이 이 값으로 이어진다', () {
      final sighting = Sighting.fromRpcRow(const {
        'id': 'S0',
        'user_id': myUserId,
        'photo_urls': <String>[],
        'latitude': 0,
        'longitude': 0,
        'cat_type': 'stray',
        'created_at': '2026-01-01T09:00:00+09:00',
        'like_count': 0,
        'confirmation_count': 0,
      });
      expect(sighting.createdAt.isUtc, isTrue);
      expect(sighting.createdAt, DateTime.utc(2026, 1, 1, 0, 0, 0));
    });

    test('모르는 cat_type 은 길냥이로 떨어뜨린다', () {
      expect(CatType.fromRawValue('unknown_new_type'), CatType.stray);
    });
  });
}
