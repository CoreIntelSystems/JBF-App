import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/data/sync/sync_api.dart';
import 'package:jbf_app/features/elections/ballot_screen.dart';
import 'package:jbf_app/features/elections/election_admin.dart';
import 'package:jbf_app/features/elections/election_api.dart';
import 'package:jbf_app/features/elections/results_screen.dart';

void main() {
  final election = {
    'id': 'e1',
    'title': '2027 Elections',
    'posts': [
      {
        'id': 'p1',
        'title': 'President',
        'seats': 1,
        'candidates': [
          {'id': 'c1', 'name': 'Ama Mensah', 'member_no': 'JBF-000001'},
          {'id': 'c2', 'name': 'Kofi Boateng', 'member_no': 'JBF-000002'},
        ],
      },
      {
        'id': 'p2',
        'title': 'Secretary',
        'seats': 1,
        'candidates': [
          {'id': 'c3', 'name': 'Esi Owusu', 'member_no': 'JBF-000003'},
        ],
      },
    ],
  };

  testWidgets('the ballot needs a choice for every post, then casts it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final calls = <(String, Map<String, Object?>)>[];
    final api = ElectionApi(
      SyncApi((fn, args) async {
        calls.add((fn, args));
        return {'ok': true};
      }),
      'tok',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BallotScreen(api: api, election: election),
      ),
    );
    FilledButton cast() => tester.widget(find.byType(FilledButton));
    expect(cast().onPressed, isNull);

    await tester.tap(find.text('Ama Mensah'));
    await tester.pump();
    expect(cast().onPressed, isNull, reason: 'one post is still empty');

    await tester.tap(find.text('Abstain').last);
    await tester.pump();
    expect(cast().onPressed, isNotNull);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('President: Ama Mensah'), findsOneWidget);
    expect(find.text('Secretary: No one (abstain)'), findsOneWidget);

    await tester.tap(find.text('Cast my vote'));
    await tester.pumpAndSettle();
    expect(find.text('Your vote has been recorded.'), findsOneWidget);
    final vote = calls.single;
    expect(vote.$1, 'election_vote');
    expect(vote.$2['choices'], {'p1': 'c1', 'p2': 'abstain'});
  });

  testWidgets('an already-voted answer from the cloud is shown, not hidden', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = ElectionApi(
      SyncApi(
        (fn, args) async => throw SyncException('You have already voted.'),
      ),
      'tok',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BallotScreen(api: api, election: election),
      ),
    );
    await tester.tap(find.text('Kofi Boateng'));
    await tester.tap(find.text('Esi Owusu'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cast my vote'));
    await tester.pumpAndSettle();
    expect(find.text('You have already voted.'), findsOneWidget);
  });

  testWidgets('results show the winner and flag a tie', (tester) async {
    final api = ElectionApi(
      SyncApi(
        (fn, args) async => {
          'title': '2027 Elections',
          'voters': 10,
          'log_ok': true,
          'posts': [
            {
              'id': 'p1',
              'title': 'President',
              'seats': 1,
              'ballots': 5,
              'voted': 5,
              'abstained': 0,
              'candidates': [
                {'id': 'c1', 'name': 'Ama Mensah', 'votes': 3},
                {'id': 'c2', 'name': 'Kofi Boateng', 'votes': 2},
              ],
            },
            {
              'id': 'p2',
              'title': 'Treasurer',
              'seats': 1,
              'ballots': 4,
              'voted': 4,
              'abstained': 0,
              'candidates': [
                {'id': 'c3', 'name': 'Esi Owusu', 'votes': 2},
                {'id': 'c4', 'name': 'Yaw Addo', 'votes': 2},
              ],
            },
          ],
        },
      ),
      'tok',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ResultsScreen(api: api, id: 'e1'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Elected'), findsOneWidget);
    expect(find.textContaining('tie for the last seat'), findsOneWidget);
  });

  testWidgets('a draft can be changed: seats, a post taken out', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final calls = <(String, Map<String, Object?>)>[];
    final api = ElectionApi(
      SyncApi((fn, args) async {
        calls.add((fn, args));
        return {'ok': true};
      }),
      'tok',
    );
    final draft = {
      ...election,
      'status': 'draft',
      'notes': 'Vote well',
      'closes_at': DateTime.now()
          .add(const Duration(days: 5))
          .toUtc()
          .toIso8601String(),
    };
    await tester.pumpWidget(
      MaterialApp(
        home: CreateElectionScreen(api: api, existing: draft),
      ),
    );
    expect(find.text('Change election'), findsOneWidget);
    expect(find.text('2027 Elections'), findsOneWidget);
    expect(find.text('Secretary'), findsOneWidget);

    await tester.tap(find.byTooltip('Take this post out').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take it out'));
    await tester.pumpAndSettle();
    expect(find.text('Secretary'), findsNothing);

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    final (fn, args) = calls.single;
    expect(fn, 'election_update');
    expect(args['eid'], 'e1');
    expect(args['posts'], [
      {'id': 'p1', 'title': 'President', 'seats': 1},
    ]);
  });

  testWidgets('a draft candidate can be taken off the ballot', (tester) async {
    final calls = <(String, Map<String, Object?>)>[];
    final api = ElectionApi(
      SyncApi((fn, args) async {
        calls.add((fn, args));
        return {'ok': true};
      }),
      'tok',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CandidateEditor(
          api: api,
          postId: 'p1',
          postTitle: 'President',
          existing: const {
            'id': 'c1',
            'name': 'Ama Mensah',
            'member_no': 'JBF-000001',
            'member_key': 'm1',
            'manifesto': 'Unity',
          },
        ),
      ),
    );
    expect(find.text('Unity'), findsOneWidget);
    await tester.tap(find.text('Take off the ballot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take off'));
    await tester.pumpAndSettle();
    expect(calls.single.$1, 'election_remove_candidate');
    expect(calls.single.$2['cid'], 'c1');
  });
}
