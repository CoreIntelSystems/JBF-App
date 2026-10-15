import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../domain/password_hasher.dart';
import 'connection.dart';
import 'database.dart';
import 'repositories/actor.dart';
import 'repositories/audit_repository.dart';

class BatchException implements Exception {
  BatchException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BatchSummary {
  const BatchSummary({
    required this.fromDevice,
    required this.exportedAt,
    required this.count,
    required this.total,
  });
  final String fromDevice;
  final DateTime exportedAt;
  final int count;
  final int total;
}

class ImportResult {
  const ImportResult({
    required this.added,
    required this.alreadyHad,
    required this.voidsApplied,
    required this.skipped,
  });
  final int added;
  final int alreadyHad;
  final int voidsApplied;

  /// Reasons for rows that could not be imported.
  final List<String> skipped;
}

/// Moves payments collected on a field phone (e.g. a zone treasurer's) to
/// the main phone without internet.
///
/// The field phone is set up by restoring a backup of the main phone and
/// giving it its own receipt prefix, so receipt numbers never clash. It then
/// exports the payments it recorded as a password-protected `.jbfc` file,
/// sent by WhatsApp or Bluetooth. Importing ignores payments already
/// present, so sending the same batch twice is harmless.
class CollectionBatches {
  CollectionBatches(this._db, this._audit, {Directory? workDir})
    : workDir = workDir ?? Directory.systemTemp;

  final AppDatabase _db;
  final AuditRepository _audit;
  final Directory workDir;

  static const _magic = 'JBFBATCH1\n';
  static const _saltLength = 16;

  static String _hex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

  File _temp(String name) => File(
    p.join(workDir.path, 'tmp-${DateTime.now().microsecondsSinceEpoch}-$name'),
  );

  /// Payments recorded on [deviceId], optionally only since [since].
  Future<List<Payment>> paymentsFrom(String deviceId, {DateTime? since}) {
    final q = _db.select(_db.payments)
      ..where((t) => t.deviceId.equals(deviceId))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    if (since != null) {
      // Include later voids of earlier payments too.
      q.where(
        (t) =>
            t.createdAt.isBiggerOrEqualValue(since) |
            t.updatedAt.isBiggerOrEqualValue(since),
      );
    }
    return q.get();
  }

  Future<Uint8List> export({
    required String deviceId,
    required String deviceName,
    required String password,
    DateTime? since,
  }) async {
    if (password.length < 6) {
      throw BatchException('Use a password of at least 6 characters.');
    }
    final rows = await paymentsFrom(deviceId, since: since);
    if (rows.isEmpty) throw BatchException('No payments to send.');
    final r = Random.secure();
    final salt = List<int>.generate(_saltLength, (_) => r.nextInt(256));
    final key = _hex(await PasswordHasher.deriveKey(password, salt));
    final tmp = _temp('batch.db');
    final d = sqlite3.open(tmp.path);
    try {
      applyEncryptionKey(d, key);
      d.execute('CREATE TABLE batch (meta TEXT NOT NULL, rows TEXT NOT NULL)');
      d.execute('INSERT INTO batch VALUES (?, ?)', [
        jsonEncode({
          'device': deviceName,
          'deviceId': deviceId,
          'exportedAt': DateTime.now().toIso8601String(),
        }),
        jsonEncode([for (final p in rows) p.toJson()]),
      ]);
    } finally {
      d.close();
    }
    try {
      return Uint8List.fromList([
        ...ascii.encode(_magic),
        ...salt,
        ...await tmp.readAsBytes(),
      ]);
    } finally {
      tmp.deleteSync();
    }
  }

  Future<(BatchSummary, List<Payment>)> read(
    Uint8List bytes,
    String password,
  ) async {
    final head = ascii.encode(_magic);
    if (bytes.length < head.length + _saltLength + 512 ||
        !List.generate(
          head.length,
          (i) => bytes[i] == head[i],
        ).every((x) => x)) {
      throw BatchException('This is not a collection batch file.');
    }
    final salt = bytes.sublist(head.length, head.length + _saltLength);
    final key = _hex(await PasswordHasher.deriveKey(password, salt));
    final tmp = _temp('batch-in.db');
    await tmp.writeAsBytes(bytes.sublist(head.length + _saltLength));
    final d = sqlite3.open(tmp.path);
    try {
      try {
        applyEncryptionKey(d, key);
      } on SqliteException {
        throw BatchException('Wrong password.');
      }
      final row = d.select('SELECT meta, rows FROM batch').first;
      final meta = jsonDecode(row['meta'] as String) as Map<String, dynamic>;
      final payments = [
        for (final j in jsonDecode(row['rows'] as String) as List)
          Payment.fromJson(j as Map<String, dynamic>),
      ];
      return (
        BatchSummary(
          fromDevice: meta['device'] as String? ?? '',
          exportedAt: DateTime.parse(meta['exportedAt'] as String),
          count: payments.length,
          total: payments
              .where((p) => p.status == PaymentStatus.valid)
              .fold(0, (a, p) => a + p.amount),
        ),
        payments,
      );
    } finally {
      d.close();
      tmp.deleteSync();
    }
  }

  Future<ImportResult> import(
    List<Payment> incoming,
    Actor actor, {
    required String fromDevice,
  }) => _db.transaction(() async {
    var added = 0, had = 0, voids = 0;
    final skipped = <String>[];
    for (final p in incoming) {
      final existing = await (_db.select(
        _db.payments,
      )..where((t) => t.id.equals(p.id))).getSingleOrNull();
      if (existing != null) {
        if (existing.status == PaymentStatus.valid &&
            p.status == PaymentStatus.voided) {
          await (_db.update(
            _db.payments,
          )..where((t) => t.id.equals(p.id))).write(
            PaymentsCompanion(
              status: const Value(PaymentStatus.voided),
              voidReason: Value(p.voidReason),
              voidedBy: Value(p.voidedBy),
              voidedAt: Value(p.voidedAt),
              updatedAt: Value(p.updatedAt),
            ),
          );
          voids++;
        } else {
          had++;
        }
        continue;
      }
      final clash = await (_db.select(
        _db.payments,
      )..where((t) => t.receiptNo.equals(p.receiptNo))).getSingleOrNull();
      if (clash != null) {
        skipped.add(
          '${p.receiptNo}: this receipt number is already used here. Give '
          'the field phone its own receipt prefix.',
        );
        continue;
      }
      if (p.memberId != null) {
        final m = await (_db.select(
          _db.members,
        )..where((t) => t.id.equals(p.memberId!))).getSingleOrNull();
        if (m == null) {
          skipped.add('${p.receiptNo}: the member is not on this phone.');
          continue;
        }
      }
      final type = await (_db.select(
        _db.contributionTypes,
      )..where((t) => t.id.equals(p.contributionTypeId))).getSingleOrNull();
      if (type == null) {
        skipped.add('${p.receiptNo}: unknown contribution type.');
        continue;
      }
      await _db.into(_db.payments).insert(p.toCompanion(false));
      added++;
    }
    await _audit.log(
      actor,
      'batch.import',
      entity: 'payments',
      newValue: {
        'from': fromDevice,
        'added': added,
        'alreadyHad': had,
        'voids': voids,
        'skipped': skipped.length,
      },
    );
    return ImportResult(
      added: added,
      alreadyHad: had,
      voidsApplied: voids,
      skipped: skipped,
    );
  });
}
