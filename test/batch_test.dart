import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/data/collection_batch.dart';
import 'package:jbf_app/data/database.dart';
import 'package:jbf_app/data/repositories/actor.dart';
import 'package:jbf_app/data/repositories/payment_repository.dart';
import 'package:jbf_app/domain/member_qr.dart';

import 'helpers.dart';

void main() {
  test('field phone batch moves payments to the main phone once', () async {
    // Main phone with a member; the field phone starts as a copy of it.
    final main = TestEnv();
    final field = TestEnv();
    final zone = (await main.zoneIdsByCode())[1]!;
    final m = await main.members.create(
      main.draft('Ama', [zone]),
      TestEnv.actor,
    );
    // Same member id on the field phone, as after restoring a backup.
    await field.db.into(field.db.members).insert(m.toCompanion(false));
    final types = await field.payments.activeTypes();
    final silver = types.firstWhere((t) => t.name == 'Silver collection');
    await field.db
        .update(field.db.orgSettings)
        .write(const OrgSettingsCompanion(receiptPrefix: Value('Z1')));
    // Main and field seeded their own type ids; align for the test.
    final mainSilver = (await main.payments.activeTypes()).firstWhere(
      (t) => t.name == 'Silver collection',
    );

    const fieldActor = Actor(userId: 'f', username: 'zt', deviceId: 'field-1');
    Future<Payment> pay(int amount) => field.payments.record(
      PaymentDraft(
        memberId: m.id,
        contributionTypeId: silver.id,
        amount: amount,
        method: PaymentMethod.cash,
        paidOn: DateTime(2026, 10, 14),
      ),
      fieldActor,
      collectorName: 'Zone treasurer',
    );
    final p1 = await pay(1000);
    await pay(2000);
    // A payment by someone else on the field phone is not sent.
    await field.payments.record(
      PaymentDraft(
        memberId: m.id,
        contributionTypeId: silver.id,
        amount: 5,
        method: PaymentMethod.cash,
        paidOn: DateTime(2026, 10, 14),
      ),
      TestEnv.actor,
      collectorName: 'Other',
    );
    expect(p1.receiptNo, startsWith('Z1-2026-'));

    final out = CollectionBatches(field.db, field.audit);
    final bytes = await out.export(
      deviceId: 'field-1',
      deviceName: 'Zone 1 phone',
      password: 'zone1pass',
    );
    final into = CollectionBatches(main.db, main.audit);
    await expectLater(into.read(bytes, 'nope'), throwsA(isA<BatchException>()));
    final (summary, rows) = await into.read(bytes, 'zone1pass');
    expect(summary.count, 2);
    expect(summary.total, 3000);
    expect(summary.fromDevice, 'Zone 1 phone');

    // The field phone used its own type ids, unknown to main.
    var result = await into.import(rows, TestEnv.actor, fromDevice: 'Z1');
    expect(result.added, 0);
    expect(result.skipped, hasLength(2));

    // With matching types (as after a backup restore) they import once.
    final fixed = [
      for (final r in rows) r.copyWith(contributionTypeId: mainSilver.id),
    ];
    result = await into.import(fixed, TestEnv.actor, fromDevice: 'Z1');
    expect(result.added, 2);
    result = await into.import(fixed, TestEnv.actor, fromDevice: 'Z1');
    expect(result.added, 0);
    expect(result.alreadyHad, 2);

    // A later void on the field phone carries over.
    await field.payments.voidPayment(p1.id, 'Wrong member', fieldActor);
    final again = await out.export(
      deviceId: 'field-1',
      deviceName: 'Zone 1 phone',
      password: 'zone1pass',
    );
    final (_, rows2) = await into.read(again, 'zone1pass');
    result = await into.import(
      [for (final r in rows2) r.copyWith(contributionTypeId: mainSilver.id)],
      TestEnv.actor,
      fromDevice: 'Z1',
    );
    expect(result.voidsApplied, 1);
    final stored = await (main.db.select(
      main.db.payments,
    )..where((t) => t.id.equals(p1.id))).getSingle();
    expect(stored.status, PaymentStatus.voided);

    await main.db.close();
    await field.db.close();
  });

  test('member QR codes', () {
    expect(MemberQr.decode(MemberQr.encode('JBF-000012')), 'JBF-000012');
    expect(MemberQr.decode('JBF-000012'), 'JBF-000012');
    expect(MemberQr.decode('https://example.com'), isNull);
  });
}
