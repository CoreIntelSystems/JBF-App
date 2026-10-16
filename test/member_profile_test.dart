import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/data/sync/sync_api.dart';
import 'package:jbf_app/features/portal/member_profile_screen.dart';

void main() {
  testWidgets('zones are read-only once the member has chosen them', (
    tester,
  ) async {
    final home = MemberHome.fromJson({
      'member': {'name': 'Kofi', 'member_no': 'JBF-000002', 'status': 'active'},
      'dues': [],
      'payments': [],
      'self_edit': true,
      'zones_locked': true,
      'profile': {'full_name': 'Kofi'},
      'zone_options': [
        {'id': 'z1', 'code': 1, 'name': 'Zone 1'},
        {'id': 'z2', 'code': 2, 'name': 'Zone 2'},
      ],
      'zone_ids': ['z1'],
    });
    expect(home.zonesLocked, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        home: MemberProfileScreen(
          home: home,
          session: const MemberSession(
            token: 't',
            memberKey: 'k',
            memberNo: 'JBF-000002',
            name: 'Kofi',
            orgName: 'JBF',
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.textContaining('already chosen'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(CheckboxListTile), findsNothing);
  });
}
