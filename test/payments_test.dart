import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/core/money.dart';
import 'package:jbf_app/data/database.dart';
import 'package:jbf_app/data/repositories/payment_repository.dart';
import 'package:jbf_app/features/payments/receipt_pdf.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestEnv env;
  late String zone1;
  late ContributionType dues;

  setUp(() async {
    env = TestEnv(clock: () => DateTime(2026, 10, 14, 12));
    zone1 = (await env.zoneIdsByCode())[1]!;
    final types = await env.payments.activeTypes();
    dues = types.firstWhere((t) => t.name == 'Monthly welfare dues');
    await env.payments.saveType(
      dues.id,
      const ContributionTypesCompanion(amount: Value(2000)),
      TestEnv.actor,
    );
  });
  tearDown(() => env.db.close());

  Future<Member> member(DateTime joined) async {
    final d = env.draft('Ama', [zone1])..dateJoined = joined;
    return env.members.create(d, TestEnv.actor);
  }

  PaymentDraft draft(Member m, int amount, String period) => PaymentDraft(
    memberId: m.id,
    contributionTypeId: dues.id,
    amount: amount,
    method: PaymentMethod.cash,
    paidOn: DateTime(2026, 10, 14),
    period: period,
  );

  test('money parsing and formatting', () {
    expect(parseMoney('20'), 2000);
    expect(parseMoney('1,250.5'), 125050);
    expect(parseMoney('0.05'), 5);
    expect(parseMoney('-3'), isNull);
    expect(parseMoney('abc'), isNull);
    expect(formatMoney(125050), 'GHS 1,250.50');
  });

  test('seeds the six categories with dues amount unset', () async {
    final types = await env.payments.activeTypes();
    expect(
      types.map((t) => t.category).toSet(),
      ContributionCategory.values.toSet(),
    );
    final silver = types.firstWhere((t) => t.name == 'Silver collection');
    expect(silver.frequency, ContributionFrequency.perEvent);
  });

  test('receipt numbers are sequential and per year', () async {
    final m = await member(DateTime(2026, 10, 1));
    final a = await env.payments.record(
      draft(m, 2000, '2026-10'),
      TestEnv.actor,
      collectorName: 'Tester',
    );
    final b = await env.payments.record(
      draft(m, 2000, '2026-11'),
      TestEnv.actor,
      collectorName: 'Tester',
    );
    expect(a.receiptNo, 'RCP-2026-000001');
    expect(b.receiptNo, 'RCP-2026-000002');
  });

  test('ledger shows arrears and next unpaid month', () async {
    final m = await member(DateTime(2026, 8, 5));
    await env.payments.record(
      draft(m, 2000, '2026-08'),
      TestEnv.actor,
      collectorName: 'Tester',
    );
    final ledger = await env.payments.ledger(m.id);
    final s = ledger.dues.single.summary;
    expect(s.expected, 6000); // Aug, Sep, Oct
    expect(s.outstanding, 4000);
    expect(s.nextUnpaidPeriod, '2026-09');
    expect(ledger.totalPaid, 2000);
    expect(ledger.lastPaymentDate, DateTime(2026, 10, 14));

    final defaulters = await env.payments.defaulters();
    expect(defaulters.single.$2, 4000);
  });

  test(
    'voided payments stop counting and cannot be deleted or edited',
    () async {
      final m = await member(DateTime(2026, 10, 1));
      final p = await env.payments.record(
        draft(m, 2000, '2026-10'),
        TestEnv.actor,
        collectorName: 'Tester',
      );
      expect((await env.payments.ledger(m.id)).outstanding, 0);

      await env.payments.voidPayment(p.id, 'Wrong member', TestEnv.actor);
      final ledger = await env.payments.ledger(m.id);
      expect(ledger.outstanding, 2000);
      expect(ledger.payments.single.payment.status, PaymentStatus.voided);

      await expectLater(
        env.db.customStatement('DELETE FROM payments'),
        throwsA(anything),
      );
      await expectLater(
        env.db.customStatement('UPDATE payments SET amount = 1'),
        throwsA(anything),
      );
      final logs = await env.audit.watchRecent().first;
      expect(
        logs.map((l) => l.action),
        containsAll(['payment.record', 'payment.void']),
      );
    },
  );

  test('dues need a member and a month', () async {
    await expectLater(
      env.payments.record(
        PaymentDraft(
          memberId: null,
          contributionTypeId: dues.id,
          amount: 2000,
          method: PaymentMethod.cash,
          paidOn: DateTime(2026, 10, 14),
          period: '2026-10',
        ),
        TestEnv.actor,
        collectorName: 'T',
      ),
      throwsA(isA<PaymentException>()),
    );
  });

  test('builds a receipt PDF, including a voided one', () async {
    final m = await member(DateTime(2026, 1, 1));
    final p = await env.payments.record(
      draft(m, 2000, '2026-01'),
      TestEnv.actor,
      collectorName: 'Treasurer',
    );
    final org = await env.payments.org();
    var view = (await env.payments.watchPayment(p.id).first)!;
    final bytes = await buildReceiptPdf(view, org);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    await env.payments.voidPayment(p.id, 'Entered twice', TestEnv.actor);
    view = (await env.payments.watchPayment(p.id).first)!;
    expect((await buildReceiptPdf(view, org)).length, greaterThan(1000));
  });
}
