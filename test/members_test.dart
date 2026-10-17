import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/data/database.dart';
import 'package:jbf_app/data/repositories/member_repository.dart';
import 'package:jbf_app/domain/zone_rules.dart';

import 'helpers.dart';

void main() {
  late TestEnv env;
  late Map<int, String> zone;

  setUp(() async {
    env = TestEnv();
    zone = await env.zoneIdsByCode();
  });
  tearDown(() => env.db.close());

  test('seeds 8 zones with Zone 6 inactive', () async {
    final zones = await env.members.zones();
    expect(zones, hasLength(8));
    expect(zones.where((z) => !z.isActive).map((z) => z.code), [6]);
    expect(zones.first.nickname, 'Legends');
  });

  test('seeds JBF green and gold as configurable brand colours', () async {
    final org = await env.db.select(env.db.orgSettings).getSingle();
    expect(org.primaryColor, 0xFF0B6B3A);
    expect(org.accentColor, 0xFFC9A227);
  });

  test('allocates sequential member IDs', () async {
    final a = await env.members.create(
      env.draft('Ama', [zone[1]!]),
      TestEnv.actor,
    );
    final b = await env.members.create(
      env.draft('Kofi', [zone[2]!]),
      TestEnv.actor,
    );
    expect(a.memberNo, 'JBF-000001');
    expect(b.memberNo, 'JBF-000002');
  });

  test('accepts one or two zones and rejects three', () async {
    await env.members.create(env.draft('One', [zone[1]!]), TestEnv.actor);
    await env.members.create(
      env.draft('Two', [zone[1]!, zone[2]!]),
      TestEnv.actor,
    );
    await expectLater(
      env.members.create(
        env.draft('Three', [zone[1]!, zone[2]!, zone[3]!]),
        TestEnv.actor,
      ),
      throwsA(
        isA<ZoneRuleException>().having(
          (e) => e.message,
          'message',
          ZoneRules.tooManyMessage,
        ),
      ),
    );
    await expectLater(
      env.members.create(env.draft('None', []), TestEnv.actor),
      throwsA(isA<ZoneRuleException>()),
    );
  });

  test('rejects new assignment to inactive Zone 6', () async {
    await expectLater(
      env.members.create(env.draft('Six', [zone[6]!]), TestEnv.actor),
      throwsA(isA<ZoneRuleException>()),
    );
  });

  test(
    'database trigger blocks a third zone even outside the app logic',
    () async {
      final m = await env.members.create(
        env.draft('Guarded', [zone[1]!, zone[2]!]),
        TestEnv.actor,
      );
      await expectLater(
        env.db
            .into(env.db.memberZones)
            .insert(
              MemberZonesCompanion.insert(memberId: m.id, zoneId: zone[3]!),
            ),
        throwsA(
          predicate((e) => e.toString().contains(maxZonesTriggerMessage)),
        ),
      );
    },
  );

  test('swapping zones on edit works and keeps the limit', () async {
    final m = await env.members.create(
      env.draft('Swap', [zone[1]!, zone[2]!]),
      TestEnv.actor,
    );
    await env.members.update(
      m.id,
      env.draft('Swap', [zone[3]!, zone[4]!]),
      TestEnv.actor,
    );
    var loaded = await env.members.getMember(m.id);
    expect(loaded!.zones.map((z) => z.code), [3, 4]);

    // Moving back restores the earlier soft-deleted rows.
    await env.members.update(
      m.id,
      env.draft('Swap', [zone[1]!, zone[4]!]),
      TestEnv.actor,
    );
    loaded = await env.members.getMember(m.id);
    expect(loaded!.zones.map((z) => z.code), [1, 4]);
    expect(loaded.primaryZoneId, zone[1]);
  });

  test(
    'search by name, WhatsApp name, phone and member ID, and zone',
    () async {
      await env.members.create(
        env.draft('Abena Mensah', [zone[1]!]),
        TestEnv.actor,
      );
      final k = env.draft('Kwame Boateng', [zone[2]!])
        ..phone = '0551234567'
        ..whatsappName = ' Kay B 🇬🇭 ';
      await env.members.create(k, TestEnv.actor);

      Future<List<String>> names(MemberFilter f) async =>
          (await env.members.watchMembers(f).first)
              .map((m) => m.member.fullName)
              .toList();

      expect(await names(const MemberFilter(query: 'abena')), ['Abena Mensah']);
      expect(await names(const MemberFilter(query: '0551')), ['Kwame Boateng']);
      expect(await names(const MemberFilter(query: 'JBF-000001')), [
        'Abena Mensah',
      ]);
      expect(await names(const MemberFilter(query: 'kay b')), [
        'Kwame Boateng',
      ]);
      expect(await names(MemberFilter(zoneId: zone[2])), ['Kwame Boateng']);
      final saved =
          (await env.members
                  .watchMembers(const MemberFilter(query: 'Kwame'))
                  .first)
              .single
              .member;
      expect(saved.whatsappName, 'Kay B 🇬🇭');
    },
  );

  test('status changes and edits are written to the audit log', () async {
    final m = await env.members.create(
      env.draft('Audited', [zone[1]!]),
      TestEnv.actor,
    );
    await env.members.changeStatus(m.id, MemberStatus.suspended, TestEnv.actor);
    final logs = await env.audit.watchRecent().first;
    expect(
      logs.map((l) => l.action),
      containsAll(['member.create', 'member.status']),
    );

    // Audit rows cannot be altered.
    await expectLater(
      env.db.customStatement('DELETE FROM audit_logs'),
      throwsA(anything),
    );
    expect(
      await (env.db.select(env.db.auditLogs)).get(),
      hasLength(logs.length),
    );
  });
}
