import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/data/connection.dart';
import 'package:jbf_app/data/database.dart';
import 'package:jbf_app/domain/permissions.dart';

void main() {
  const key =
      'aa112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

  /// Rolls a fresh database back to the shape of an older release.
  Future<void> stripTo(AppDatabase db, int version) async {
    // v14: collection drives.
    for (final table in ['welfare_cases', 'welfare_drive_gifts']) {
      for (final t in ['ins', 'upd', 'stamp']) {
        await db.customStatement('DROP TRIGGER IF EXISTS sync_${table}_$t');
      }
    }
    await db.customStatement('DROP TABLE welfare_drive_gifts');
    for (final c in [
      'drive_status',
      'funeral_on',
      'funeral_venue',
      'family_contact',
      'family_phone',
      'drive_opened_by_name',
      'drive_closed_on',
      'drive_closed_by',
      'drive_closed_by_name',
      'handover_amount',
      'handover_on',
      'handover_method',
      'handover_reference',
      'handover_by',
      'handover_by_name',
    ]) {
      await db.customStatement('ALTER TABLE welfare_cases DROP COLUMN $c');
    }
    if (version >= 13) {
      await db.customStatement('PRAGMA user_version = $version');
      return;
    }
    // v13: welfare membership.
    for (final table in ['members', 'contribution_types']) {
      for (final t in ['ins', 'upd', 'stamp']) {
        await db.customStatement('DROP TRIGGER IF EXISTS sync_${table}_$t');
      }
    }
    for (final c in [
      'welfare_membership',
      'welfare_since',
      'welfare_ended_on',
      'welfare_note',
    ]) {
      await db.customStatement('ALTER TABLE members DROP COLUMN $c');
    }
    for (final c in ['minimum_amount', 'welfare_rule']) {
      await db.customStatement('ALTER TABLE contribution_types DROP COLUMN $c');
    }
    await db.customStatement(
      "DELETE FROM contribution_types WHERE id = 'welfare-contribution'",
    );
    if (version >= 12) {
      await db.customStatement('PRAGMA user_version = $version');
      return;
    }
    // v12: WhatsApp names.
    await db.customStatement('ALTER TABLE members DROP COLUMN whatsapp_name');
    if (version >= 11) {
      await db.customStatement('PRAGMA user_version = $version');
      return;
    }
    // v11: members the founding list may correct for themselves.
    await db.customStatement('ALTER TABLE members DROP COLUMN self_edit');
    if (version >= 10) {
      await db.customStatement('PRAGMA user_version = $version');
      return;
    }
    // v10: announcements.
    for (final r in await db.select(db.roles).get()) {
      final perms = decodePermissions(r.permissions)..remove(Perm.announce);
      await db.customStatement(
        'UPDATE roles SET permissions = ? WHERE id = ?',
        [encodePermissions(perms), r.id],
      );
    }
    if (version >= 9) {
      await db.customStatement('PRAGMA user_version = $version');
      return;
    }
    // v9: zone helpers.
    await db.customStatement(
      'DELETE FROM role_permissions WHERE role_id IN (SELECT id FROM roles '
      "WHERE key IN ('zone_organizing_helper', 'zone_welfare_helper'))",
    );
    await db.customStatement(
      "DELETE FROM roles WHERE key IN ('zone_organizing_helper', "
      "'zone_welfare_helper')",
    );
    for (final r in await db.select(db.roles).get()) {
      final perms = decodePermissions(r.permissions)
        ..remove(Perm.helpersAssign);
      await db.customStatement(
        'UPDATE roles SET permissions = ? WHERE id = ?',
        [encodePermissions(perms), r.id],
      );
    }
    if (version >= 8) {
      await db.customStatement('PRAGMA user_version = $version');
      return;
    }
    // v8: role assignments, permissions on roles, dues approval.
    await db.customStatement('DROP TABLE role_assignments');
    await db.customStatement('DROP TRIGGER roles_permissions_ins');
    await db.customStatement('DROP TRIGGER roles_permissions_upd');
    await db.customStatement('ALTER TABLE roles DROP COLUMN permissions');
    for (final c in [
      'proposed_amount',
      'proposed_by_name',
      'proposed_at',
      'approved_by_name',
    ]) {
      await db.customStatement('ALTER TABLE contribution_types DROP COLUMN $c');
    }
    const newRoles =
        "('patron', 'welfare_secretary', 'welfare_treasurer', "
        "'discipline_member', 'ec_secretary')";
    await db.customStatement(
      'DELETE FROM role_permissions WHERE role_id IN '
      '(SELECT id FROM roles WHERE key IN $newRoles)',
    );
    await db.customStatement('DELETE FROM roles WHERE key IN $newRoles');
    await db.customStatement(
      "DELETE FROM executive_positions WHERE title IN ('Patron', "
      "'Welfare Treasurer', 'Electoral Commission Secretary', "
      "'Disciplinary Committee')",
    );
    if (version >= 7) {
      await db.customStatement('PRAGMA user_version = $version');
      return;
    }
    final syncTriggers = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'trigger' "
          "AND name LIKE 'sync_%'",
        )
        .get();
    for (final t in syncTriggers) {
      await db.customStatement('DROP TRIGGER ${t.read<String>('name')}');
    }
    for (final t in [
      'sync_outbox',
      'sync_flags',
      'sync_state',
      'sync_issues',
    ]) {
      await db.customStatement('DROP TABLE $t');
    }
    await db.customStatement('DROP TRIGGER welfare_cases_flow');
    await db.customStatement('''
      CREATE TRIGGER welfare_cases_flow BEFORE UPDATE ON welfare_cases
      WHEN NEW.case_no IS NOT OLD.case_no
      BEGIN SELECT RAISE(ABORT, 'This welfare case can no longer be changed'); END
    ''');
    await db.customStatement('ALTER TABLE org_settings DROP COLUMN updated_at');
    await db.customStatement(
      'ALTER TABLE org_settings DROP COLUMN device_series',
    );
    if (version >= 6) {
      await db.customStatement('PRAGMA user_version = $version');
      return;
    }
    await db.customStatement('ALTER TABLE users DROP COLUMN zone_ids');
    if (version >= 5) {
      await db.customStatement('PRAGMA user_version = $version');
      return;
    }
    for (final t in [
      'executives',
      'executive_positions',
      'attendance_records',
      'meetings',
      'events',
    ]) {
      await db.customStatement('DROP TABLE $t');
    }
    await db.customStatement('ALTER TABLE payments DROP COLUMN event_id');
    await db.customStatement(
      'DELETE FROM role_permissions WHERE permission IN '
      "('attendance.record', 'executives.manage')",
    );
    if (version >= 4) {
      await db.customStatement('PRAGMA user_version = $version');
      return;
    }
    for (final t in ['expenses_no_delete', 'expenses_no_edit']) {
      await db.customStatement('DROP TRIGGER $t');
    }
    await db.customStatement('DROP TABLE expenses');
    await db.customStatement('DROP TABLE expense_categories');
    await db.customStatement(
      'ALTER TABLE org_settings DROP COLUMN next_expense_no',
    );
    await db.customStatement(
      "DELETE FROM role_permissions WHERE permission = 'expenses.record'",
    );
    if (version >= 3) {
      await db.customStatement('PRAGMA user_version = $version');
      return;
    }
    for (final t in ['welfare_cases_no_delete', 'welfare_cases_flow']) {
      await db.customStatement('DROP TRIGGER $t');
    }
    await db.customStatement('DROP TABLE welfare_cases');
    await db.customStatement('DROP TABLE welfare_case_types');
    await db.customStatement(
      'ALTER TABLE org_settings DROP COLUMN next_welfare_case_no',
    );
    await db.customStatement(
      "DELETE FROM role_permissions WHERE permission = 'welfare.pay'",
    );
    if (version < 2) {
      await db.customStatement('DROP TRIGGER payments_no_delete');
      await db.customStatement('DROP TRIGGER payments_no_edit');
      await db.customStatement('DROP TABLE payments');
      await db.customStatement('DROP TABLE contribution_types');
      await db.customStatement(
        'ALTER TABLE org_settings DROP COLUMN receipt_prefix',
      );
      await db.customStatement(
        'ALTER TABLE org_settings DROP COLUMN next_receipt_no',
      );
    }
    await db.customStatement('PRAGMA user_version = $version');
  }

  Future<void> expectCurrent(AppDatabase db) async {
    expect(await db.select(db.zones).get(), hasLength(8));
    final memberColumns = await db
        .customSelect('PRAGMA table_info(members)')
        .get();
    expect(
      memberColumns.map((c) => c.read<String>('name')),
      containsAll([
        'self_edit',
        'whatsapp_name',
        'welfare_membership',
        'welfare_since',
      ]),
    );
    final memberTrigger = await db
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE name = 'sync_members_upd'",
        )
        .getSingle();
    expect(memberTrigger.read<String>('sql'), contains('whatsapp_name'));
    expect(memberTrigger.read<String>('sql'), contains('welfare_since'));
    final types = await db.select(db.contributionTypes).get();
    expect(types, hasLength(8));
    expect(
      types.singleWhere((t) => t.name == 'Welfare contribution').welfareRule,
      WelfareRule.contribution,
    );
    expect(
      types.singleWhere((t) => t.name == 'Monthly welfare dues').welfareRule,
      WelfareRule.dues,
    );
    expect(await db.select(db.welfareCaseTypes).get(), hasLength(7));
    final org = await db.select(db.orgSettings).getSingle();
    expect(org.receiptPrefix, 'RCP');
    expect(org.nextWelfareCaseNo, 1);
    final triggers = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'trigger' "
          "AND (name LIKE 'payments_%' OR name LIKE 'welfare_%' "
          "OR name LIKE 'expenses_%')",
        )
        .get();
    expect(triggers, hasLength(7));
    final flow = await db
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE name = 'welfare_cases_flow'",
        )
        .getSingle();
    expect(flow.read<String>('sql'), contains('applying'));
    final syncTriggers = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'trigger' "
          "AND name LIKE 'sync_%'",
        )
        .get();
    // Insert triggers on the 20 uploaded tables; update and stamp
    // triggers on the 19 whose rows change.
    expect(syncTriggers, hasLength(20 + 19 * 2));
    expect(org.deviceSeries, isNull);
    expect(await db.select(db.expenseCategories).get(), hasLength(10));
    expect(await db.select(db.executivePositions).get(), hasLength(20));
    expect(await db.select(db.events).get(), isEmpty);
    final attend = await db
        .customSelect(
          'SELECT r.key FROM role_permissions p JOIN roles r '
          "ON r.id = p.role_id WHERE p.permission = 'attendance.record'",
        )
        .get();
    expect(attend.map((r) => r.read<String>('key')).toSet(), {
      'super_admin',
      'founder',
      'general_secretary',
      'organizer',
      'zone_mayor',
      'zone_secretary',
      'zone_organizer',
      'zone_organizing_helper',
    });
    final pay = await db
        .customSelect(
          'SELECT r.key FROM role_permissions p JOIN roles r '
          "ON r.id = p.role_id WHERE p.permission = 'welfare.pay'",
        )
        .get();
    expect(pay.map((r) => r.read<String>('key')).toSet(), {
      'super_admin',
      'founder',
      'treasurer',
      'welfare_treasurer',
    });
    expect(await db.select(db.roles).get(), hasLength(defaultRoles.length));
    final announcers = await db
        .customSelect(
          'SELECT r.key FROM role_permissions p JOIN roles r ON r.id = p.role_id '
          'WHERE p.permission = ?',
          variables: [Variable.withString(Perm.announce)],
        )
        .get();
    expect(
      {for (final a in announcers) a.read<String>('key')},
      {'super_admin', 'founder', 'general_secretary'},
    );
    final helpers = await db
        .customSelect(
          'SELECT r.key FROM role_permissions p JOIN roles r ON r.id = p.role_id '
          'WHERE p.permission = ?',
          variables: [Variable.withString(Perm.helpersAssign)],
        )
        .get();
    expect(
      {for (final h in helpers) h.read<String>('key')},
      {'super_admin', 'founder', 'zone_organizer', 'zone_welfare_officer'},
    );
    expect(
      (await db.select(db.roles).get()).every((r) => r.permissions != null),
      isTrue,
    );
  }

  for (final from in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]) {
    test('a v$from database upgrades to the current schema', () async {
      final dir = await Directory.systemTemp.createTemp('jbf_mig');
      final file = File('${dir.path}/jbf.db');
      var db = openDatabaseFile(file, hexKey: key);
      expect(await db.select(db.zones).get(), hasLength(8));
      await stripTo(db, from);
      await db.close();

      db = openDatabaseFile(file, hexKey: key);
      await expectCurrent(db);
      await db.close();
      await dir.delete(recursive: true);
    });
  }
}
