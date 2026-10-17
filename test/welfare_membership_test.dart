import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/data/database.dart';
import 'package:jbf_app/data/repositories/actor.dart';
import 'package:jbf_app/data/repositories/payment_repository.dart';
import 'package:jbf_app/data/repositories/welfare_repository.dart';

import 'helpers.dart';

void main() {
  late TestEnv env;
  late Member kofi;
  var now = DateTime(2026, 10, 14, 12);

  const officer = WelfareActor(
    Actor(userId: 'w1', username: 'welfare', deviceId: 'd1'),
    name: 'Esi Welfare',
    roleName: 'Welfare Chairman',
  );

  setUp(() async {
    now = DateTime(2026, 10, 14, 12);
    env = TestEnv(clock: () => now);
    final zone1 = (await env.zoneIdsByCode())[1]!;
    kofi = await env.members.create(env.draft('Kofi', [zone1]), TestEnv.actor);
  });
  tearDown(() => env.db.close());

  Future<ContributionType> type(String name) async =>
      (await env.payments.activeTypes()).firstWhere((t) => t.name == name);

  Future<Member> reload() => (env.db.select(
    env.db.members,
  )..where((m) => m.id.equals(kofi.id))).getSingle();

  Future<Payment> pay(
    ContributionType t,
    int amount, {
    String? period,
    DateTime? on,
  }) => env.payments.record(
    PaymentDraft(
      memberId: kofi.id,
      contributionTypeId: t.id,
      amount: amount,
      method: PaymentMethod.cash,
      paidOn: on ?? now,
      period: period,
    ),
    TestEnv.actor,
    collectorName: 'Treasurer',
  );

  Future<ContributionType> setDues(int amount) async {
    final dues = await type('Monthly welfare dues');
    await env.payments.saveType(
      dues.id,
      ContributionTypesCompanion(amount: Value(amount)),
      TestEnv.actor,
    );
    return type('Monthly welfare dues');
  }

  test('members start outside welfare', () async {
    expect(kofi.welfareMembership, WelfareMembership.none);
    expect(await env.welfare.benefitBlock(kofi.id), contains('not a welfare'));
  });

  test('welfare contribution is seeded with no fixed amount', () async {
    final t = await type('Welfare contribution');
    expect(t.amount, isNull);
    expect(t.welfareRule, WelfareRule.contribution);
    expect(t.frequency, ContributionFrequency.open);
  });

  test('the minimum is enforced', () async {
    final t = await type('Welfare contribution');
    await env.payments.saveType(
      t.id,
      const ContributionTypesCompanion(minimumAmount: Value(2000)),
      TestEnv.actor,
    );
    await expectLater(pay(t, 1000), throwsA(isA<PaymentException>()));
    await pay(t, 2000);
  });

  test(
    'paying a welfare contribution makes the member a welfare member',
    () async {
      final t = await type('Welfare contribution');
      await pay(t, 5000);
      final m = await reload();
      expect(m.welfareMembership, WelfareMembership.member);
      expect(m.welfareSince, now);
      expect(await env.welfare.benefitBlock(kofi.id), isNull);
    },
  );

  test('a donation does not join welfare', () async {
    await pay(await type('Voluntary donation'), 1000);
    expect((await reload()).welfareMembership, WelfareMembership.none);
  });

  test('welfare dues are owed only by welfare members', () async {
    final dues = await setDues(2000);
    expect((await env.payments.duesFor(kofi.id, dues.id))!.outstanding, 0);
    await env.welfare.joinWelfare(kofi.id, officer);
    now = DateTime(2026, 12, 20);
    // October, November, December since joining.
    expect((await env.payments.duesFor(kofi.id, dues.id))!.outstanding, 6000);
    expect(await env.payments.defaulters(), hasLength(1));
  });

  test('paying dues joins welfare from the month paid for', () async {
    final dues = await setDues(2000);
    await pay(dues, 2000, period: '2026-09');
    final m = await reload();
    expect(m.welfareMembership, WelfareMembership.member);
    expect(m.welfareSince, DateTime(2026, 9));
  });

  test('three months of dues missed in a row blocks benefits', () async {
    await setDues(2000);
    await env.welfare.joinWelfare(kofi.id, officer);
    now = DateTime(2026, 12, 20);
    // Completed months since joining: October and November only.
    expect(await env.welfare.benefitBlock(kofi.id), isNull);
    now = DateTime(2027, 1, 5);
    expect(await env.welfare.benefitBlock(kofi.id), contains('missed 3'));
  });

  test('leaving welfare stops dues, and a disqualified member rejoins only by '
      'reinstatement', () async {
    final dues = await setDues(2000);
    await env.welfare.joinWelfare(kofi.id, officer);
    await env.welfare.leaveWelfare(kofi.id, officer);
    now = DateTime(2027, 3, 1);
    expect((await env.payments.duesFor(kofi.id, dues.id))!.outstanding, 2000);

    await (env.db.update(
      env.db.members,
    )..where((m) => m.id.equals(kofi.id))).write(
      const MembersCompanion(
        welfareMembership: Value(WelfareMembership.disqualified),
      ),
    );
    await expectLater(
      env.welfare.joinWelfare(kofi.id, officer),
      throwsA(isA<WelfareException>()),
    );
    await pay(dues, 2000, period: '2027-03');
    expect((await reload()).welfareMembership, WelfareMembership.disqualified);
    await env.welfare.reinstateWelfare(kofi.id, officer);
    expect((await reload()).welfareMembership, WelfareMembership.member);
  });

  test('cases are refused for members outside welfare', () async {
    final caseType = (await env.welfare.activeCaseTypes()).first;
    final draft = WelfareCaseDraft(
      memberId: kofi.id,
      caseTypeId: caseType.id,
      occurredOn: DateTime(2026, 10, 10),
      requestedAmount: 10000,
    );
    await expectLater(
      env.welfare.createCase(draft, officer),
      throwsA(isA<WelfareException>()),
    );
    await env.welfare.joinWelfare(kofi.id, officer);
    await env.welfare.createCase(draft, officer);
  });
}
