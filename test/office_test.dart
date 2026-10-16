import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/data/sync/sync_api.dart';
import 'package:jbf_app/features/offices/office_api.dart';
import 'package:jbf_app/features/offices/office_screen.dart';

Map<String, Object?> _home({required bool lead, int steps = 0}) => {
  'key': 'ec',
  'name': 'Electoral Commission',
  'purpose': 'Prepares and runs the elections.',
  'me': 'm1',
  'role': lead ? 'chair' : 'member',
  'role_name': lead ? 'Chairperson' : 'Member',
  'lead': lead,
  'has_checklist': true,
  'members': [
    {
      'key': 'm1',
      'name': 'Ama Mensah',
      'member_no': 'JBF-000001',
      'role_name': lead ? 'Chairperson' : 'Member',
      'lead': lead,
    },
    {
      'key': 'm2',
      'name': 'Kofi Boateng',
      'member_no': 'JBF-000002',
      'role_name': 'Secretary',
      'lead': true,
    },
  ],
  'tasks': [
    {
      'id': 't1',
      'title': 'Book the hall',
      'status': 'open',
      'assignee': 'm1',
      'assignee_name': 'Ama Mensah',
      'mine': false,
    },
    {
      'id': 't2',
      'title': 'Agree the timetable',
      'status': 'done',
      'done_by': 'Kofi Boateng',
      'mine': false,
    },
  ],
  'notes': [
    {
      'id': 'n1',
      'kind': 'decision',
      'title': 'Voting closes at 6 pm',
      'body': 'Agreed by all.',
      'by': 'Kofi Boateng',
      'mine': false,
    },
  ],
  'notices': <Object>[],
  'log': [
    {'by': 'Kofi Boateng', 'event': 'Added a task', 'detail': 'Book the hall'},
  ],
  'roll': {
    'active': 453,
    'ready': 4,
    'zones': [
      {'zone': 'Zone 1', 'active': 3, 'ready': 2},
    ],
  },
  'elections': [
    {
      'id': 'e1',
      'title': '2027 Elections',
      'status': 'draft',
      'voters': 0,
      'steps': steps,
      'steps_done': 0,
    },
  ],
};

