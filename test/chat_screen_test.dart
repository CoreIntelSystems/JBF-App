import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/data/sync/sync_api.dart';
import 'package:jbf_app/features/chats/chats_screen.dart';

void main() {
  late List<(String, Map<String, Object?>)> calls;

  final messages = [
    {
      'id': 'm1',
      'author': 'Ama Mensah',
      'author_key': 'k1',
      'author_whatsapp': 'Ama JBF',
      'zones': ['Zone 2', 'Zone 4'],
      'body': 'Good evening everyone',
      'at': '2026-10-18T10:00:00Z',
      'mine': false,
      'kind': 'text',
    },
    {
      'id': 'm2',
      'author': 'Kofi Boateng',
      'author_key': 'k2',
      'zones': [],
      'body': 'Welcome',
      'at': '2026-10-18T10:01:00Z',
      'mine': true,
      'kind': 'text',
      'reply': {
        'id': 'm1',
        'author': 'Ama Mensah',
        'body': 'Good evening everyone',
        'kind': 'text',
      },
    },
    {
      'id': 'm3',
      'author': 'Ama Mensah',
      'author_key': 'k1',
      'zones': ['Zone 2', 'Zone 4'],
      'body': '🙏',
      'at': '2026-10-18T10:02:00Z',
      'mine': false,
      'kind': 'sticker',
    },
    {
      'id': 'm4',
      'author': 'Ama Mensah',
      'author_key': 'k1',
      'zones': ['Zone 2', 'Zone 4'],
      'body': '',
      'at': '2026-10-18T10:03:00Z',
      'mine': false,
      'kind': 'file',
      'file': {
        'id': 'f1',
        'name': 'minutes.pdf',
        'mime': 'application/pdf',
        'size': 52000,
      },
    },
  ];

  SyncApi api() {
    calls = [];
    return SyncApi((fn, args) async {
      calls.add((fn, args));
      return switch (fn) {
        'chat_messages' => messages,
        'chat_avatars' => <String, Object?>{},
        _ => {'ok': true},
      };
    });
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          api: api(),
          access: const ChatAccess('tok'),
          channel: const ChatChannel(id: 'c', name: 'General', canPost: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows names, WhatsApp name, zones, quotes, stickers and files', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Ama Mensah'), findsWidgets);
    expect(find.textContaining('~Ama JBF'), findsOneWidget);
    expect(find.text('Zone 2'), findsWidgets);
    expect(find.text('Zone 4'), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            RegExp(
              r'^(Today|Yesterday|\d{1,2} \w{3} \d{4})$',
            ).hasMatch(w.data ?? ''),
      ),
      findsOneWidget,
    ); // one day chip for the day
    expect(
      find.text('Good evening everyone'),
      findsNWidgets(2),
    ); // message + quote
    expect(find.text('🙏'), findsOneWidget);
    expect(find.text('minutes.pdf'), findsOneWidget);
    expect(find.byKey(const Key('avatar-m1')), findsOneWidget);
  });

  testWidgets('long press, reply, and the answer carries the quoted message', (
    tester,
  ) async {
    await open(tester);
    await tester.longPress(find.byKey(const Key('msg-m1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('menuReply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('replyBar')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('chatText')), 'Thank you');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    final post = calls.firstWhere((c) => c.$1 == 'chat_post');
    expect(post.$2['reply_to'], 'm1');
    expect(post.$2['body'], 'Thank you');
    expect(post.$2['kind'], 'text');
    expect(find.byKey(const Key('replyBar')), findsNothing);
  });

  testWidgets('a member can report another member\'s message', (tester) async {
    await open(tester);
    await tester.longPress(find.byKey(const Key('msg-m1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('menuReport')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('reportReason')), 'Rude');
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    final report = calls.firstWhere((c) => c.$1 == 'chat_report');
    expect(report.$2['msg'], 'm1');
    expect(report.$2['reason'], 'Rude');
  });

  testWidgets('blocking hides that member\'s messages', (tester) async {
    await open(tester);
    await tester.longPress(find.byKey(const Key('msg-m1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('menuBlock')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    final block = calls.firstWhere((c) => c.$1 == 'chat_block');
    expect(block.$2['blocked'], true);
    expect(find.byKey(const Key('msg-m1')), findsNothing);
  });

  testWidgets('a sticker is sent as a sticker', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('stickerButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sticker❤️')));
    await tester.pumpAndSettle();
    final post = calls.firstWhere((c) => c.$1 == 'chat_post');
    expect(post.$2['kind'], 'sticker');
    expect(post.$2['body'], '❤️');
  });

  testWidgets('My picture shows the saved picture and can remove it', (
    tester,
  ) async {
    final seen = <String>[];
    final a = SyncApi((fn, args) async {
      seen.add(fn);
      return switch (fn) {
        'avatar_get' => {'photo': null},
        _ => {'ok': true},
      };
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyPictureTile(token: 'tok', api: a),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('My picture'), findsOneWidget);
    expect(seen, ['avatar_get']);
    await tester.tap(find.byTooltip('Change my picture'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove my picture'));
    await tester.pumpAndSettle();
    expect(seen, ['avatar_get', 'avatar_set', 'avatar_get']);
  });
}
