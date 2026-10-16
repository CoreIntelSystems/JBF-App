import 'dart:io';
import 'dart:typed_data';

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
  final List<String> skipped;
}

/// Field-phone batch files are a phone feature; in the browser, payments
/// sync through the cloud instead. This stand-in lets shared code compile.
class CollectionBatches {
  CollectionBatches(this._db, this._audit, {Directory? workDir});

  // ignore: unused_field
  final AppDatabase _db;
  // ignore: unused_field
  final AuditRepository _audit;

  static BatchException get _no =>
      BatchException('Field phone files are used on the Android app.');

  Future<List<Payment>> paymentsFrom(
    String deviceId, {
    DateTime? since,
  }) async => const [];
  Future<Uint8List> export({
    required String deviceId,
    required String deviceName,
    required String password,
    DateTime? since,
  }) async => throw _no;
  Future<(BatchSummary, List<Payment>)> read(
    Uint8List bytes,
    String password,
  ) async => throw _no;
  Future<ImportResult> import(
    List<Payment> incoming,
    Actor actor, {
    required String fromDevice,
  }) async => throw _no;
}
