import 'dart:convert';

import 'package:drift/drift.dart';

import '../database.dart';
import 'actor.dart';

/// Writes and reads the append-only audit trail.
///
/// Callers write the audit row inside the same transaction as the change it
/// describes, so neither can exist without the other.
class AuditRepository {
  AuditRepository(this._db);

  final AppDatabase _db;

  Future<void> log(
    Actor actor,
    String action, {
    String? entity,
    String? entityId,
    Object? oldValue,
    Object? newValue,
  }) {
    return _db
        .into(_db.auditLogs)
        .insert(
          AuditLogsCompanion.insert(
            userId: Value(actor.userId),
            username: Value(actor.username),
            action: action,
            entity: Value(entity),
            entityId: Value(entityId),
            oldValue: Value(oldValue == null ? null : jsonEncode(oldValue)),
            newValue: Value(newValue == null ? null : jsonEncode(newValue)),
            deviceId: Value(actor.deviceId),
          ),
        );
  }

  Stream<List<AuditLog>> watchRecent({int limit = 200}) {
    return (_db.select(_db.auditLogs)
          ..orderBy([(t) => OrderingTerm.desc(t.at)])
          ..limit(limit))
        .watch();
  }
}
