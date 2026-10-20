import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/data/database.dart';
import 'package:jbf_app/data/repositories/actor.dart';
import 'package:jbf_app/data/repositories/drive_repository.dart';
import 'package:jbf_app/data/repositories/welfare_repository.dart';

import 'helpers.dart';

void main() {
  late TestEnv env;
  late WelfareCase welfareCase;

  const secretary = WelfareActor(
    Actor(userId: 's1', username: 'sec', deviceId: 'd1'),
    name: 'Ama Secretary',
    roleName: 'Welfare Secretary',
  );
  const chairman = WelfareActor(
    Actor(userId: 'c1', username: 'chair', deviceId: 'd1'),
    name: 'Esi Chair',
    roleName: 'Welfare Chairman',
  );

  setUp(() async {
    env = TestEnv(clock: () => DateTime(2026, 10, 14, 12));
    final zone1 = (await env.zoneIdsByCode())[1]!;
    final member = await env.members.create(
      env.draft('Kofi', [zone1]),
      TestEnv.actor,
    );
    await env.welfare.joinWelfare(member.id, secretary);
    final types = await env.welfare.activeCaseTypes();
    welfareCase = await env.welfare.createCase(
      WelfareCaseDraft(
        memberId: member.id,
        caseTypeId: types.firstWhere((t) => t.name == 'Other support').id,
        occurredOn: DateTime(2026, 10, 10),
        requestedAmount: 50000,
        beneficiary: 'Mother',
      ),
      secretary,
    );
  });
  tearDown(() => env.db.close());

  test('pledges become gifts, and only received money is counted', () async {
    await env.drives.openDrive(
      welfareCase.id,
      secretary,
      funeralVenue: 'Kumasi',
      familyContact: 'Uncle Kwame',
    );
    await env.drives.addGift(
      welfareCase.id,
      secretary,
      giverName: 'Adwoa',
      amount: 2000,
    );
    final cash = await env.drives.addGift(
      welfareCase.id,
      secretary,
      giverName: 'Yaw',
      amount: 5000,
      method: PaymentMethod.cash,
      anonymous: true,
    );
    var t = driveTotals(await env.drives.gifts(welfareCase.id));
    expect(t.received, 5000);
    expect(t.pledged, 2000);
    expect(t.givers, 2);

    final pledge = (await env.drives.gifts(
      welfareCase.id,
    )).firstWhere((g) => g.giverName == 'Adwoa');
    await env.drives.receiveGift(
      pledge.id,
      secretary,
      method: PaymentMethod.momo,
      reference: 'MP1',
    );
    await env.drives.voidGift(cash.id, secretary, 'Entered twice');
    t = driveTotals(await env.drives.gifts(welfareCase.id));
    expect(t.received, 2000);
    expect(t.pledged, 0);
    expect(t.givers, 1);
  });

  test(
    'closing locks gifts; a different officer approves the hand-over',
    () async {
      await env.drives.openDrive(welfareCase.id, secretary);
      await env.drives.addGift(
        welfareCase.id,
        secretary,
        giverName: 'Yaw',
        amount: 5000,
        method: PaymentMethod.cash,
      );
      await expectLater(
        env.drives.approveHandover(
          welfareCase.id,
          chairman,
          method: PaymentMethod.cash,
          handedOn: DateTime(2026, 10, 15),
        ),
        throwsA(isA<WelfareException>()),
      );
      await env.drives.closeDrive(welfareCase.id, secretary);
      await expectLater(
        env.drives.addGift(
          welfareCase.id,
          secretary,
          giverName: 'Late',
          amount: 100,
        ),
        throwsA(isA<WelfareException>()),
      );
      await expectLater(
        env.drives.approveHandover(
          welfareCase.id,
          secretary,
          method: PaymentMethod.cash,
          handedOn: DateTime(2026, 10, 15),
        ),
        throwsA(isA<WelfareException>()),
      );
      await env.drives.approveHandover(
        welfareCase.id,
        chairman,
        method: PaymentMethod.cash,
        handedOn: DateTime(2026, 10, 15),
      );
      final c =
          (await env.welfare.watchCase(welfareCase.id).first)!.welfareCase;
      expect(c.driveStatus, DriveStatus.handedOver);
      expect(c.handoverAmount, 5000);
      expect(c.handoverByName, 'Esi Chair');
    },
  );

  test('the shared summary hides anonymous givers and voided gifts', () async {
    await env.drives.openDrive(
      welfareCase.id,
      secretary,
      funeralVenue: 'Kumasi',
    );
    await env.drives.addGift(
      welfareCase.id,
      secretary,
      giverName: 'Secret Giver',
      amount: 5000,
      method: PaymentMethod.cash,
      anonymous: true,
    );
    final wrong = await env.drives.addGift(
      welfareCase.id,
      secretary,
      giverName: 'Mistake',
      amount: 900,
    );
    await env.drives.voidGift(wrong.id, secretary, 'Wrong person');
    final c = (await env.welfare.watchCase(welfareCase.id).first)!;
    final text = driveSummaryText(
      welfareCase: c.welfareCase,
      memberName: c.member.fullName,
      gifts: await env.drives.gifts(welfareCase.id),
    );
    expect(text, contains('A well-wisher'));
    expect(text, contains('Venue: Kumasi'));
    expect(text, isNot(contains('Secret Giver')));
    expect(text, isNot(contains('Mistake')));
  });

  test('gifts cannot be deleted', () async {
    await env.drives.openDrive(welfareCase.id, secretary);
    final g = await env.drives.addGift(
      welfareCase.id,
      secretary,
      giverName: 'Yaw',
      amount: 100,
    );
    await expectLater(
      env.db.customStatement('DELETE FROM welfare_drive_gifts WHERE id = ?', [
        g.id,
      ]),
      throwsA(anything),
    );
  });
}
