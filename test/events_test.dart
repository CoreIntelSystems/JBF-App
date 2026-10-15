import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/data/database.dart';
import 'package:jbf_app/data/repositories/events_repository.dart';
import 'package:jbf_app/data/repositories/finance_repository.dart';
import 'package:jbf_app/data/repositories/payment_repository.dart';
import 'package:jbf_app/domain/member_qr.dart';

import 'helpers.dart';

void main() {
  late TestEnv env;
  late Member kofi;
  late Member ama;
  late Map<int, String> zones;

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
  });
  tearDown(() => env.db.close());

  test('event money adds collections and spending linked to it', () async {
    final e = await env.events.saveEvent(
      EventDraft(
        name: 'End of year party',
        kind: EventKind.party,
        startsOn: DateTime(2026, 12, 20, 14),
        budget: 200000,
      ),
      TestEnv.actor,
    );
    final silver = (await env.payments.activeTypes()).firstWhere(
      (t) => t.name == 'Silver collection',
    );
    await env.payments.record(
      PaymentDraft(
        memberId: kofi.id,
        contributionTypeId: silver.id,
        amount: 5000,
        method: PaymentMethod.cash,
        paidOn: DateTime(2026, 12, 20),
        eventId: e.id,
      ),
      TestEnv.actor,
      collectorName: 'T',
    );
    // Not linked to the event.
    await env.payments.record(
      PaymentDraft(
        memberId: ama.id,
        contributionTypeId: silver.id,
        amount: 7000,
        method: PaymentMethod.cash,
        paidOn: DateTime(2026, 12, 20),
      ),
      TestEnv.actor,
      collectorName: 'T',
    );
    final cat = (await env.finance.activeCategories()).first;
    await env.finance.recordExpense(
      ExpenseDraft(
        categoryId: cat.id,
        amount: 3000,
        description: 'Drinks',
        method: PaymentMethod.cash,
        paidOn: DateTime(2026, 12, 20),
        eventId: e.id,
      ),
      TestEnv.actor,
      recordedByName: 'T',
    );
    final m = await env.events.watchEventMoney(e.id).first;
    expect(m.collected, 5000);
    expect(m.spent, 3000);
    expect(m.balance, 2000);
  });

  test('attendance by QR, manual marks and the rest absent', () async {
    final meeting = await env.events.saveMeeting(
      MeetingDraft(
        title: 'Zone 1 meeting',
        kind: MeetingKind.zonal,
        zoneId: zones[1],
        heldOn: DateTime(2026, 10, 15, 16),
      ),
      TestEnv.actor,
    );
    final expected = await env.events.expected(meeting: meeting);
    expect(expected.map((m) => m.fullName), ['Kofi']);

    final (m1, already1) = await env.events.checkInByQr(
      meeting.id,
      MemberQr.encode(ama.memberNo),
      TestEnv.actor,
    );
    expect(m1.id, ama.id);
    expect(already1, isFalse);
    final (_, already2) = await env.events.checkInByQr(
      meeting.id,
      ama.memberNo,
      TestEnv.actor,
    );
    expect(already2, isTrue);
    expect(
      () => env.events.checkInByQr(meeting.id, 'hello', TestEnv.actor),
      throwsA(isA<EventsException>()),
    );

    expect(
      await env.events.markRestAbsent(meeting.id, expected, TestEnv.actor),
      1,
    );
    await env.events.mark(
      meeting.id,
      kofi.id,
      AttendanceStatus.excused,
      TestEnv.actor,
    );
    final list = await env.events.watchAttendance(meeting.id).first;
    final c = EventsRepository.count(list);
    expect((c.present, c.absent, c.excused), (1, 0, 1));
    expect(
      list.firstWhere((e) => e.member.id == ama.id).record.method,
      AttendanceMethod.qr,
    );
  });

  test(
    'executives: appoint, attendance at executive meetings, end term',
    () async {
      final positions = await env.events.watchPositions().first;
      final mayor = positions.firstWhere((p) => p.title == 'Zone Mayor');
      final secretary = positions.firstWhere(
        (p) => p.title == 'General Secretary',
      );
      expect(
        () => env.events.appoint(
          memberId: kofi.id,
          position: mayor,
          termStart: DateTime(2026, 1, 1),
          actor: TestEnv.actor,
        ),
        throwsA(isA<EventsException>()),
      );
      await env.events.appoint(
        memberId: kofi.id,
        position: mayor,
        zoneId: zones[1],
        termStart: DateTime(2026, 1, 1),
        actor: TestEnv.actor,
      );
      await env.events.appoint(
        memberId: ama.id,
        position: secretary,
        termStart: DateTime(2026, 1, 1),
        actor: TestEnv.actor,
      );
      var current = await env.events.currentExecutives();
      expect(current, hasLength(2));
      expect(
        current.firstWhere((v) => v.member.id == kofi.id).title,
        startsWith('Zone Mayor, '),
      );

      final meeting = await env.events.saveMeeting(
        MeetingDraft(
          title: 'Executive meeting',
          kind: MeetingKind.executive,
          heldOn: DateTime(2026, 10, 1, 16),
        ),
        TestEnv.actor,
      );
      final expected = await env.events.expected(meeting: meeting);
      expect(expected, hasLength(2));
      await env.events.mark(
        meeting.id,
        kofi.id,
        AttendanceStatus.present,
        TestEnv.actor,
      );
      final kofiView = current.firstWhere((v) => v.member.id == kofi.id);
      expect(await env.events.meetingAttendance(kofiView), (1, 1));

      await env.events.endTerm(
        kofiView.executive.id,
        DateTime(2026, 10, 10),
        'Elections',
        TestEnv.actor,
      );
      current = await env.events.currentExecutives();
      expect(current.map((v) => v.member.id), [ama.id]);
      final past = await env.events.watchExecutives(current: false).first;
      expect(past.single.executive.endedReason, 'Elections');
    },
  );
}
