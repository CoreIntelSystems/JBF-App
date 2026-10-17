import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/core/xlsx.dart';
import 'package:jbf_app/data/backup_service.dart';
import 'package:jbf_app/data/connection.dart';
import 'package:jbf_app/data/database.dart';
import 'package:jbf_app/data/repositories/finance_repository.dart';
import 'package:jbf_app/data/repositories/payment_repository.dart';
import 'package:jbf_app/data/repositories/welfare_repository.dart';
import 'package:jbf_app/features/reports/report_export.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('expenses and reports', () {
    late TestEnv env;
    late Member kofi;
    late ContributionType silver;

    setUp(() async {
      env = TestEnv(clock: () => DateTime(2026, 10, 14, 12));
      final zones = await env.zoneIdsByCode();
      kofi = await env.members.create(
        env.draft('Kofi', [zones[3]!]),
        TestEnv.actor,
      );
      silver = (await env.payments.activeTypes()).firstWhere(
        (t) => t.name == 'Silver collection',
      );
    });
    tearDown(() => env.db.close());

    Future<void> pay(int amount, DateTime on, {Member? m}) =>
        env.payments.record(
          PaymentDraft(
            memberId: m?.id,
            contributionTypeId: silver.id,
            amount: amount,
            method: PaymentMethod.cash,
            paidOn: on,
          ),
          TestEnv.actor,
          collectorName: 'T',
        );

    Future<Expense> spend(int amount, DateTime on) async {
      final cat = (await env.finance.activeCategories()).first;
      return env.finance.recordExpense(
        ExpenseDraft(
          categoryId: cat.id,
          amount: amount,
          description: 'Hall',
          method: PaymentMethod.momo,
          paidOn: on,
        ),
        TestEnv.actor,
        recordedByName: 'Treasurer',
      );
    }

    test('vouchers, void and immutability', () async {
      final e = await spend(5000, DateTime(2026, 10, 2));
      expect(e.voucherNo, 'EXP-2026-000001');
      await expectLater(
        env.finance.voidExpense(e.id, '', TestEnv.actor),
        throwsA(isA<FinanceException>()),
      );
      await env.finance.voidExpense(e.id, 'Duplicate', TestEnv.actor);
      await expectLater(
        env.db.customStatement("DELETE FROM expenses WHERE id = '${e.id}'"),
        throwsA(anything),
      );
      await expectLater(
        env.db.customStatement(
          "UPDATE expenses SET amount = 1 WHERE id = '${e.id}'",
        ),
        throwsA(anything),
      );
    });

    test('monthly report with opening balance, zones and payouts', () async {
      await pay(10000, DateTime(2026, 9, 20), m: kofi); // before: opening
      await spend(3000, DateTime(2026, 9, 25)); // before: opening
      await pay(20000, DateTime(2026, 10, 3), m: kofi);
      await pay(500, DateTime(2026, 10, 4)); // anonymous
      final voided = await spend(999, DateTime(2026, 10, 5));
      await env.finance.voidExpense(voided.id, 'Wrong', TestEnv.actor);
      await spend(4000, DateTime(2026, 10, 6));
      await pay(7000, DateTime(2026, 11, 1), m: kofi); // after: excluded

      // A paid welfare case counts as spending.
      const by = WelfareActor(TestEnv.actor, name: 'T', roleName: 'Treasurer');
      await env.welfare.joinWelfare(kofi.id, by);
      final type = (await env.welfare.activeCaseTypes()).first;
      final c = await env.welfare.createCase(
        WelfareCaseDraft(
          memberId: kofi.id,
          caseTypeId: type.id,
          occurredOn: DateTime(2026, 10, 1),
          requestedAmount: 6000,
        ),
        by,
      );
      await env.welfare.decideCase(c.id, by, approve: true);
      await env.welfare.markPaid(
        c.id,
        by,
        method: PaymentMethod.cash,
        paidOn: DateTime(2026, 10, 7),
      );

      final (from, to) = ReportPeriod.month.rangeFor(DateTime(2026, 10, 14));
      final r = await env.finance.report(from, to, title: 'Monthly');
      expect(r.opening, 7000);
      expect(r.totalIncome, 20500);
      expect(r.totalExpense, 10000);
      expect(r.closing, 17500);
      expect(r.transactions, hasLength(4));
      expect(
        {for (final l in r.incomeByZone) l.label: l.amount},
        {'Zone 3': 20000, 'No member': 500},
      );
      expect(
        r.expenseByCategory.map((l) => l.label),
        containsAll(['Welfare payouts', 'Event costs']),
      );

      final org = await env.payments.org();
      final csv = String.fromCharCodes(reportCsv(r, org).skip(3));
      expect(csv.split('\r\n'), hasLength(5));
      final xlsx = ZipDecoder().decodeBytes(reportXlsx(r, org));
      expect(xlsx.findFile('xl/worksheets/sheet2.xml'), isNotNull);
      final pdf = await reportPdf(r, org);
      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    });

    test('week range starts on Monday', () {
      final (from, to) = ReportPeriod.week.rangeFor(DateTime(2026, 10, 14));
      expect(from, DateTime(2026, 10, 12));
      expect(to, DateTime(2026, 10, 19));
    });
  });

  test('csv quoting', () {
    expect(
      buildCsv([
        ['a,b', 'say "hi"', 3],
      ]),
      '"a,b","say ""hi""",3',
    );
  });

  group('backup', () {
    late Directory dir;
    late AppDatabase db;
    late BackupService backup;
    const key =
        'aa112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
    var now = DateTime(2026, 10, 14, 9);

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('jbf_bk');
      final file = File('${dir.path}/jbf.db');
      db = openDatabaseFile(file, hexKey: key);
      await db.select(db.zones).get();
      backup = BackupService(
        db: db,
        databaseKey: () async => key,
        databaseFile: file,
        workDir: dir,
        clock: () => now,
      );
    });
    tearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });

    test('password backup round trip onto a new phone', () async {
      await db.customStatement(
        "UPDATE org_settings SET name = 'Backup Test Org'",
      );
      await expectLater(
        backup.createBackup('123'),
        throwsA(isA<BackupException>()),
      );
      final Uint8List bytes = await backup.createBackup('s3cret!');
      await expectLater(
        backup.inspect(bytes, 'wrong-pass'),
        throwsA(isA<BackupException>()),
      );
      final info = await backup.inspect(bytes, 's3cret!');
      expect(info.orgName, 'Backup Test Org');
      await expectLater(
        backup.inspect(Uint8List.fromList(List.filled(2000, 7)), 'x'),
        throwsA(isA<BackupException>()),
      );

      // A different phone with its own key restores it.
      final dir2 = await Directory.systemTemp.createTemp('jbf_bk2');
      const key2 =
          'bb112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
      final file2 = File('${dir2.path}/jbf.db');
      final db2 = openDatabaseFile(file2, hexKey: key2);
      await db2.select(db2.zones).get();
      final other = BackupService(
        db: db2,
        databaseKey: () async => key2,
        databaseFile: file2,
        workDir: dir2,
      );
      final prepared = await other.prepareRestore(bytes, 's3cret!');
      await db2.close();
      await other.replaceDatabase(prepared);
      final reopened = openDatabaseFile(file2, hexKey: key2);
      final org = await reopened.select(reopened.orgSettings).getSingle();
      expect(org.name, 'Backup Test Org');
      expect(File('${file2.path}.before-restore').existsSync(), isTrue);
      await reopened.close();
      await dir2.delete(recursive: true);
    });

    test('daily automatic backups keep the last seven', () async {
      expect(await backup.autoBackupIfDue(), isNotNull);
      now = now.add(const Duration(hours: 2));
      expect(await backup.autoBackupIfDue(), isNull);
      for (var i = 0; i < 9; i++) {
        now = now.add(const Duration(days: 1));
        expect(await backup.autoBackupIfDue(), isNotNull);
      }
      final all = await backup.autoBackups();
      expect(all, hasLength(BackupService.keepAutoBackups));
      final prepared = await backup.prepareAutoRestore(all.first);
      expect(prepared.existsSync(), isTrue);
    });
  });
}
