import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/data/connection.dart';
import 'package:jbf_app/data/database.dart';

void main() {
  const key =
      'aa112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

  /// Rolls a fresh database back to the shape of an older release.
  Future<void> stripTo(AppDatabase db, int version) async {
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
    expect(await db.select(db.contributionTypes).get(), hasLength(7));
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
    expect(triggers, hasLength(6));
    expect(await db.select(db.expenseCategories).get(), hasLength(10));
    final pay = await db
        .customSelect(
          'SELECT r.key FROM role_permissions p JOIN roles r '
          "ON r.id = p.role_id WHERE p.permission = 'welfare.pay'",
        )
        .get();
    expect(pay.map((r) => r.read<String>('key')).toSet(), {
      'super_admin',
      'treasurer',
    });
  }

  for (final from in [1, 2, 3]) {
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
