import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/data/repositories/member_repository.dart';
import 'package:jbf_app/features/members/id_card_pdf.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ID card PDF shows roles and builds', () async {
    final env = TestEnv();
    final zones = await env.zoneIdsByCode();
    final a = await env.members.create(
      env.draft('Naomi Adarkwa', [zones[3]!]),
      TestEnv.actor,
    );
    final b = await env.members.create(
      env.draft('Kwame Mensah Boateng', [zones[1]!])
        ..whatsappName = 'Kwame 🇬🇭 Boat',
      TestEnv.actor,
    );
    final list = (await env.members.watchMembers(MemberFilter()).first);
    final org = await env.payments.org();
    final bytes = await buildIdCardsPdf(
      list,
      org,
      roles: {
        a.id: [
          'Zone Mayor (Zone 3)',
          'Treasurer',
          'Welfare Chairman',
          'Patron',
        ],
      },
    );
    expect(bytes.length, greaterThan(1000));
    final out = Platform.environment['CARD_OUT'];
    if (out != null) File(out).writeAsBytesSync(bytes);
    expect(b.id, isNotEmpty);
  });
}
