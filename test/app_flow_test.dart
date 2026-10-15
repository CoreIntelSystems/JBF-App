import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/app.dart';
import 'package:jbf_app/app_services.dart';
import 'package:jbf_app/features/portal/member_profile_screen.dart';
import 'package:jbf_app/data/connection.dart';
import 'package:jbf_app/data/repositories/audit_repository.dart';
import 'package:jbf_app/data/repositories/auth_repository.dart';
import 'package:jbf_app/data/secure_store.dart';
import 'package:jbf_app/data/sync/sync_api.dart';
import 'package:jbf_app/data/sync/sync_service.dart';
import 'package:jbf_app/domain/password_hasher.dart';
import 'package:jbf_app/features/auth/biometrics.dart';
import 'package:jbf_app/features/cloud/cloud_sync_screen.dart';
import 'package:jbf_app/features/dashboard/dashboard_screen.dart';
import 'package:jbf_app/features/members/member_form_screen.dart';
import 'package:jbf_app/features/more/more_screen.dart';
import 'package:jbf_app/features/payments/record_payment_screen.dart';

import 'fake_cloud.dart';

class _NoBiometrics extends Biometrics {
  @override
  Future<bool> isAvailable() async => false;
}

/// Pumps until [finder] appears, letting real async work (isolates, the
/// database) run between frames.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int tries = 100,
}) async {
  for (var i = 0; i < tries; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
  }
  final texts = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .join(' | ');
  throw TestFailure(
    'Timed out waiting for $finder. Showing: $texts. Exception: ${tester.takeException()}',
  );
}

