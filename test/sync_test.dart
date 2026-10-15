import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/data/database.dart';
import 'package:jbf_app/data/repositories/auth_repository.dart';
import 'package:jbf_app/data/repositories/member_repository.dart';
import 'package:jbf_app/data/repositories/payment_repository.dart';
import 'package:jbf_app/data/repositories/welfare_repository.dart';
import 'package:jbf_app/data/sync/sync_api.dart';
import 'package:jbf_app/data/sync/sync_service.dart';
import 'package:jbf_app/domain/permissions.dart';

import 'fake_cloud.dart';
import 'helpers.dart';

class Phone {
  Phone(this.cloud) : env = TestEnv() {
    sync = SyncService(env.db, cloud.api, MemorySyncPrefs());
  }
  final FakeCloud cloud;
  final TestEnv env;
  late final SyncService sync;
  AppDatabase get db => env.db;

  Future<void> close() async {
    await sync.close();
    await db.close();
  }
}

void main() {
  late FakeCloud cloud;
  late Phone main;
  late Phone field;

  const actor = TestEnv.actor;

  Future<String> duesTypeId(Phone p) async =>
      (await (p.db.select(p.db.contributionTypes)..where(
                (t) => t.frequency.equalsValue(ContributionFrequency.monthly),
              ))
              .get())
          .first
          .id;

  setUp(() async {
    cloud = FakeCloud();
    main = Phone(cloud);
    await main.env.auth.createInitialAdmin(
      displayName: 'Ama',
      username: 'ama',
      password: 'secret1',
      deviceId: 'main',
    );
    final zones = await main.env.zoneIdsByCode();
    await main.env.members.create(
      main.env.draft('Kofi Mensah', [zones[1]!]),
      actor,
    );
    await main.sync.load();
    expect(
      await main.sync.join(
        code: cloud.newCode(admin: true),
        deviceName: 'Main',
      ),
      JoinOutcome.founded,
    );
    expect(main.sync.state.pending, 0);
    expect(main.sync.state.error, isNull);

    field = Phone(cloud);
    await field.sync.load();
    final code = await main.sync.createCode();
    expect(
      await field.sync.join(code: code, deviceName: 'Zone 3', series: 'z3'),
      JoinOutcome.received,
    );
  });

  tearDown(() async {
    await main.close();
    await field.close();
  });

  test('a new phone receives the organisation and can sign in', () async {
    expect(field.sync.state.error, isNull);
    expect(field.sync.state.issues, 0);
    final members = await field.db.select(field.db.members).get();
    expect(members.single.fullName, 'Kofi Mensah');
    expect(await field.db.select(field.db.zones).get(), hasLength(8));
    final mainRoles = await main.db.select(main.db.roles).get();
    final fieldRoles = await field.db.select(field.db.roles).get();
    expect(
      fieldRoles.map((r) => r.id).toSet(),
      mainRoles.map((r) => r.id).toSet(),
    );
    expect(
      (await field.db.select(field.db.rolePermissions).get()).length,
      (await main.db.select(main.db.rolePermissions).get()).length,
    );
    final user = await field.env.auth.login(
      'ama',
      'secret1',
      method: LoginMethod.password,
      deviceId: 'field',
    );
    expect(user.username, 'ama');
    final org = await field.db.select(field.db.orgSettings).getSingle();
    expect(org.deviceSeries, 'Z3');
  });

  test('numbers made on the field phone carry its series', () async {
    final zones = await field.env.zoneIdsByCode();
    final m = await field.env.members.create(
      field.env.draft('Akua Boateng', [zones[3]!]),
      actor,
    );
    expect(m.memberNo, 'JBF-Z3-000001');
    final p = await field.env.payments.record(
      PaymentDraft(
        memberId: m.id,
        contributionTypeId: await duesTypeId(field),
        period: '2026-10',
        amount: 2000,
        method: PaymentMethod.cash,
        paidOn: DateTime(2026, 10, 15),
      ),
      actor,
      collectorName: 'Treasurer',
    );
    expect(p.receiptNo, 'RCP-Z3-2026-000001');
  });

  test('payments, voids and edits flow both ways', () async {
    final kofi = (await main.db.select(main.db.members).get()).single;
    final zones = await field.env.zoneIdsByCode();
    final akua = await field.env.members.create(
      field.env.draft('Akua Boateng', [zones[3]!]),
      actor,
    );
    final p = await field.env.payments.record(
      PaymentDraft(
        memberId: akua.id,
        contributionTypeId: await duesTypeId(field),
        period: '2026-10',
        amount: 2000,
        method: PaymentMethod.cash,
        paidOn: DateTime(2026, 10, 15),
      ),
      actor,
      collectorName: 'Treasurer',
    );
    await field.sync.refresh();
    expect(field.sync.state.pending, greaterThan(0));
    await field.sync.syncNow();
    expect(field.sync.state.pending, 0);
    await main.sync.syncNow();
    expect(main.sync.state.issues, 0);

    final onMain = await (main.db.select(
      main.db.payments,
    )..where((t) => t.id.equals(p.id))).getSingle();
    expect(onMain.amount, 2000);
    final akuaZones = await (main.db.select(
      main.db.memberZones,
    )..where((t) => t.memberId.equals(akua.id))).get();
    expect(akuaZones.single.zoneId, zones[3]);

    // Void on the main phone, edit a member on the field phone.
    await main.env.payments.voidPayment(p.id, 'Wrong month', actor);
    await field.env.members.update(
      kofi.id,
      field.env.draft('Kofi Mensah Jnr', [zones[1]!]),
      actor,
    );
    await main.sync.syncNow();
    await field.sync.syncNow();
    await main.sync.syncNow();

    final voided = await (field.db.select(
      field.db.payments,
    )..where((t) => t.id.equals(p.id))).getSingle();
    expect(voided.status, PaymentStatus.voided);
    expect(voided.voidReason, 'Wrong month');
    final kofiOnMain = await (main.db.select(
      main.db.members,
    )..where((t) => t.id.equals(kofi.id))).getSingle();
    expect(kofiOnMain.fullName, 'Kofi Mensah Jnr');
    expect(main.sync.state.issues, 0);
    expect(field.sync.state.issues, 0);

    // Audit trails merge.
    final mainAudit = await main.db.select(main.db.auditLogs).get();
    final fieldAudit = await field.db.select(field.db.auditLogs).get();
    expect(mainAudit.length, fieldAudit.length);
  });

  test('the newest edit wins', () async {
    final kofi = (await main.db.select(main.db.members).get()).single;
    final zones = await main.env.zoneIdsByCode();
    await field.env.members.update(
      kofi.id,
      field.env.draft('Older edit', [zones[1]!]),
      actor,
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await main.env.members.update(
      kofi.id,
      main.env.draft('Newer edit', [zones[1]!]),
      actor,
    );
    await main.sync.syncNow();
    await field.sync.syncNow();
    await main.sync.syncNow();
    for (final p in [main, field]) {
      final m = await (p.db.select(
        p.db.members,
      )..where((t) => t.id.equals(kofi.id))).getSingle();
      expect(m.fullName, 'Newer edit');
    }
  });

  test(
    'a password change reaches other phones; login attempts do not',
    () async {
      final ama = await main.env.auth.login(
        'ama',
        'secret1',
        method: LoginMethod.password,
        deviceId: 'main',
      );
      await main.env.auth.changePassword(
        ama,
        'secret1',
        'newpass1',
        deviceId: 'main',
      );
      await main.sync.syncNow();
      await field.sync.syncNow();
      expect(
        () => field.env.auth.login(
          'ama',
          'secret1',
          method: LoginMethod.password,
          deviceId: 'f',
        ),
        throwsA(anything),
      );
      await field.env.auth.login(
        'ama',
        'newpass1',
        method: LoginMethod.password,
        deviceId: 'f',
      );
      // The failed attempt above is this phone's business only.
      expect(field.sync.state.pending, 0);
    },
  );

  test('welfare cases jump forward when a phone missed a step', () async {
    final kofi = (await main.db.select(main.db.members).get()).single;
    final type = (await main.db.select(main.db.welfareCaseTypes).get()).first;
    final c = await main.env.welfare.createCase(
      WelfareCaseDraft(
        memberId: kofi.id,
        caseTypeId: type.id,
        occurredOn: DateTime(2026, 10, 1),
        requestedAmount: 50000,
      ),
      const WelfareActor(actor, name: 'Sec', roleName: 'Secretary'),
    );
    await main.sync.syncNow();
    await field.sync.syncNow();
    await main.db.customStatement(
      "UPDATE welfare_cases SET status = 'approved' WHERE id = ?",
      [c.id],
    );
    await main.db.customStatement(
      "UPDATE welfare_cases SET status = 'paid' WHERE id = ?",
      [c.id],
    );
    await main.sync.syncNow();
    await field.sync.syncNow();
    expect(field.sync.state.issues, 0);
    final onField = await (field.db.select(
      field.db.welfareCases,
    )..where((t) => t.id.equals(c.id))).getSingle();
    expect(onField.status, WelfareStatus.paid);
  });

  test('a removed phone is told so', () async {
    cloud.revoked.add(cloud.devices[field.sync.credentials!.token]!.id);
    await field.sync.syncNow();
    expect(field.sync.state.error, contains('removed'));
    await field.sync.leave();
    expect(field.sync.state.enabled, isFalse);
  });

  test('a phone with unrelated records is not merged', () async {
    final other = Phone(cloud);
    await other.env.auth.createInitialAdmin(
      displayName: 'X',
      username: 'x',
      password: 'secret1',
      deviceId: 'x',
    );
    await other.sync.load();
    await expectLater(
      other.sync.join(
        code: await main.sync.createCode(),
        deviceName: 'Other',
        series: 'Q',
      ),
      throwsA(isA<SyncException>()),
    );
    expect(other.sync.state.enabled, isFalse);
    await other.close();
  });

  test('a new phone joins by signing in, without a code', () async {
    final third = Phone(cloud);
    await third.sync.load();
    await expectLater(
      third.sync.signIn(org: 'JBF', username: 'ama', password: 'nope'),
      throwsA(isA<SyncException>()),
    );
    expect(
      await third.sync.signIn(org: 'jbf', username: 'AMA', password: 'secret1'),
      JoinOutcome.received,
    );
    expect(third.sync.state.credentials?.series, 'P2');
    final org = await third.db.select(third.db.orgSettings).getSingle();
    expect(org.deviceSeries, 'P2');
    expect(await third.db.select(third.db.members).get(), hasLength(1));
    await third.close();
  });

  test('executives and members sign in with their member ID', () async {
    final zones = await main.env.zoneIdsByCode();
    final founder = await main.env.auth.login(
      'ama',
      'secret1',
      method: LoginMethod.password,
      deviceId: 'main',
    );
    final yaw = await main.env.members.create(
      MemberDraft(
        fullName: 'Yaw Boateng',
        dateJoined: DateTime(2026, 1, 1),
        zoneIds: [zones[2]!],
        phone: '0241112222',
      ),
      actor,
    );
    final mayor = (await main.env.auth.roles()).firstWhere(
      (r) => r.key == 'zone_mayor',
    );
    await main.env.auth.assignRole(
      memberId: yaw.id,
      roleId: mayor.id,
      zoneIds: [zones[2]!],
      by: founder,
      deviceId: 'main',
    );
    await main.sync.syncNow();

    // Activation is checked against the phone number on record.
    final api = cloud.api;
    await expectLater(
      api.memberAuth(
        action: 'activate',
        org: 'JBF',
        memberNo: yaw.memberNo,
        newPassword: 'pass123',
        phone: '0200000000',
      ),
      throwsA(isA<SyncException>()),
    );
    final r = await api.memberAuth(
      action: 'activate',
      org: 'JBF',
      memberNo: yaw.memberNo.toLowerCase(),
      newPassword: 'pass123',
      phone: '+233 24 111 2222',
    );
    expect(r, isA<OfficerSignIn>());

    // The Zone Mayor's phone joins and signs in with the member ID.
    final third = Phone(cloud);
    third.env.auth.cloudCheck = (no, pw, {newPassword}) => api.memberAuth(
      action: newPassword == null ? 'sign_in' : 'change_password',
      org: 'JBF',
      memberNo: no,
      password: pw,
      newPassword: newPassword,
      check: true,
    );
    await third.sync.load();
    await third.sync.joinEnrollment((r as OfficerSignIn).enrollment, 'Yaw');
    final user = await third.env.auth.login(
      yaw.memberNo,
      'pass123',
      method: LoginMethod.password,
      deviceId: 'yaw',
    );
    expect(user.memberAccount, isTrue);
    expect(user.memberId, yaw.id);
    expect(user.roleName, 'Zone Mayor');
    expect(user.zoneScope, {zones[2]});
    expect(user.can(Perm.membersView), isTrue);
    expect(user.can(Perm.zoneRolesAssign), isTrue);
    expect(user.can(Perm.rolesAssign), isFalse);
    await expectLater(
      third.env.auth.login(
        yaw.memberNo,
        'wrong',
        method: LoginMethod.password,
        deviceId: 'yaw',
      ),
      throwsA(isA<AuthException>()),
    );

    // Offline, the copy kept on the phone still works.
    third.env.auth.cloudCheck = (no, pw, {newPassword}) =>
        throw SyncException('offline', offline: true);
    expect(
      (await third.env.auth.login(
        yaw.memberNo,
        'pass123',
        method: LoginMethod.password,
        deviceId: 'yaw',
      )).id,
      yaw.id,
    );

    // A Zone Mayor may give zone roles in their zone only.
    final secretary = (await third.env.auth.roles()).firstWhere(
      (r) => r.key == 'zone_secretary',
    );
    final kofi = (await third.db.select(third.db.members).get()).firstWhere(
      (m) => m.fullName == 'Kofi Mensah',
    );
    await expectLater(
      third.env.auth.assignRole(
        memberId: kofi.id,
        roleId: secretary.id,
        zoneIds: [zones[1]!],
        by: user,
        deviceId: 'yaw',
      ),
      throwsA(isA<AuthException>()),
    );
    final treasurer = (await third.env.auth.roles()).firstWhere(
      (r) => r.key == 'treasurer',
    );
    await expectLater(
      third.env.auth.assignRole(
        memberId: kofi.id,
        roleId: treasurer.id,
        by: user,
        deviceId: 'yaw',
      ),
      throwsA(isA<AuthException>()),
    );

    // An ordinary member gets their own page, not the records.
    final kofiMain = (await main.db.select(main.db.members).get()).firstWhere(
      (m) => m.fullName == 'Kofi Mensah',
    );
    final k = await api.memberAuth(
      action: 'activate',
      org: 'JBF',
      memberNo: kofiMain.memberNo,
      newPassword: 'kofi123',
      phone: '0240000000',
    );
    expect(k, isA<MemberSession>());
    final home = MemberHome.fromJson(
      await api.memberHome((k as MemberSession).token),
    );
    expect(home.statement.name, 'Kofi Mensah');
    expect(home.officer, isFalse);
    await expectLater(
      main.env.auth.login(
        kofiMain.memberNo,
        'kofi123',
        method: LoginMethod.password,
        deviceId: 'main',
      ),
      throwsA(isA<AuthException>()),
    );

    // Removing the role takes the access away on every phone.
    final held = (await main.env.auth.heldRoles(yaw.id)).single;
    await main.env.auth.endRole(held, by: founder, deviceId: 'main');
    await main.sync.syncNow();
    await third.sync.syncNow();
    await expectLater(
      third.env.auth.login(
        yaw.memberNo,
        'pass123',
        method: LoginMethod.password,
        deviceId: 'yaw',
      ),
      throwsA(isA<AuthException>()),
    );
    await third.close();
  });
}
