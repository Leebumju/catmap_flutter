import 'package:bloc_test/bloc_test.dart';
import 'package:catmap_flutter/domain/models/app_error.dart';
import 'package:catmap_flutter/domain/models/comment.dart';
import 'package:catmap_flutter/domain/repositories/auth_repository.dart';
import 'package:catmap_flutter/domain/repositories/comment_repository.dart';
import 'package:catmap_flutter/domain/repositories/sighting_repository.dart';
import 'package:catmap_flutter/features/comments/bloc/comments_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCommentRepository extends Mock implements CommentRepository {}

class MockSightingRepository extends Mock implements SightingRepository {}

class FakeAuthRepository extends Fake implements AuthRepository {
  FakeAuthRepository(this._userId);

  final String? _userId;

  @override
  String? currentUserId() => _userId;
}

const sightingId = 'S1';
const myUserId = 'U1';

Comment makeComment(
  String id, {
  String userId = myUserId,
  String? parentId,
  int replyCount = 0,
  DateTime? createdAt,
}) {
  return Comment(
    id: id,
    sightingId: sightingId,
    userId: userId,
    parentId: parentId,
    content: '댓글 $id',
    createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
    replyCount: replyCount,
  );
}

List<Comment> page(int count, {int startIndex = 0}) {
  return List.generate(
    count,
    (i) => makeComment(
      'C${startIndex + i}',
      createdAt:
          DateTime.utc(2026, 1, 1).subtract(Duration(minutes: startIndex + i)),
    ),
  );
}

