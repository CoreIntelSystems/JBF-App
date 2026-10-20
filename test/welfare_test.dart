import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/data/database.dart';
import 'package:jbf_app/data/repositories/actor.dart';
import 'package:jbf_app/data/repositories/payment_repository.dart';
import 'package:jbf_app/data/repositories/welfare_repository.dart';
import 'package:jbf_app/domain/permissions.dart';

import 'helpers.dart';

void main() {
  late TestEnv env;
  late Member member;
  late List<WelfareCaseType> types;

  const treasurer = WelfareActor(
    Actor(userId: 't1', username: 'treasurer', deviceId: 'd1'),
    name: 'Yaw Treasurer',
    roleName: 'Treasurer',
  );
  const chairman = WelfareActor(
    Actor(userId: 'c1', username: 'chair', deviceId: 'd1'),
    name: 'Esi Chair',
    roleName: 'Welfare Chairman',
  );

  setUp(() async {
    env = TestEnv(clock: () => DateTime(2026, 10, 14, 12));
    final zone1 = (await env.zoneIdsByCode())[1]!;
    member = await env.members.create(
      env.draft('Kofi', [zone1]),
      TestEnv.actor,
    );
    types = await env.welfare.activeCaseTypes();
    await env.welfare.joinWelfare(member.id, treasurer);
  });
  tearDown(() => env.db.close());

  WelfareCaseType type(String name) => types.firstWhere((t) => t.name == name);

  test('seeds case types with no amounts and gives the Treasurer pay', () {
    expect(types, hasLength(7));
    expect(types.every((t) => t.benefitAmount == null), isTrue);
    final treasurerRole = defaultRoles.firstWhere((r) => r.key == 'treasurer');
    expect(treasurerRole.permissions, contains(Perm.welfarePay));
  });

  test('benefit amount applies only after approval', () async {
    final hosp = type('Hospitalisation');
    await env.welfare.proposeBenefit(hosp.id, 50000, treasurer);
    var t = (await env.welfare.activeCaseTypes()).firstWhere(
      (x) => x.id == hosp.id,
    );
    expect(t.benefitAmount, isNull);
    expect(t.proposedAmount, 50000);
    expect((await env.welfare.summary()).pendingBenefitChanges, 1);

    await env.welfare.decideBenefit(hosp.id, chairman, approve: true);
    t = (await env.welfare.activeCaseTypes()).firstWhere(
      (x) => x.id == hosp.id,
    );
    expect(t.benefitAmount, 50000);
    expect(t.proposedAmount, isNull);
    expect(t.benefitApprovedByName, 'Esi Chair');

    // A rejected change leaves the approved amount alone.
    await env.welfare.proposeBenefit(hosp.id, 90000, treasurer);
    await env.welfare.decideBenefit(hosp.id, chairman, approve: false);
    t = (await env.welfare.activeCaseTypes()).firstWhere(
      (x) => x.id == hosp.id,
    );
    expect(t.benefitAmount, 50000);
    expect(t.proposedAmount, isNull);
  });

  test('case uses the fixed amount, then is approved and paid', () async {
    final hosp = type('Hospitalisation');
    await env.welfare.proposeBenefit(hosp.id, 50000, treasurer);
    await env.welfare.decideBenefit(hosp.id, chairman, approve: true);

    final c = await env.welfare.createCase(
      WelfareCaseDraft(
        memberId: member.id,
        caseTypeId: hosp.id,
        occurredOn: DateTime(2026, 10, 10),
        requestedAmount: 999999, // ignored: the type has a fixed amount
      ),
      treasurer,
    );
    expect(c.caseNo, 'WEL-2026-0001');
    expect(c.amount, 50000);
    expect(c.amountIsFixed, isTrue);
    expect(c.status, WelfareStatus.pending);

    await expectLater(
      env.welfare.markPaid(
        c.id,
        treasurer,
        method: PaymentMethod.momo,
        paidOn: DateTime(2026, 10, 14),
      ),
      throwsA(isA<WelfareException>()),
    );

    await env.welfare.decideCase(c.id, chairman, approve: true);
    await env.welfare.markPaid(
      c.id,
      treasurer,
      method: PaymentMethod.momo,
      paidOn: DateTime(2026, 10, 14),
      reference: 'MP123',
    );
    final view = (await env.welfare.watchCase(c.id).first)!;
    expect(view.welfareCase.status, WelfareStatus.paid);
    expect(view.welfareCase.decidedByRole, 'Welfare Chairman');
    expect(view.member.fullName, 'Kofi');

    final s = await env.welfare.summary();
    expect(s.fundPaidOut, 50000);
    expect(s.paidThisMonth, 50000);
    expect(s.pendingCases, 0);
  });

  test('case without a fixed amount needs a requested amount', () async {
    final other = type('Other support');
    await expectLater(
      env.welfare.createCase(
        WelfareCaseDraft(
          memberId: member.id,
          caseTypeId: other.id,
          occurredOn: DateTime(2026, 10, 1),
        ),
        treasurer,
      ),
      throwsA(isA<WelfareException>()),
    );
    final c = await env.welfare.createCase(
      WelfareCaseDraft(
        memberId: member.id,
        caseTypeId: other.id,
        occurredOn: DateTime(2026, 10, 1),
        requestedAmount: 20000,
      ),
      treasurer,
    );
    expect(c.amountIsFixed, isFalse);
  });

  test('rejection needs a reason; decided cases are locked', () async {
    final c = await env.welfare.createCase(
      WelfareCaseDraft(
        memberId: member.id,
        caseTypeId: type('Wedding').id,
        occurredOn: DateTime(2026, 9, 1),
        requestedAmount: 30000,
      ),
      treasurer,
    );
    await expectLater(
      env.welfare.decideCase(c.id, chairman, approve: false),
      throwsA(isA<WelfareException>()),
    );
    await env.welfare.decideCase(
      c.id,
      chairman,
      approve: false,
      note: 'Not a member at the time',
    );
    await expectLater(
      env.welfare.decideCase(c.id, chairman, approve: true),
      throwsA(isA<WelfareException>()),
    );
    // The database refuses changes that skip the workflow.
    await expectLater(
      env.db.customStatement(
        "UPDATE welfare_cases SET status = 'paid' WHERE id = '${c.id}'",
      ),
      throwsA(anything),
    );
    await expectLater(
      env.db.customStatement(
        "UPDATE welfare_cases SET amount = 1 WHERE id = '${c.id}'",
      ),
      throwsA(anything),
    );
    await expectLater(
      env.db.customStatement("DELETE FROM welfare_cases WHERE id = '${c.id}'"),
      throwsA(anything),
    );
  });

  test('welfare fund counts welfare-category payments only', () async {
    final pt = await env.payments.activeTypes();
    final silver = pt.firstWhere((t) => t.name == 'Silver collection');
    final charity = pt.firstWhere((t) => t.name == 'Charity project');
    for (final t in [silver, charity]) {
      await env.payments.record(
        PaymentDraft(
          memberId: member.id,
          contributionTypeId: t.id,
          amount: 10000,
          method: PaymentMethod.cash,
          paidOn: DateTime(2026, 10, 14),
        ),
        TestEnv.actor,
        collectorName: 'T',
      );
    }
    final s = await env.welfare.summary();
    expect(s.fundCollected, 10000);
    expect(s.fundBalance, 10000);
  });

  test('an officer cannot decide their own case or proposal, the Founder can',
      () async {
    final hosp = type('Hospitalisation');
    await env.welfare.proposeBenefit(hosp.id, 50000, treasurer);
    await expectLater(
      env.welfare.decideBenefit(hosp.id, treasurer, approve: true),
      throwsA(isA<WelfareException>()),
    );
    const founder = WelfareActor(
      Actor(userId: 'f1', username: 'founder', deviceId: 'd1'),
      name: 'Founder',
      roleName: 'Founder / President',
      mayApproveOwn: true,
    );
    await env.welfare.proposeBenefit(hosp.id, 60000, founder);
    await env.welfare.decideBenefit(hosp.id, founder, approve: true);

    final c = await env.welfare.createCase(
      WelfareCaseDraft(
        memberId: member.id,
        caseTypeId: hosp.id,
        occurredOn: DateTime(2026, 10, 10),
      ),
      treasurer,
    );
    await expectLater(
      env.welfare.decideCase(c.id, treasurer, approve: true),
      throwsA(isA<WelfareException>()),
    );
    await env.welfare.decideCase(c.id, chairman, approve: true);

    final own = await env.welfare.createCase(
      WelfareCaseDraft(
        memberId: member.id,
        caseTypeId: hosp.id,
        occurredOn: DateTime(2026, 10, 11),
      ),
      founder,
    );
    await env.welfare.decideCase(own.id, founder, approve: true);
    final logs = await env.db.select(env.db.auditLogs).get();
    expect(
      logs.any((l) => (l.newValue ?? '').contains('decidedOwnCase')),
      isTrue,
    );
  });
}