void main() {
  testWidgets('first run: create admin, land on dashboard, see zones', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    // A typical Android phone with larger text, where layouts overflow first.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final db = openInMemoryDatabase();
    final services = AppServices(
      db: db,
      store: SecureStore(),
      deviceId: 'test',
    );
    await tester.pumpWidget(
      JbfApp(services: services, biometrics: _NoBiometrics()),
    );

    await pumpUntil(tester, find.text('Create account'));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Ama Owusu');
    await tester.enterText(fields.at(1), 'ama');
    await tester.enterText(fields.at(2), 'secret1');
    await tester.enterText(fields.at(3), 'secret1');
    await tester.ensureVisible(find.text('Create account'));
    await tester.pump();
    await tester.tap(find.text('Create account'));

    await pumpUntil(tester, find.text('Hello, Ama Owusu'));
    expect(find.text('Super Administrator'), findsOneWidget);
    await pumpUntil(tester, find.text('Collected today'));
    await tester.scrollUntilVisible(
      find.text('Zone 8 (Abrempong)'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(DashboardScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Zone 8 (Abrempong)'), findsOneWidget);

    // Register a member: a third zone is refused with a warning.
    await tester.tap(find.text('Members'));
    await pumpUntil(tester, find.text('Add member'));
    await tester.tap(find.text('Add member'));
    await pumpUntil(tester, find.byType(MemberFormScreen));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).first, 'Kofi Mensah');
    final formScroll = find
        .descendant(
          of: find.byType(MemberFormScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.widgetWithText(TextFormField, 'Mobile number *'),
      200,
      scrollable: formScroll,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mobile number *'),
      '0241234567',
    );
    for (final z in [
      'Zone 1 (Legends)',
      'Zone 2 (Pacesetters)',
      'Zone 3 (Elite)',
    ]) {
      await tester.scrollUntilVisible(
        find.widgetWithText(FilterChip, z),
        200,
        scrollable: formScroll,
      );
      await tester.tap(find.widgetWithText(FilterChip, z));
      await tester.pump();
    }
    expect(find.textContaining('at most 2 zones'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Primary zone'),
      200,
      scrollable: formScroll,
    );
    expect(find.text('Primary zone'), findsOneWidget);

    final registerButton = find.widgetWithText(FilledButton, 'Register member');
    await tester.scrollUntilVisible(
      registerButton,
      200,
      scrollable: formScroll,
    );
    await tester.pump();
    await tester.tap(registerButton);
    await pumpUntil(tester, find.text('Kofi Mensah'));
    expect(find.textContaining('JBF-000001'), findsWidgets);

    // Record a dues payment for Kofi and get a receipt.
    // Dismiss the queued zone-limit and registered snack bars.
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
        .clearSnackBars();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Payments'));
    await pumpUntil(tester, find.text('Record payment'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Record payment'));
    await pumpUntil(tester, find.text('Choose member'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Choose member'));
    await pumpUntil(tester, find.text('Kofi Mensah'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Kofi Mensah'));
    await pumpUntil(tester, find.text('Month paid for'));
    expect(find.text('Monthly welfare dues'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '20');
    final save = find.text('Save and issue receipt');
    await tester.scrollUntilVisible(
      save,
      200,
      scrollable: find
          .descendant(
            of: find.byType(RecordPaymentScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();
    await tester.tap(save);
    await pumpUntil(tester, find.text('Payment saved'));
    expect(find.textContaining('RCP-'), findsWidgets);
    expect(find.text('GHS 20.00'), findsOneWidget);
    expect(find.text('Share receipt (PDF)'), findsOneWidget);

    // Welfare: set a benefit amount, approve it, report, approve, pay.
    Future<void> tapAndWait(Finder f, Finder next) async {
      await tester.pump(const Duration(seconds: 1));
      if (f.evaluate().isEmpty) {
        // Lazy lists only build what is near the screen; it may be above.
        // The page's list: the last scrollable that is not inside a text
        // field (multi-line fields scroll too).
        final page = find
            .byType(Scrollable)
            .evaluate()
            .where(
              (e) => e.findAncestorWidgetOfExactType<EditableText>() == null,
            )
            .last;
        final list = find.byElementPredicate((e) => e == page);
        for (final step in [200.0, -200.0]) {
          try {
            await tester.scrollUntilVisible(
              f,
              step,
              scrollable: list,
              maxScrolls: 15,
            );
            break;
          } on StateError {
            // Not that way; try the other direction.
          }
        }
      }
      await tester.ensureVisible(f);
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
          .clearSnackBars();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(f);
      await pumpUntil(tester, next);
    }

    await tapAndWait(find.byTooltip('Back'), find.text('More'));
    await tapAndWait(find.text('More'), find.text('Welfare'));
    await tapAndWait(find.text('Welfare'), find.text('Welfare fund balance'));
    await tapAndWait(
      find.byTooltip('Benefit amounts'),
      find.text('Hospitalisation'),
    );
    await tapAndWait(
      find.text('Hospitalisation'),
      find.text('Send for approval'),
    );
    await tester.enterText(find.byType(TextField).last, '500');
    await tapAndWait(
      find.text('Send for approval'),
      find.textContaining('awaiting approval'),
    );
    await tapAndWait(
      find.widgetWithText(FilledButton, 'Approve'),
      find.text('GHS 500.00'),
    );
    await tapAndWait(find.byTooltip('Back'), find.text('New case'));
    await tapAndWait(find.text('New case'), find.text('Choose member'));
    await tapAndWait(find.text('Choose member'), find.text('Kofi Mensah'));
    await tapAndWait(find.text('Kofi Mensah'), find.text('Type of case'));
    await tapAndWait(
      find.text('Type of case'),
      find.text('Hospitalisation').last,
    );
    await tapAndWait(
      find.text('Hospitalisation').last,
      find.text('Fixed benefit for this type of case'),
    );
    expect(find.text('GHS 500.00'), findsOneWidget);
    await tapAndWait(
      find.text('Submit for approval'),
      find.text('WEL-${DateTime.now().year}-0001'),
    );
    await tapAndWait(find.text('Approve'), find.text('Approve this case?'));
    await tapAndWait(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Approve'),
      ),
      find.text('Record payout'),
    );
    await tapAndWait(find.text('Record payout'), find.text('Mark as paid'));
    await tapAndWait(find.text('Mark as paid'), find.text('Paid'));
    expect(find.textContaining('standing in'), findsNothing);

    // Expenses, then this month's report.
    await tapAndWait(find.byTooltip('Back'), find.text('Welfare fund balance'));
    await tapAndWait(find.byTooltip('Back'), find.text('Expenses'));
    await tapAndWait(find.text('Expenses'), find.text('Record expense'));
    await tapAndWait(find.text('Record expense'), find.text('Category'));
    await tapAndWait(
      find.text('Category'),
      find.text('Venue and hall hire').last,
    );
    await tapAndWait(
      find.text('Venue and hall hire').last,
      find.text('Save expense'),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'What was it for?'),
      'Hall for AGM',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '100');
    await tapAndWait(find.text('Save expense'), find.text('Hall for AGM'));
    await tapAndWait(find.byTooltip('Reports'), find.text('Closing balance'));
    await tester.scrollUntilVisible(
      find.text('Excel'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tapAndWait(find.byTooltip('Back'), find.text('Hall for AGM'));
    await tapAndWait(find.byTooltip('Back'), find.byType(MoreScreen));
    await tapAndWait(
      find.text('Backup and restore'),
      find.text('Create backup and share'),
    );
    await tapAndWait(find.byTooltip('Back'), find.byType(MoreScreen));
    await tapAndWait(find.text('Field phones'), find.text('How it works'));
    await tester.scrollUntilVisible(
      find.text('Import a collections file'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tapAndWait(find.byTooltip('Back'), find.byType(MoreScreen));
    await tapAndWait(
      find.text('Reminders'),
      find.text('Monthly dues reminder'),
    );
    await tapAndWait(
      find.text('Monthly dues reminder'),
      find.text('Day of the month'),
    );
    expect(await services.reminders.duesDay(), 1);
    await tapAndWait(
      find.byTooltip('Back'),
      find.text('Organisation settings'),
    );
    await tapAndWait(
      find.text('Organisation settings'),
      find.text('Receipt prefix on this phone'),
    );
    await tapAndWait(find.byTooltip('Back'), find.text('Payments'));

    // Meeting collection: tick Kofi and save.
    await tapAndWait(find.text('Payments'), find.byTooltip('Defaulters'));
    await tapAndWait(
      find.byTooltip('Meeting collection'),
      find.text('Tick the members who paid'),
    );
    await tester.enterText(find.widgetWithText(TextField, 'Amount each'), '20');
    await tapAndWait(find.text('Kofi Mensah'), find.textContaining('Save 1'));
    await tapAndWait(
      find.textContaining('Save 1'),
      find.text('Save 1 payments?'),
    );
    await tapAndWait(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Save'),
      ),
      find.byTooltip('Defaulters'),
    );
    await tapAndWait(find.byTooltip('Defaulters'), find.text('Defaulters'));

    // Events: create one and mark attendance.
    await tapAndWait(find.byTooltip('Back'), find.byTooltip('Defaulters'));
    await tapAndWait(find.text('More'), find.byType(MoreScreen));
    await tapAndWait(
      find.text('Events and meetings'),
      find.text('No events yet.'),
    );
    await tapAndWait(find.text('New event'), find.text('Event name'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Event name'),
      'Family picnic',
    );
    await tapAndWait(find.text('Save event'), find.text('Family picnic'));
    await tapAndWait(find.text('Family picnic'), find.text('Take attendance'));
    await tapAndWait(find.text('Take attendance'), find.text('Kofi Mensah'));
    await tapAndWait(
      find.byTooltip('Present: Kofi Mensah'),
      find.textContaining('1 present'),
    );
    await tapAndWait(find.byTooltip('Back'), find.text('Take attendance'));
    await tapAndWait(find.byTooltip('Back'), find.text('Meetings'));
    await tapAndWait(find.text('Meetings'), find.text('New meeting'));
    await tapAndWait(find.byTooltip('Back'), find.byType(MoreScreen));
    await tapAndWait(find.text('Executives'), find.text('Appoint'));
    await tapAndWait(find.text('Appoint'), find.text('Choose member'));
    await tapAndWait(find.byTooltip('Back'), find.text('Appoint'));
    await tapAndWait(find.byTooltip('Back'), find.byType(MoreScreen));
    await tapAndWait(find.text('Charts'), find.text('Monthly collections'));

    await tester.pumpWidget(const SizedBox());
    // Let snack bars and drift's stream clean-up timers finish.
    await tester.pump(const Duration(seconds: 5));
    // The in-memory database is dropped with the test; closing it from the
    // fake-async test zone would wait on stream queries that never resume.
  });

  testWidgets('a new phone signs in online and opens the dashboard', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final cloud = FakeCloud();
    final mainDb = openInMemoryDatabase();
    await tester.runAsync(() async {
      await AuthRepository(
        mainDb,
        AuditRepository(mainDb),
        hasher: const PasswordHasher(iterations: 10),
      ).createInitialAdmin(
        displayName: 'Ama Owusu',
        username: 'ama',
        password: 'secret1',
        deviceId: 'main',
      );
      final mainSync = SyncService(mainDb, cloud.api, MemorySyncPrefs());
      await mainSync.load();
      await mainSync.join(code: cloud.newCode(admin: true), deviceName: 'Main');
      await mainSync.close();
    });

    final services = AppServices(
      db: openInMemoryDatabase(),
      store: SecureStore(),
      deviceId: 'new',
      syncApi: cloud.api,
      syncPrefs: MemorySyncPrefs(),
    );
    await tester.pumpWidget(
      JbfApp(services: services, biometrics: _NoBiometrics()),
    );
    const button = 'Sign in online with an old username';
    await pumpUntil(tester, find.text(button));
    await tester.ensureVisible(find.text(button));
    await tester.tap(find.text(button));
    await pumpUntil(tester, find.text('Organisation'));
    final fields = find.descendant(
      of: find.byType(JoinCloudScreen),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.at(1), 'ama');
    await tester.enterText(fields.at(2), 'secret1');
    final connect = find.widgetWithText(FilledButton, 'Sign in and connect');
    await tester.ensureVisible(connect);
    await tester.pump();
    await tester.tap(connect);
    await pumpUntil(tester, find.text('Hello, Ama Owusu'), tries: 600);
    expect(services.sync.state.credentials?.series, 'P2');
    services.sync.stopAuto();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    await tester.runAsync(mainDb.close);
  });

  testWidgets('a member activates and sees their own page', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final asked = <Map<String, Object?>>[];
    final sent = <String>[];
    final saved = <Map<String, Object?>>[];
    final api = SyncApi((fn, args) async {
      switch (fn) {
        case 'member_update_profile':
          saved.add(args);
          return {'ok': true};
        case 'fn:member-auth':
          asked.add(args);
          if (args['phone'] != '0241234567') {
            throw SyncException(
              'Member ID and phone number do not match our records.',
            );
          }
          return {
            'kind': 'member',
            'token': 'mtok',
            'member_key': 'm1',
            'member_no': 'JBF-000001',
            'name': 'Kofi Mensah',
            'org_name': 'June Borns Family',
          };
        case 'member_home':
          expect(args['token'], 'mtok');
          return {
            'org': 'June Borns Family',
            'member': {
              'name': 'Kofi Mensah',
              'member_no': 'JBF-000001',
              'status': 'active',
              'joined': '2026-01-10',
              'zones': ['Zone 1'],
            },
            'dues': [
              {
                'name': 'Monthly welfare dues',
                'monthly': 2000,
                'months': 10,
                'expected': 20000,
                'paid': 6000,
                'outstanding': 14000,
                'months_behind': 7,
                'next_unpaid': '2026-04',
              },
            ],
            'payments': [
              {
                'receipt_no': 'RCP-2026-000003',
                'paid_on': '2026-03-05',
                'type': 'Monthly welfare dues',
                'period': '2026-03',
                'amount': 2000,
                'method': 'momo',
              },
            ],
            'updated': '2026-10-15T08:00:00+00:00',
            'officer': false,
            'welfare': [],
            'events': [],
            'executives': [
              {'name': 'Ama Owusu', 'position': 'Founder / President'},
            ],
            'directory': [
              {
                'name': 'Kofi Mensah',
                'zones': ['Zone 1'],
              },
            ],
            'announcements': [],
            'roles': ['Zone Secretary (Zone 1)'],
            'self_edit': true,
            'profile': {
              'full_name': 'Kofi Mensah',
              'phone': '0241234567',
              'gender': 'Male',
            },
            'zone_options': [
              {'id': 'z1', 'code': 1, 'name': 'Zone 1'},
              {'id': 'z2', 'code': 2, 'name': 'Zone 2'},
            ],
            'zone_ids': ['z1'],
          };
        case 'member_sign_out':
          return null;
        case 'chat_channels':
          return [
            {'id': 'announcements', 'name': 'Announcements', 'post': false},
            {'id': 'members', 'name': 'All members', 'post': true},
          ];
        case 'chat_messages':
          expect(args['channel'], 'members');
          return [
            for (final (i, body) in sent.indexed)
              if (args['after'] == null || i == sent.length - 1)
                {
                  'id': 'm$i',
                  'author': 'Kofi Mensah',
                  'body': body,
                  'at': '2026-10-15T12:0$i:00Z',
                  'mine': true,
                },
          ];
        case 'chat_send':
          sent.add(args['body']! as String);
          return {'ok': true};
      }
      fail('unexpected $fn');
    });
    final services = AppServices(
      db: openInMemoryDatabase(),
      store: SecureStore(),
      deviceId: 'member',
      syncApi: api,
      syncPrefs: MemorySyncPrefs(),
    );
    await tester.pumpWidget(
      JbfApp(services: services, biometrics: _NoBiometrics()),
    );
    const button = 'First time? Activate your account';
    await pumpUntil(tester, find.text(button));
    await tester.tap(find.text(button));
    await pumpUntil(tester, find.text('Activate and sign in'));
    await tester.enterText(find.byKey(const Key('memberNo')), 'jbf-000001');
    await tester.enterText(find.byKey(const Key('memberPhone')), '0200000000');
    await tester.enterText(find.byKey(const Key('memberPassword')), 'kofi123');
    await tester.enterText(find.byKey(const Key('memberConfirm')), 'kofi123');
    await tester.tap(find.text('Activate and sign in'));
    await pumpUntil(
      tester,
      find.text('Member ID and phone number do not match our records.'),
    );
    await tester.enterText(find.byKey(const Key('memberPhone')), '0241234567');
    await tester.tap(find.text('Activate and sign in'));
    await pumpUntil(tester, find.text('GHS 140.00'));
    expect(asked.last, {
      'action': 'activate',
      'org': 'JBF',
      'member_no': 'jbf-000001',
      'new_password': 'kofi123',
      'phone': '0241234567',
      'check': false,
    });
    expect(
      find.textContaining('7 months behind, from Apr 2026'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Mobile money · RCP-2026-000003'),
      findsOneWidget,
    );
    await tester.tap(find.text('People'));
    await pumpUntil(tester, find.text('Ama Owusu'));
    expect(find.text('Founder / President'), findsOneWidget);
    await tester.tap(find.text('Chats').last);
    await pumpUntil(tester, find.text('All members'));
    await tester.tap(find.text('All members'));
    await pumpUntil(tester, find.text('No messages yet.'));
    // Let the page finish sliding in.
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(find.byKey(const Key('chatText')), 'Hello all');
    await tester.tap(find.byTooltip('Send'));
    await pumpUntil(
      tester,
      find.descendant(of: find.byType(Card), matching: find.text('Hello all')),
    );
    expect(sent, ['Hello all']);
    await tester.pageBack();
    await pumpUntil(tester, find.text('Me'));
    await tester.tap(find.text('Me'));
    await pumpUntil(tester, find.text('MEMBERSHIP CARD'));
    expect(find.text('Zone Secretary (Zone 1)'), findsOneWidget);
    await tester.tap(find.text('Edit my details and zones'));
    await pumpUntil(tester, find.text('My details'));
    await tester.enterText(
      find.byKey(const Key('profile_full_name')),
      'Kofi A. Mensah',
    );
    final form = find
        .descendant(
          of: find.byType(MemberProfileScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(find.text('Zone 2'), 200, scrollable: form);
    await tester.tap(find.text('Zone 2'));
    await tester.pump();
    await tester.tap(find.text('Zone 1'));
    await tester.pump();
    await tester.tap(find.text('Save').first);
    await pumpUntil(tester, find.text('MEMBERSHIP CARD'));
    expect(saved.single['zone_ids'], ['z2']);
    expect((saved.single['patch']! as Map)['full_name'], 'Kofi A. Mensah');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Sign out'), findsOneWidget);
    services.sync.stopAuto();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
