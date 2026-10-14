import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/data/connection.dart';

void main() {
  test(
    'a Phase 1 (v1) database upgrades to payments (v2) keeping data',
    () async {
      final dir = await Directory.systemTemp.createTemp('jbf_mig');
      final file = File('${dir.path}/jbf.db');
      const key =
          'aa112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

      // Build a database, then strip it back to the v1 shape.
      var db = openDatabaseFile(file, hexKey: key);
      expect(await db.select(db.zones).get(), hasLength(8));
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
      await db.customStatement('PRAGMA user_version = 1');
      await db.close();

      db = openDatabaseFile(file, hexKey: key);
      expect(await db.select(db.zones).get(), hasLength(8));
      expect(await db.select(db.contributionTypes).get(), hasLength(7));
      final org = await db.select(db.orgSettings).getSingle();
      expect(org.receiptPrefix, 'RCP');
      expect(org.nextReceiptNo, 1);
      final triggers = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'trigger' "
            "AND name LIKE 'payments_%'",
          )
          .get();
      expect(triggers, hasLength(2));
      await db.close();
      await dir.delete(recursive: true);
    },
  );
}
