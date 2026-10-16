import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/data/access_scope.dart';
import 'package:jbf_app/data/database.dart';
import 'package:jbf_app/data/repositories/analytics_repository.dart';
import 'package:jbf_app/data/repositories/auth_repository.dart';
import 'package:jbf_app/data/repositories/member_repository.dart';
import 'package:jbf_app/data/repositories/payment_repository.dart';

import 'helpers.dart';

void main() {
  late TestEnv env;
  late Map<int, String> zones;
  late Member kofi;
  late Member ama;

  setUp(() async {
    env = TestEnv(clock: () => DateTime(2026, 10, 15, 12));
    zones = await env.zoneIdsByCode();
    kofi = await env.members.create(
      env.draft('Kofi', [zones[1]!]),
      TestEnv.actor,
    );
    ama = await env.members.create(
      env.draft('Ama', [zones[2]!]),
      TestEnv.actor,
    );
    final dues = (await env.payments.activeTypes()).firstWhere(
      (t) => t.name == 'Monthly welfare dues',
    );
    await env.payments.saveType(
      dues.id,
      const ContributionTypesCompanion(amount: Value(2000)),
      TestEnv.actor,
    );
    for (final m in [kofi, ama]) {
      await env.payments.record(
        PaymentDraft(
          memberId: m.id,
          contributionTypeId: dues.id,
          amount: 2000,
          method: PaymentMethod.cash,
          paidOn: DateTime(2026, 10, 15),
          period: '2026-01',
        ),
        TestEnv.actor,
        collectorName: 'T',
      );
    }
  });
  tearDown(() => env.db.close());

  test('a zone leader only sees members and money of their zone', () async {
    env.scope.zoneIds = {zones[1]!};
    final members = await env.members.watchMembers(const MemberFilter()).first;
    expect(members.map((m) => m.member.id), [kofi.id]);
    final payments = await env.payments.watchRecent().first;
    expect(payments.map((p) => p.member?.id), [kofi.id]);
    final defaulters = await env.payments.defaulters();
    expect(defaulters.map((d) => d.$1.id), [kofi.id]);
    final stats = await env.payments.watchCollectionStats().first;
    expect(stats.today, 2000);
    final dash = await env.dashboard.watchStats().first;
    expect(dash.total, 1);
    expect(dash.byZone.map((z) => z.zone.id), [zones[1]]);

    env.scope.zoneIds = null;
    expect(
      await env.members.watchMembers(const MemberFilter()).first,
      hasLength(2),
    );
    expect((await env.payments.watchCollectionStats().first).today, 4000);
  });

  test('zone roles need a zone and sign in limited to it', () async {
    final roles = await env.auth.roles();
    final zoneTreasurer = roles.firstWhere((r) => r.key == 'zone_treasurer');
    expect(
      () => env.auth.createUser(
        displayName: 'Zone 1 Treasurer',
        username: 'z1t',
        password: 'secret1',
        roleId: zoneTreasurer.id,
        actor: TestEnv.actor,
      ),
      throwsA(isA<AuthException>()),
    );
    await env.auth.createUser(
      displayName: 'Zone 1 Treasurer',
      username: 'z1t',
      password: 'secret1',
      roleId: zoneTreasurer.id,
      zoneIds: [zones[1]!],
      actor: TestEnv.actor,
    );
    final user = await env.auth.login(
      'z1t',
      'secret1',
      method: LoginMethod.password,
      deviceId: 'd1',
    );
    expect(user.zoneScope, {zones[1]});
    expect(AccessScope(user.zoneScope).allowsZone(zones[2]!), isFalse);
  });

  test(
    'charts: collections by month and zone, growth, respects scope',
    () async {
      final analytics = AnalyticsRepository(
        env.db,
        clock: () => DateTime(2026, 10, 15, 12),
        scope: env.scope,
      );
      var a = await analytics.load();
      expect(a.monthlyCollections, hasLength(12));
      expect(a.monthlyCollections.last.label, 'Oct');
      expect(a.monthlyCollections.last.value, 4000);
      expect(a.zoneCollections.firstWhere((p) => p.label == 'Z1').value, 2000);
      expect(a.zoneCollections.firstWhere((p) => p.label == 'Z2').value, 2000);
      // Both joined on 1 Jan 2026, inside the 12-month window.
      expect(a.memberTotals.last.value, 2);
      expect(a.newMembers.fold(0, (s, p) => s + p.value), 2);

      env.scope.zoneIds = {zones[1]!};
      a = await analytics.load();
      expect(a.monthlyCollections.last.value, 2000);
      expect(a.zoneCollections.map((p) => p.label), ['Z1']);
      expect(a.memberTotals.last.value, 1);
    },
  );
}