void main() {
  late List<(String, Map<String, Object?>)> calls;

  Future<void> pumpOffice(WidgetTester tester, {required bool lead}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    calls = [];
    final api = OfficeApi(
      SyncApi((fn, args) async {
        calls.add((fn, args));
        return fn == 'office_home' ? _home(lead: lead) : {'ok': true};
      }),
      'tok',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: OfficeScreen(
          api: api,
          committee: 'ec',
          title: 'Electoral Commission',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the overview shows the people, elections and voter roll', (
    tester,
  ) async {
    await pumpOffice(tester, lead: true);
    expect(find.text('You: Chairperson'), findsOneWidget);
    expect(find.text('2027 Elections'), findsOneWidget);
    expect(find.text('453'), findsOneWidget);
    expect(find.textContaining('449 active members have not'), findsOneWidget);
    expect(find.text('Secretary'), findsOneWidget);

    await tester.tap(find.text('Add the standard steps'));
    await tester.pumpAndSettle();
    expect(
      calls.where((c) => c.$1 == 'office_add_checklist').single.$2,
      containsPair('election', 'e1'),
    );
  });

  testWidgets('tasks can be ticked off and added', (tester) async {
    await pumpOffice(tester, lead: false);
    expect(find.text('Add the standard steps'), findsNothing);
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    expect(find.text('Book the hall'), findsOneWidget);
    expect(find.text('Agree the timetable'), findsNothing, reason: 'done');

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    final done = calls.where((c) => c.$1 == 'office_task_done').single.$2;
    expect(done['id'], 't1');
    expect(done['done'], true);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Agree the timetable'), findsOneWidget);

    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'What needs doing'),
      'Print the voter list',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = calls.where((c) => c.$1 == 'office_task_save').single.$2;
    expect(saved['title'], 'Print the voter list');
    expect(saved['id'], isNull);
  });

  testWidgets('only leads can post notices; anyone can read the minutes', (
    tester,
  ) async {
    await pumpOffice(tester, lead: false);
    await tester.tap(find.text('Minutes'));
    await tester.pumpAndSettle();
    expect(find.text('Voting closes at 6 pm'), findsOneWidget);
    await tester.tap(find.text('Notices'));
    await tester.pumpAndSettle();
    expect(find.text('Post notice'), findsNothing);
  });

  testWidgets('a lead posts a notice to every member', (tester) async {
    await pumpOffice(tester, lead: true);
    await tester.tap(find.text('Notices'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Post notice'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Nominations are open',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Notice'),
      'Send names to the Secretary by Friday.',
    );
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();
    final posted = calls.where((c) => c.$1 == 'office_notice_post').single.$2;
    expect(posted['title'], 'Nominations are open');
  });

  testWidgets(
    'the Disciplinary office shows its cases and adds hearing steps',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final calls = <(String, Map<String, Object?>)>[];
      final home = {
        ..._home(lead: true),
        'key': 'discipline',
        'name': 'Disciplinary Committee',
        'chat': 'discipline',
        'elections': null,
        'roll': null,
        'cases': {
          'open': 1,
          'closed': 0,
          'warnings': 2,
          'recent': [
            {
              'id': 'c1',
              'kind': 'complaint',
              'status': 'open',
              'member_name': 'Eddie Nii',
              'member_no': 'JBF-000106',
              'details': 'Rude at the meeting',
              'by': 'Zone 1 Secretary',
              'steps': 0,
              'steps_done': 0,
            },
          ],
        },
      }..removeWhere((k, v) => v == null);
      final api = OfficeApi(
        SyncApi((fn, args) async {
          calls.add((fn, args));
          return fn == 'office_home' ? home : {'ok': true};
        }),
        'tok',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: OfficeScreen(
            api: api,
            committee: 'discipline',
            title: 'Disciplinary Committee',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open complaints'), findsOneWidget);
      expect(find.text('Eddie Nii · JBF-000106'), findsOneWidget);
      expect(find.text('Voter roll'.toUpperCase()), findsNothing);
      await tester.tap(find.text('Add the hearing steps'));
      await tester.pumpAndSettle();
      expect(
        calls.where((c) => c.$1 == 'office_add_case_steps').single.$2,
        containsPair('case_id', 'c1'),
      );
    },
  );

  testWidgets('the Organizing office lists events and adds planning steps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final calls = <(String, Map<String, Object?>)>[];
    final home = {
      ..._home(lead: true),
      'key': 'organizing',
      'name': 'Organizing Committee',
      'chat': 'organizing',
      'events': [
        {
          'id': 'ev-1',
          'name': 'End of year party',
          'status': 'planned',
          'starts_on': '2026-12-20T15:00:00.000',
          'venue': 'Accra',
          'present': 0,
          'steps': 0,
          'steps_done': 0,
        },
        {
          'id': 'ev-0',
          'name': 'Picnic',
          'status': 'held',
          'starts_on': '2026-08-01T10:00:00.000',
          'present': 42,
          'steps': 0,
          'steps_done': 0,
        },
      ],
    }..removeWhere((k, _) => k == 'elections' || k == 'roll');
    final api = OfficeApi(
      SyncApi((fn, args) async {
        calls.add((fn, args));
        return fn == 'office_home' ? home : {'ok': true};
      }),
      'tok',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: OfficeScreen(
          api: api,
          committee: 'organizing',
          title: 'Organizing Committee',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('End of year party'), findsOneWidget);
    expect(find.text('42 attended'), findsOneWidget);
    await tester.tap(find.text('Add the planning steps'));
    await tester.pumpAndSettle();
    expect(
      calls.where((c) => c.$1 == 'office_add_event_steps').single.$2,
      containsPair('event', 'ev-1'),
    );
  });
}
