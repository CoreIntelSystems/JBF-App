import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/data/sync/sync_api.dart';
import 'package:jbf_app/features/pay_requests/pay_api.dart';
import 'package:jbf_app/features/pay_requests/pay_requests_screen.dart';

Map<String, Object?> _request({Map<String, Object?>? mine}) => {
  'id': 'r1',
  'office': 'treasury',
  'title': 'Silver Collection',
  'type': 'Silver Collection',
  'amount': 5000,
  'pay_to': 'MoMo 024 000 0000',
  'closed': false,
  'by': 'Miz Akosua',
  'asked': 3,
  'pending': 1,
  'confirmed': 0,
  'collected': 0,
  'mine': mine,
};

void main() {
  late List<(String, Map<String, Object?>)> calls;

  PayApi api(Object? Function(String fn) answer) {
    calls = [];
    return PayApi(
      SyncApi((fn, args) async {
        calls.add((fn, args));
        return answer(fn);
      }),
      'tok',
    );
  }

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  testWidgets('a member reports a Mobile Money payment', (tester) async {
    final a = api((fn) => {'id': 'c1'});
    await pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => PaidDialog(api: a, request: _request()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('50.00'), findsOneWidget);

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(find.textContaining('transaction ID'), findsOneWidget);
    expect(calls, isEmpty);

    await tester.enterText(
      find.widgetWithText(TextField, 'Transaction ID'),
      '1234567',
    );
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(calls.single.$1, 'pay_claim_submit');
    expect(calls.single.$2['amount'], 5000);
    expect(calls.single.$2['method'], 'momo');
    expect(calls.single.$2['reference'], '1234567');
    expect(find.byType(PaidDialog), findsNothing);
  });

  testWidgets('a treasurer confirms a reported payment', (tester) async {
    final a = api(
      (fn) => switch (fn) {
        'pay_claims_for' => [
          {
            'id': 'c1',
            'member_name': 'Ama Mensah',
            'member_no': 'JBF-000001',
            'amount': 5000,
            'method': 'momo',
            'reference': '1234567',
            'status': 'pending',
          },
        ],
        'pay_claim_decide' => {'ok': true, 'receipt_no': 'ONL-2026-000001'},
        _ => null,
      },
    );
    await pump(
      tester,
      PayRequestScreen(api: a, request: _request(), canConfirm: true),
    );
    expect(find.text('Ama Mensah'), findsOneWidget);
    expect(find.text('Transaction: 1234567'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm').last);
    await tester.pumpAndSettle();
    final decide = calls.firstWhere((c) => c.$1 == 'pay_claim_decide');
    expect(decide.$2['claim'], 'c1');
    expect(decide.$2['confirm'], true);
    expect(find.text('Confirmed. Receipt ONL-2026-000001.'), findsOneWidget);
  });

  testWidgets('officers who cannot confirm see no Confirm or Reject', (
    tester,
  ) async {
    final a = api(
      (fn) => switch (fn) {
        'pay_claims_for' => [
          {
            'id': 'c1',
            'member_name': 'Ama Mensah',
            'amount': 5000,
            'method': 'cash',
            'status': 'pending',
          },
        ],
        _ => {'ok': true},
      },
    );
    await pump(
      tester,
      PayRequestScreen(api: a, request: _request(), canConfirm: false),
    );
    expect(find.text('Reject'), findsNothing);
  });

  testWidgets('asking members to pay sends the type, month and zones', (
    tester,
  ) async {
    final a = api((fn) => {'id': 'r1'});
    await pump(
      tester,
      NewPayRequestScreen(
        api: a,
        offices: const ['treasury', 'welfare'],
        data: const {
          'types': [
            {
              'id': 'dues',
              'name': 'Monthly dues',
              'frequency': 'monthly',
              'amount': 2000,
            },
          ],
          'zones': [
            {'id': 'z1', 'name': 'Zone 1'},
            {'id': 'z2', 'name': 'Zone 2'},
          ],
        },
      ),
    );
    await tester.tap(find.text('Payment for'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monthly dues').last);
    await tester.pumpAndSettle();
    expect(find.text('Month'), findsOneWidget);
    await tester.tap(find.text('Zone 2'));
    await tester.pump();
    await tester.tap(find.text('Send to members'));
    await tester.pumpAndSettle();
    final c = calls.single;
    expect(c.$1, 'pay_request_create');
    expect(c.$2['office'], 'treasury');
    expect(c.$2['type_id'], 'dues');
    expect(c.$2['title'], 'Monthly dues');
    expect(c.$2['amount'], 2000);
    expect(c.$2['period'], matches(RegExp(r'^\d{4}-\d{2}$')));
    expect(c.$2['zones'], ['z2']);
  });

  testWidgets('a member pays their own monthly dues without a request', (
    tester,
  ) async {
    final a = api(
      (fn) => fn == 'pay_self_options'
          ? {
              'pay_to': 'MoMo 024 000 0000',
              'types': [
                {'id': 'cause', 'name': 'Charity project', 'frequency': 'once'},
                {
                  'id': 'dues',
                  'name': 'Monthly dues',
                  'frequency': 'monthly',
                  'amount': 2000,
                },
              ],
            }
          : {'id': 'r9', 'title': 'Monthly dues (paid by members)'},
    );
    Map<String, dynamic>? got;
    await pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => got = await showDialog<Map<String, dynamic>>(
              context: context,
              builder: (_) => SelfPayDialog(api: a),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // Monthly dues is chosen first, with the month and where to pay.
    expect(find.text('Pay to: MoMo 024 000 0000'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    await tester.tap(find.text('I have paid'));
    await tester.pumpAndSettle();
    final c = calls.last;
    expect(c.$1, 'pay_self_request');
    expect(c.$2['type_id'], 'dues');
    expect(c.$2['period'], matches(RegExp(r'^\d{4}-\d{2}$')));
    expect(got?['id'], 'r9');
  });
}
