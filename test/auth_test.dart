import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/data/repositories/auth_repository.dart';
import 'package:jbf_app/domain/permissions.dart';

import 'helpers.dart';

void main() {
  late TestEnv env;

  setUp(() => env = TestEnv());
  tearDown(() => env.db.close());

  test('seeds every role from the spec', () async {
    final keys = (await env.auth.roles()).map((r) => r.key).toSet();
    expect(
      keys,
      containsAll([
        'super_admin',
        'treasurer',
        'zone_mayor',
        'welfare_chairman',
        'auditor',
        'electoral_commission',
        'member',
      ]),
    );
  });

  test('first-run admin gets every permission and can log in', () async {
    expect(await env.auth.hasUsers(), isFalse);
    final admin = await env.auth.createInitialAdmin(
      displayName: 'Admin',
      username: ' Admin ',
      password: 'secret1',
      pin: '1234',
      deviceId: 'd1',
    );
    expect(admin.username, 'admin');
    expect(admin.permissions, containsAll(Perm.all));
    expect(await env.auth.hasUsers(), isTrue);

    final viaPassword = await env.auth.login(
      'ADMIN',
      'secret1',
      method: LoginMethod.password,
      deviceId: 'd1',
    );
    expect(viaPassword.id, admin.id);
    final viaPin = await env.auth.login(
      'admin',
      '1234',
      method: LoginMethod.pin,
      deviceId: 'd1',
    );
    expect(viaPin.id, admin.id);

    await expectLater(
      env.auth.createInitialAdmin(
        displayName: 'X',
        username: 'x',
        password: 'secret1',
        deviceId: 'd1',
      ),
      throwsA(isA<AuthException>()),
    );
  });

  test('locks the account after 5 wrong attempts', () async {
    await env.auth.createInitialAdmin(
      displayName: 'A',
      username: 'a',
      password: 'secret1',
      deviceId: 'd',
    );
    for (var i = 0; i < 5; i++) {
      await expectLater(
        env.auth.login(
          'a',
          'wrong',
          method: LoginMethod.password,
          deviceId: 'd',
        ),
        throwsA(isA<AuthException>()),
      );
    }
    await expectLater(
      env.auth.login(
        'a',
        'secret1',
        method: LoginMethod.password,
        deviceId: 'd',
      ),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          contains('Too many'),
        ),
      ),
    );
  });

  test('fingerprint login only works when switched on', () async {
    final admin = await env.auth.createInitialAdmin(
      displayName: 'A',
      username: 'a',
      password: 'secret1',
      deviceId: 'd',
    );
    await expectLater(
      env.auth.login('a', '', method: LoginMethod.biometric, deviceId: 'd'),
      throwsA(isA<AuthException>()),
    );
    await env.auth.setBiometric(admin, true, deviceId: 'd');
    final u = await env.auth.login(
      'a',
      '',
      method: LoginMethod.biometric,
      deviceId: 'd',
    );
    expect(u.biometricEnabled, isTrue);
  });

  test('treasurer role cannot manage users', () async {
    final roles = await env.auth.roles();
    final treasurer = roles.firstWhere((r) => r.key == 'treasurer');
    await env.auth.createUser(
      displayName: 'T',
      username: 'treasurer',
      password: 'secret1',
      roleId: treasurer.id,
      actor: TestEnv.actor,
    );
    final t = await env.auth.login(
      'treasurer',
      'secret1',
      method: LoginMethod.password,
      deviceId: 'd',
    );
    expect(t.can(Perm.usersManage), isFalse);
    expect(t.can(Perm.paymentsRecord), isTrue);
  });

  test('dues and welfare approvals follow the agreed roles', () async {
    final roles = await env.auth.roles();
    Future<Set<String>> perms(String key) async {
      final role = roles.firstWhere((r) => r.key == key);
      final rows = await (env.db.select(
        env.db.rolePermissions,
      )..where((p) => p.roleId.equals(role.id))).get();
      return rows.map((r) => r.permission).toSet();
    }

    Future<List<String>> holders(String perm) async => [
      for (final r in roles)
        if ((await perms(r.key)).contains(perm) && r.key != 'super_admin')
          r.key,
    ]..sort();

    expect(await holders(Perm.duesManage), ['founder', 'treasurer']);
    expect(await holders(Perm.duesApprove), ['founder', 'general_secretary']);
    expect(await holders(Perm.welfareSetBenefits), ['founder', 'treasurer']);
    expect(await holders(Perm.welfareApprove), [
      'founder',
      'general_secretary',
      'welfare_chairman',
    ]);
    expect(await holders(Perm.signInReset), [
      'founder',
      'general_secretary',
      'zone_mayor',
      'zone_secretary',
    ]);
  });

  test('zone helpers and zone roles stay inside the zone', () async {
    final zones = await env.zoneIdsByCode();
    final founder = await env.auth.createInitialAdmin(
      displayName: 'Ama',
      username: 'ama',
      password: 'secret1',
      deviceId: 'd1',
    );
    final roles = {for (final r in await env.auth.roles()) r.key: r};
    Future<String> member(String name, int zone) async =>
        (await env.members.create(
          env.draft(name, [zones[zone]!]),
          TestEnv.actor,
        )).id;
    final esi = await member('Esi', 1);
    final kwame = await member('Kwame', 1);
    final yaa = await member('Yaa', 1);
    await env.auth.assignRole(
      memberId: esi,
      roleId: roles['zone_organizer']!.id,
      zoneIds: [zones[1]!],
      by: founder,
      deviceId: 'd1',
    );
    final organizer = await env.auth.loadMemberUser(esi);
    expect(organizer.roleKeys, {'zone_organizer'});

    // The Zone Organizer adds an organizing helper, but not a welfare one.
    await env.auth.assignRole(
      memberId: kwame,
      roleId: roles['zone_organizing_helper']!.id,
      zoneIds: [zones[1]!],
      by: organizer,
      deviceId: 'd2',
    );
    await expectLater(
      env.auth.assignRole(
        memberId: yaa,
        roleId: roles['zone_welfare_helper']!.id,
        zoneIds: [zones[1]!],
        by: organizer,
        deviceId: 'd2',
      ),
      throwsA(isA<AuthException>()),
    );
    await expectLater(
      env.auth.assignRole(
        memberId: yaa,
        roleId: roles['zone_organizing_helper']!.id,
        zoneIds: [zones[2]!],
        by: organizer,
        deviceId: 'd2',
      ),
      throwsA(isA<AuthException>()),
    );
    final helper = await env.auth.loadMemberUser(kwame);
    expect(helper.can(Perm.attendanceRecord), isTrue);
    expect(helper.zoneScope, {zones[1]});

    // A Zone Mayor adds a zone role with access they hold, and gives it.
    await env.auth.assignRole(
      memberId: yaa,
      roleId: roles['zone_mayor']!.id,
      zoneIds: [zones[1]!],
      by: founder,
      deviceId: 'd1',
    );
    final mayor = await env.auth.loadMemberUser(yaa);
    await expectLater(
      env.auth.saveRole(
        name: 'Zone Youth Leader',
        level: 'zone',
        permissions: {Perm.membersView, Perm.financeView},
        by: mayor,
        deviceId: 'd3',
      ),
      throwsA(isA<AuthException>()),
    );
    await env.auth.saveRole(
      name: 'Zone Youth Leader',
      level: 'zone',
      permissions: {Perm.dashboardView, Perm.membersView},
      by: mayor,
      deviceId: 'd3',
    );
    final youth = (await env.auth.roles()).firstWhere(
      (r) => r.name == 'Zone Youth Leader',
    );
    expect(AuthRepository.canEditRole(mayor, youth), isTrue);
    expect(AuthRepository.canEditRole(mayor, roles['treasurer']!), isFalse);
    expect(AuthRepository.canEditRole(founder, roles['treasurer']!), isTrue);
    expect(AuthRepository.canEditRole(founder, roles['super_admin']!), isFalse);

    // The Founder changes what a role can do; holders get it at sign-in.
    await env.auth.saveRole(
      existing: roles['zone_organizing_helper'],
      name: 'Zone Organizing Helper',
      level: 'zone',
      permissions: {Perm.dashboardView, Perm.membersView},
      by: founder,
      deviceId: 'd1',
    );
    expect(
      (await env.auth.loadMemberUser(kwame)).can(Perm.attendanceRecord),
      isFalse,
    );
  });
}
