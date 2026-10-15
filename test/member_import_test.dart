import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/core/sheet_reader.dart';
import 'package:jbf_app/core/xlsx.dart';
import 'package:jbf_app/data/repositories/member_repository.dart';
import 'package:jbf_app/domain/member_import.dart';

import 'helpers.dart';

void main() {
  final sheet = [
    ['Name', 'Phone 1', 'Phone 2', 'Phone 3', 'Note'],
    ['Abel King June', '+233 24 486 2488', null, null, null],
    [
      'Abby Queen June',
      '+233 20 810 3636',
      '+233 55 408 2776',
      '0201112222',
      null,
    ],
    ['(not saved)', '+233 26 577 8617', null, null, null],
    ['@MsAssiful', null, null, null, 'Username only'],
    ['Kofi Mensah', '0244862488', null, null, null],
    ['Esi Boateng', null, null, null, null],
    ['Ama Owusu', '+44 7700 900123', null, null, null],
  ];

  test('reads an xlsx and plans the import', () {
    final bytes = buildXlsx([XlsxSheet('Group numbers', sheet)]);
    final rows = readSheetRows(bytes, 'list.xlsx');
    expect(rows.first.take(2), ['Name', 'Phone 1']);

    final plan = planMemberImport(rows);
    expect(plan.members.map((m) => m.name), [
      'Abel',
      'Abby',
      'Member 0265778617',
      'Ama Owusu',
    ]);
    expect(plan.members[0].phone, '0244862488');
    expect(plan.members[0].gender, 'Male');
    expect(plan.members[1].gender, 'Female');
    expect(plan.members[1].whatsapp, '0554082776');
    expect(plan.members[1].otherNumbers, ['0201112222']);
    expect(plan.members[2].unnamed, isTrue);
    expect(plan.members[3].phone, '+447700900123');
    expect(plan.skipped.map((s) => s.reason), [
      'WhatsApp username only, no number',
      'Same number as row 2',
      'No usable phone number',
    ]);
    expect(plan.hasZones, isFalse);
    expect(plan.withoutZone, 4);
  });

  test('leaves out people who are already registered', () {
    final plan = planMemberImport(
      readSheetRows(buildXlsx([XlsxSheet('S', sheet)]), 'list.xlsx'),
      existing: {phoneKey('0244862488')},
    );
    expect(plan.members.map((m) => m.name), [
      'Abby',
      'Member 0265778617',
      'Ama Owusu',
    ]);
    expect(plan.skipped.first.reason, contains('Already registered'));
  });

  test('reads zones from a csv', () {
    const csv =
        'Name,Phone 1,Zone,Zone 2\n'
        'Abel,0244862488,3,\n'
        '"Kwame, Jr",0201234567,Zone 5,7\n'
        'Efua,0551234567,x,\n';
    final plan = planMemberImport(
      readSheetRows(Uint8List.fromList(utf8.encode(csv)), 'list.csv'),
    );
    expect(plan.hasZones, isTrue);
    expect(plan.members.map((m) => m.zones), [
      [3],
      [5, 7],
    ]);
    expect(plan.members[1].name, 'Kwame, Jr');
    expect(plan.skipped.single.reason, contains('Zone "x"'));
  });

  test(
    'imported people register with zones and can activate by phone',
    () async {
      final env = TestEnv();
      final zones = await env.zoneIdsByCode();
      final plan = planMemberImport(
        readSheetRows(buildXlsx([XlsxSheet('S', sheet)]), 'l.xlsx'),
      );
      for (final m in plan.members) {
        await env.members.create(
          MemberDraft(
            fullName: m.name,
            gender: m.gender,
            phone: m.phone,
            whatsapp: m.whatsapp,
            dateJoined: DateTime(2026, 10, 15),
            zoneIds: [zones[1]!],
          ),
          TestEnv.actor,
        );
      }
      final all = await env.members.watchMembers(MemberFilter()).first;
      expect(all.length, 4);
      expect(all.map((m) => m.member.memberNo), contains('JBF-000001'));
    },
  );

  test(
    'the holding zone is created once and used for the unassigned',
    () async {
      final env = TestEnv();
      final a = await env.members.ensureHoldingZone();
      final b = await env.members.ensureHoldingZone();
      expect(a, b);
      final m = await env.members.create(
        MemberDraft(
          fullName: 'Esi',
          phone: '0241234567',
          dateJoined: DateTime(2026, 10, 15),
          zoneIds: [a],
          primaryZoneId: a,
          selfEdit: true,
        ),
        TestEnv.actor,
      );
      final back = await env.members.getMember(m.id);
      expect(back!.zones.single.name, 'Unassigned');
    },
  );
}