void main() {
  late MockCommentRepository comments;
  late MockSightingRepository sightings;

  setUp(() {
    comments = MockCommentRepository();
    sightings = MockSightingRepository();
    when(() => comments.fetch(
          sightingId: any(named: 'sightingId'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => page(3));
  });

  CommentsBloc build({String? userId = myUserId}) => CommentsBloc(
        commentRepository: comments,
        authRepository: FakeAuthRepository(userId),
        sightingRepository: sightings,
        sightingId: sightingId,
      );

  group('불러오기', () {
    blocTest<CommentsBloc, CommentsState>(
      '한 페이지보다 적게 오면 다음 페이지가 없다고 본다',
      build: build,
      act: (bloc) => bloc.add(const CommentsStarted()),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.comments.length, 3);
        expect(bloc.state.hasMorePages, isFalse);
      },
    );

    blocTest<CommentsBloc, CommentsState>(
      '추가 로드가 실패해도 페이징을 영구히 막지 않는다',
      build: () {
        when(() => comments.fetch(
              sightingId: any(named: 'sightingId'),
              cursor: null,
              limit: any(named: 'limit'),
            )).thenAnswer((_) async => page(CommentsState.pageSize));
        when(() => comments.fetch(
              sightingId: any(named: 'sightingId'),
              cursor: any(named: 'cursor', that: isNotNull),
              limit: any(named: 'limit'),
            )).thenThrow(Exception('네트워크'));
        return build();
      },
      act: (bloc) async {
        bloc.add(const CommentsStarted());
        await Future<void>.delayed(const Duration(milliseconds: 30));
        bloc.add(const CommentsLoadMoreRequested());
      },
      wait: const Duration(milliseconds: 100),
      verify: (bloc) => expect(bloc.state.hasMorePages, isTrue),
    );

    blocTest<CommentsBloc, CommentsState>(
      '커서 경계에서 겹쳐 온 댓글은 id 로 걸러낸다',
      build: () {
        when(() => comments.fetch(
              sightingId: any(named: 'sightingId'),
              cursor: null,
              limit: any(named: 'limit'),
            )).thenAnswer((_) async => page(CommentsState.pageSize));
        when(() => comments.fetch(
              sightingId: any(named: 'sightingId'),
              cursor: any(named: 'cursor', that: isNotNull),
              limit: any(named: 'limit'),
            )).thenAnswer((_) async => page(CommentsState.pageSize));
        return build();
      },
      act: (bloc) async {
        bloc.add(const CommentsStarted());
        await Future<void>.delayed(const Duration(milliseconds: 30));
        bloc.add(const CommentsLoadMoreRequested());
      },
      wait: const Duration(milliseconds: 100),
      verify: (bloc) =>
          expect(bloc.state.comments.length, CommentsState.pageSize),
    );
  });

  group('답글', () {
    blocTest<CommentsBloc, CommentsState>(
      '펼치면 받아오고, 다시 눌러 접었다 펴도 또 받지 않는다',
      build: () {
        when(() => comments.fetchReplies('C0'))
            .thenAnswer((_) async => [makeComment('R1', parentId: 'C0')]);
        return build();
      },
      act: (bloc) async {
        bloc.add(const CommentsRepliesToggled('C0'));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        bloc.add(const CommentsRepliesToggled('C0'));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const CommentsRepliesToggled('C0'));
      },
      wait: const Duration(milliseconds: 100),
      verify: (bloc) {
        verify(() => comments.fetchReplies('C0')).called(1);
        expect(bloc.state.expandedReplies.contains('C0'), isTrue);
      },
    );

    blocTest<CommentsBloc, CommentsState>(
      '답글을 못 받으면 다시 접는다 — 빈 채로 펼쳐두면 답글이 없는 것처럼 보인다',
      build: () {
        when(() => comments.fetchReplies('C0')).thenThrow(Exception('네트워크'));
        return build();
      },
      act: (bloc) => bloc.add(const CommentsRepliesToggled('C0')),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) => expect(bloc.state.expandedReplies, isEmpty),
    );
  });

  group('작성', () {
    setUp(() {
      when(() => comments.add(
            sightingId: any(named: 'sightingId'),
            content: any(named: 'content'),
            parentId: any(named: 'parentId'),
          )).thenAnswer((invocation) async => makeComment(
            'NEW',
            parentId: invocation.namedArguments[#parentId] as String?,
          ));
    });

    blocTest<CommentsBloc, CommentsState>(
      '공백만 있으면 보낼 수 없다',
      build: build,
      act: (bloc) => bloc.add(const CommentsInputChanged('   ')),
      verify: (bloc) => expect(bloc.state.canSubmit, isFalse),
    );

    blocTest<CommentsBloc, CommentsState>(
      '500자를 넘겨 입력하면 500자에서 자른다',
      build: build,
      act: (bloc) => bloc.add(CommentsInputChanged('가' * 600)),
      verify: (bloc) => expect(bloc.state.inputText.length, 500),
    );

    blocTest<CommentsBloc, CommentsState>(
      '비로그인이면 서버를 부르지 않고 로그인을 요구한다',
      build: () => build(userId: null),
      act: (bloc) async {
        bloc.add(const CommentsInputChanged('안녕'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CommentsSubmitted());
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.signal, CommentsSignal.loginRequired);
        verifyNever(() => comments.add(
              sightingId: any(named: 'sightingId'),
              content: any(named: 'content'),
              parentId: any(named: 'parentId'),
            ));
      },
    );

    blocTest<CommentsBloc, CommentsState>(
      '최상위 댓글은 맨 앞에 붙는다 — 목록이 최신순이다',
      build: build,
      seed: () => CommentsState(
        sightingId: sightingId,
        comments: [makeComment('C0')],
        inputText: '새 댓글',
        currentUserId: myUserId,
      ),
      act: (bloc) => bloc.add(const CommentsSubmitted()),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.comments.first.id, 'NEW');
        expect(bloc.state.inputText, isEmpty);
      },
    );

    blocTest<CommentsBloc, CommentsState>(
      '답글을 달면 부모의 답글 수가 하나 오른다',
      build: build,
      seed: () => CommentsState(
        sightingId: sightingId,
        comments: [makeComment('C0', replyCount: 2)],
        replies: {
          'C0': [makeComment('R1', parentId: 'C0')],
        },
        replyingTo: makeComment('C0', replyCount: 2),
        inputText: '답글',
        currentUserId: myUserId,
      ),
      act: (bloc) => bloc.add(const CommentsSubmitted()),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.comments.first.replyCount, 3);
        expect(bloc.state.replies['C0']!.length, 2);
        // 보낸 뒤에는 답글 모드가 풀린다.
        expect(bloc.state.replyingTo, isNull);
      },
    );

    blocTest<CommentsBloc, CommentsState>(
      '정지 계정이면 그 사실을 알린다',
      build: () {
        when(() => comments.add(
              sightingId: any(named: 'sightingId'),
              content: any(named: 'content'),
              parentId: any(named: 'parentId'),
            )).thenThrow(AppError.accountBanned);
        return build();
      },
      seed: () => const CommentsState(
        sightingId: sightingId,
        inputText: '안녕',
        currentUserId: myUserId,
      ),
      act: (bloc) => bloc.add(const CommentsSubmitted()),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) =>
          expect(bloc.state.signal, CommentsSignal.accountBanned),
    );
  });

  group('삭제와 차단', () {
    blocTest<CommentsBloc, CommentsState>(
      '답글을 지우면 부모의 답글 수가 하나 내려간다',
      build: () {
        when(() => comments.delete('R1')).thenAnswer((_) async {});
        return build();
      },
      seed: () => CommentsState(
        sightingId: sightingId,
        comments: [makeComment('C0', replyCount: 1)],
        replies: {
          'C0': [makeComment('R1', parentId: 'C0')],
        },
        currentUserId: myUserId,
      ),
      act: (bloc) => bloc.add(const CommentsDeleted('R1')),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.comments.first.replyCount, 0);
        expect(bloc.state.replies['C0'], isEmpty);
      },
    );

    blocTest<CommentsBloc, CommentsState>(
      '차단하면 그 사람의 댓글과 답글을 화면에서 바로 걷어낸다',
      build: () {
        when(() => sightings.blockUser('U2')).thenAnswer((_) async {});
        return build();
      },
      seed: () => CommentsState(
        sightingId: sightingId,
        comments: [makeComment('C0'), makeComment('C1', userId: 'U2')],
        replies: {
          'C0': [
            makeComment('R1', parentId: 'C0', userId: 'U2'),
            makeComment('R2', parentId: 'C0'),
          ],
        },
        currentUserId: myUserId,
      ),
      act: (bloc) => bloc.add(const CommentsUserBlocked('U2')),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.comments.map((c) => c.id), ['C0']);
        expect(bloc.state.replies['C0']!.map((c) => c.id), ['R2']);
        expect(bloc.state.signal, CommentsSignal.blocked);
      },
    );
  });
}
