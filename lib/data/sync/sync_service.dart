import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/cloud_config.dart';
import '../database.dart';
import '../secure_store.dart';
import 'sync_api.dart';
import 'sync_schema.dart';

/// Where this phone keeps its cloud identity. It must stay with the phone
/// (not in the database), so a backup restored on another phone does not
/// pretend to be this one.
abstract interface class SyncPrefs {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

class SecureSyncPrefs implements SyncPrefs {
  SecureSyncPrefs(this._store);
  final SecureStore _store;
  @override
  Future<String?> read(String key) => _store.pref(key);
  @override
  Future<void> write(String key, String? value) => _store.setPref(key, value);
}

class MemorySyncPrefs implements SyncPrefs {
  final _values = <String, String>{};
  @override
  Future<String?> read(String key) async => _values[key];
  @override
  Future<void> write(String key, String? value) async =>
      value == null ? _values.remove(key) : _values[key] = value;
}

/// This phone's membership of a cloud organisation.
class SyncCredentials extends Equatable {
  const SyncCredentials({
    required this.token,
    required this.deviceId,
    required this.orgId,
    required this.orgName,
    required this.deviceName,
    required this.isAdmin,
    this.series,
  });

  final String token;
  final String deviceId;
  final String orgId;
  final String orgName;
  final String deviceName;

  /// Main phones can add and remove phones.
  final bool isAdmin;
  final String? series;

  Map<String, Object?> toJson() => {
    'token': token,
    'device_id': deviceId,
    'org_id': orgId,
    'org_name': orgName,
    'device_name': deviceName,
    'is_admin': isAdmin,
    'series': series,
  };

  factory SyncCredentials.fromJson(Map<String, Object?> j) => SyncCredentials(
    token: j['token']! as String,
    deviceId: j['device_id']! as String,
    orgId: j['org_id']! as String,
    orgName: j['org_name']! as String,
    deviceName: j['device_name']! as String,
    isAdmin: j['is_admin']! as bool,
    series: j['series'] as String?,
  );

  @override
  List<Object?> get props => [token, deviceId, orgId, isAdmin, series];
}

class SyncStatus extends Equatable {
  const SyncStatus({
    this.loaded = false,
    this.credentials,
    this.busy = false,
    this.lastSyncAt,
    this.pending = 0,
    this.issues = 0,
    this.error,
    this.offline = false,
  });

  final bool loaded;

  /// Null when this phone is not set up for cloud sync.
  final SyncCredentials? credentials;
  final bool busy;
  final DateTime? lastSyncAt;

  /// Changes on this phone waiting to be uploaded.
  final int pending;

  /// Records from other phones that could not be saved here.
  final int issues;
  final String? error;
  final bool offline;

  bool get enabled => credentials != null;

  SyncStatus copyWith({
    bool? loaded,
    SyncCredentials? Function()? credentials,
    bool? busy,
    DateTime? lastSyncAt,
    int? pending,
    int? issues,
    String? Function()? error,
    bool? offline,
  }) => SyncStatus(
    loaded: loaded ?? this.loaded,
    credentials: credentials != null ? credentials() : this.credentials,
    busy: busy ?? this.busy,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    pending: pending ?? this.pending,
    issues: issues ?? this.issues,
    error: error != null ? error() : this.error,
    offline: offline ?? this.offline,
  );

  @override
  List<Object?> get props => [
    loaded,
    credentials,
    busy,
    lastSyncAt,
    pending,
    issues,
    error,
    offline,
  ];
}

/// What joining did, for the message shown afterwards.
enum JoinOutcome {
  /// The organisation was empty: this phone's records started it.
  founded,

  /// A new phone received the organisation's records.
  received,

  /// A phone with records (e.g. a restored backup) was merged in.
  merged,
}

class SyncIssue {
  const SyncIssue(this.table, this.key, this.message, this.at);
  final String table;
  final String key;
  final String message;
  final DateTime at;
}

/// Keeps this phone's database in step with the other phones of the
/// organisation through the cloud. The phone always works offline; changes
/// are recorded locally and exchanged whenever there is a connection.
///
/// Conflicts: the most recent change to a record wins, except that money
/// records keep their original amounts and welfare cases only move forward
/// (enforced in the cloud as well as here).
class SyncService extends Cubit<SyncStatus> {
  SyncService(this._db, this._api, this._prefs) : super(const SyncStatus());

  final AppDatabase _db;
  final SyncApi _api;

  /// The cloud functions, also used for member statements.
  SyncApi get api => _api;
  final SyncPrefs _prefs;
  Timer? _timer;
  Future<void>? _running;

  static const _credentialsKey = 'cloud_sync';
  static const _pushBatch = 200;
  static final _epoch = DateTime.utc(2000);

  SyncCredentials? get credentials => state.credentials;

  /// Reads this phone's cloud identity and counts.
  Future<void> load() async {
    final raw = await _prefs.read(_credentialsKey);
    SyncCredentials? creds;
    if (raw != null) {
      creds = SyncCredentials.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
      // A backup from another phone or organisation was restored here.
      if (await _stateValue('org_id') != creds.orgId) {
        await _resetState(creds.orgId);
        await _setEnabled(true);
        await enqueueAll();
      }
    }
    final last = await _stateValue('last_sync_at');
    emit(
      state.copyWith(
        loaded: true,
        credentials: () => creds,
        lastSyncAt: last == null ? null : DateTime.tryParse(last),
        pending: await _pendingCount(),
        issues: await _issueCount(),
      ),
    );
  }

  /// Updates the counts of waiting changes and issues.
  Future<void> refresh() async => emit(
    state.copyWith(pending: await _pendingCount(), issues: await _issueCount()),
  );

  /// Joins the organisation with a one-time code from its main phone.
  ///
  /// When the organisation has no records yet, this phone's records start
  /// it. A new phone with no users receives all records. A phone that
  /// already has records must have started from this organisation's data
  /// (for example a restored backup of the main phone).
  Future<JoinOutcome> join({
    required String code,
    required String deviceName,
    String? series,
  }) async {
    var cleanSeries = series?.trim().toUpperCase();
    if (cleanSeries != null && cleanSeries.isEmpty) cleanSeries = null;
    final e = await _api.enroll(
      code.trim().toUpperCase(),
      deviceName.trim(),
      series: cleanSeries,
    );
    return _joined(e, deviceName.trim(), cleanSeries);
  }

  /// Joins by signing in with an officer's own app username and password
  /// (checked in the cloud against the organisation's users). The cloud
  /// gives the phone its number series.
  Future<JoinOutcome> signIn({
    required String org,
    required String username,
    required String password,
    String? deviceName,
  }) async {
    final name = (deviceName ?? '').trim().isEmpty
        ? "${username.trim()}'s phone"
        : deviceName!.trim();
    final e = await _api.signIn(org.trim(), username.trim(), password, name);
    return _joined(e, name, e.series);
  }

  Future<JoinOutcome> _joined(
    Enrollment e,
    String deviceName,
    String? series,
  ) async {
    final creds = SyncCredentials(
      token: e.token,
      deviceId: e.deviceId,
      orgId: e.orgId,
      orgName: e.orgName,
      deviceName: deviceName,
      isAdmin: e.isAdmin,
      series: series,
    );
    final hasUsers =
        (await _db.customSelect('SELECT 1 FROM users LIMIT 1').get())
            .isNotEmpty;
    final JoinOutcome outcome;
    if (e.records == 0) {
      outcome = JoinOutcome.founded;
      await _resetState(e.orgId);
      await enqueueAll();
    } else if (!hasUsers) {
      outcome = JoinOutcome.received;
      final rows = await _pullEverything(e.token);
      await _resetState(e.orgId);
      await _removeStarterRecords();
      await _applyRows(rows.$1, lastSeq: rows.$2);
    } else {
      outcome = JoinOutcome.merged;
      final rows = await _pullEverything(e.token);
      final clash = await _clashingZones(rows.$1);
      if (clash != null) {
        throw SyncException(
          'This phone has its own records that did not come from '
          '${e.orgName}\'s main phone ($clash). It was not joined. Use a new '
          'phone, or restore a backup of the main phone first.',
        );
      }
      await _resetState(e.orgId);
      await enqueueAll();
      await _applyRows(rows.$1, lastSeq: rows.$2);
    }
    await (_db.update(
      _db.orgSettings,
    )).write(OrgSettingsCompanion(deviceSeries: Value(creds.series)));
    await _setEnabled(true);
    await _prefs.write(_credentialsKey, jsonEncode(creds.toJson()));
    emit(state.copyWith(credentials: () => creds, error: () => null));
    await syncNow();
    return outcome;
  }

  /// Stops syncing on this phone. Its records stay; other phones keep
  /// theirs.
  Future<void> leave() async {
    _timer?.cancel();
    await _prefs.write(_credentialsKey, null);
    await _setEnabled(false);
    await _db.customStatement('DELETE FROM sync_outbox');
    await _db.customStatement('DELETE FROM sync_state');
    emit(SyncStatus(loaded: true, pending: 0, issues: await _issueCount()));
  }

  /// Exchanges changes with the cloud now. Safe to call often: calls made
  /// while a sync is running wait for it.
  Future<void> syncNow() => _running ??= _sync().whenComplete(() {
    _running = null;
  });

  Future<void> _sync() async {
    final creds = state.credentials;
    if (creds == null) return;
    emit(state.copyWith(busy: true));
    try {
      await _pullAll(creds.token);
      await _pushAll(creds.token);
      final now = DateTime.now();
      await _setStateValue('last_sync_at', now.toIso8601String());
      emit(
        state.copyWith(
          busy: false,
          lastSyncAt: now,
          error: () => null,
          offline: false,
          pending: await _pendingCount(),
          issues: await _issueCount(),
        ),
      );
    } on SyncException catch (e) {
      emit(
        state.copyWith(
          busy: false,
          error: () => e.message,
          offline: e.offline,
          pending: await _pendingCount(),
          issues: await _issueCount(),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          busy: false,
          error: () => 'Sync stopped: $e',
          offline: false,
          pending: await _pendingCount(),
        ),
      );
    }
  }

  /// Syncs now and then every few minutes while the app is open.
  void startAuto() {
    _timer?.cancel();
    _timer = Timer.periodic(CloudConfig.autoSyncEvery, (_) => syncNow());
    syncNow().ignore();
  }

  void stopAuto() => _timer?.cancel();

  Future<String> createCode({bool admin = false}) =>
      _api.createCode(_token, admin: admin);

  Future<List<CloudDevice>> devices() => _api.devices(_token);

  Future<void> removeDevice(String deviceId) => _api.revoke(_token, deviceId);

  Future<List<SyncIssue>> issues() async => [
    for (final r
        in await _db
            .customSelect(
              'SELECT * FROM sync_issues ORDER BY id DESC LIMIT 100',
            )
            .get())
      SyncIssue(
        r.read<String>('tbl'),
        r.read<String>('row_key'),
        r.read<String>('message'),
        DateTime.parse(r.read<String>('at')),
      ),
  ];

  Future<void> clearIssues() async {
    await _db.customStatement('DELETE FROM sync_issues');
    emit(state.copyWith(issues: 0));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }

  String get _token {
    final c = state.credentials;
    if (c == null) throw SyncException('This phone is not set up for sync.');
    return c.token;
  }

  // ---- Local bookkeeping ----

  Future<String?> _stateValue(String k) async =>
      (await _db
              .customSelect(
                'SELECT v FROM sync_state WHERE k = ?',
                variables: [Variable.withString(k)],
              )
              .getSingleOrNull())
          ?.read<String?>('v');

  Future<void> _setStateValue(String k, String v) => _db.customStatement(
    'INSERT INTO sync_state (k, v) VALUES (?, ?) '
    'ON CONFLICT (k) DO UPDATE SET v = excluded.v',
    [k, v],
  );

  Future<void> _resetState(String orgId) async {
    await _db.customStatement('DELETE FROM sync_state');
    await _setStateValue('org_id', orgId);
    await _setStateValue('last_seq', '0');
  }

  Future<void> _setEnabled(bool on) => _db.customStatement(
    'UPDATE sync_flags SET enabled = ?, applying = 0 WHERE id = 1',
    [on ? 1 : 0],
  );

  Future<int> _pendingCount() async =>
      (await _db
              .customSelect('SELECT count(*) AS n FROM sync_outbox')
              .getSingle())
          .read<int>('n');

  Future<int> _issueCount() async =>
      (await _db
              .customSelect('SELECT count(*) AS n FROM sync_issues')
              .getSingle())
          .read<int>('n');

  /// Queues every shared record on this phone for upload.
  Future<void> enqueueAll() async {
    await _db.transaction(() async {
      for (final t in syncTables) {
        await _db.customStatement(
          'INSERT INTO sync_outbox (tbl, row_key, ver) '
          "SELECT '${t.name}', ${t.keyExpr(t.name)}, 1 FROM ${t.name} "
          'WHERE true ON CONFLICT (tbl, row_key) DO UPDATE SET ver = ver + 1',
        );
      }
    });
  }

  /// A new phone's starter lists (zones, roles, contribution types...) are
  /// replaced by the organisation's own.
  Future<void> _removeStarterRecords() async {
    await _withoutForeignKeys(() async {
      for (final t in const [
        'role_permissions',
        'roles',
        'zones',
        'contribution_types',
        'welfare_case_types',
        'expense_categories',
        'executive_positions',
      ]) {
        await _db.customStatement('DELETE FROM $t');
      }
    });
  }

  Future<String?> _clashingZones(List<SyncRow> rows) async {
    final local = {
      for (final r
          in await _db.customSelect('SELECT id, code FROM zones').get())
        r.read<int>('code'): r.read<String>('id'),
    };
    for (final r in rows.where((r) => r.table == 'zones')) {
      final code = (r.data['code'] as num?)?.toInt();
      final id = local[code];
      if (id != null && id != r.key) return 'zone $code';
    }
    return null;
  }

  // ---- Download ----

  Future<(List<SyncRow>, int)> _pullEverything(String token) async {
    final rows = <SyncRow>[];
    var since = 0;
    while (true) {
      final page = await _api.pull(token, since, max: 2000);
      rows.addAll(page.rows);
      since = page.lastSeq;
      if (!page.more) return (rows, since);
    }
  }

  Future<void> _pullAll(String token) async {
    var since = int.tryParse(await _stateValue('last_seq') ?? '') ?? 0;
    while (true) {
      final page = await _api.pull(token, since);
      await _applyRows(page.rows, lastSeq: page.lastSeq);
      since = page.lastSeq;
      if (!page.more) return;
    }
  }

  /// Foreign keys are switched off while applying: a page can hold a
  /// payment before the member it belongs to.
  Future<T> _withoutForeignKeys<T>(Future<T> Function() action) async {
    await _db.customStatement('PRAGMA foreign_keys = OFF');
    try {
      return await action();
    } finally {
      await _db.customStatement('PRAGMA foreign_keys = ON');
    }
  }

  Future<void> _applyRows(List<SyncRow> rows, {required int lastSeq}) async {
    final changed = <String>{};
    await _withoutForeignKeys(() async {
      try {
        await _db.transaction(() async {
          await _db.customStatement(
            'UPDATE sync_flags SET applying = 1 WHERE id = 1',
          );
          for (final row in rows) {
            try {
              if (await _applyRow(row)) changed.add(row.table);
            } catch (e) {
              await _recordIssue(row, e);
            }
          }
          await _setStateValue('last_seq', '$lastSeq');
          await _db.customStatement(
            'UPDATE sync_flags SET applying = 0 WHERE id = 1',
          );
        });
      } finally {
        await _db.customStatement(
          'UPDATE sync_flags SET applying = 0 WHERE id = 1',
        );
      }
    });
    if (changed.isNotEmpty) {
      _db.markTablesUpdated(
        _db.allTables.where((t) => changed.contains(t.actualTableName)),
      );
    }
  }

  final _columnCache = <String, List<String>>{};

  Future<List<String>> _columns(String table) async => _columnCache[table] ??= [
    for (final r in await _db.customSelect('PRAGMA table_info($table)').get())
      r.read<String>('name'),
  ];

  static Object? _sqlValue(Object? v) => switch (v) {
    true => 1,
    false => 0,
    Map() || List() => jsonEncode(v),
    _ => v,
  };

  /// Saves one record from another phone. Returns false when this phone's
  /// copy is newer and was kept.
  Future<bool> _applyRow(SyncRow row) async {
    final spec = syncTablesByName[row.table];
    if (spec == null) {
      throw SyncException(
        'Made by a newer version of the app. Update this phone.',
      );
    }
    final keyParts = row.key.split(':');
    if (keyParts.length != spec.keyColumns.length) {
      throw SyncException('Damaged record key.');
    }
    final where = spec.keyColumns.map((c) => '$c = ?').join(' AND ');
    final cols = [
      for (final c in await _columns(spec.name))
        if (spec.shares(c) && row.data.containsKey(c)) c,
    ];
    final values = [for (final c in cols) _sqlValue(row.data[c])];

    if (spec.insertOnly) {
      await _db.customStatement(
        'INSERT OR IGNORE INTO ${spec.name} (${cols.join(', ')}) '
        'VALUES (${List.filled(cols.length, '?').join(', ')})',
        values,
      );
    } else {
      final local = await _db
          .customSelect(
            'SELECT ${spec.stamp} AS s FROM ${spec.name} WHERE $where',
            variables: [for (final k in keyParts) Variable.withString(k)],
          )
          .getSingleOrNull();
      final localStamp = parseStamp(local?.read<String?>('s'));
      if (localStamp != null && localStamp.isAfter(row.updatedAt)) {
        return false;
      }
      if (spec.name == 'org_settings') {
        final set = cols.where((c) => c != 'id').toList();
        await _db.customStatement(
          'UPDATE org_settings SET ${set.map((c) => '$c = ?').join(', ')} '
          'WHERE id = 1',
          [for (final c in set) _sqlValue(row.data[c])],
        );
      } else {
        final update = cols
            .where((c) => !spec.keyColumns.contains(c) && c != 'id')
            .map((c) => '$c = excluded.$c')
            .join(', ');
        await _db.customStatement(
          'INSERT INTO ${spec.name} (${cols.join(', ')}) '
          'VALUES (${List.filled(cols.length, '?').join(', ')}) '
          'ON CONFLICT (${spec.keyColumns.join(', ')}) DO UPDATE SET $update',
          values,
        );
      }
    }
    // This phone now has the cloud's version; nothing left to upload.
    await _db.customStatement(
      'DELETE FROM sync_outbox WHERE tbl = ? AND row_key = ?',
      [row.table, row.key],
    );
    return true;
  }

  Future<void> _recordIssue(SyncRow row, Object error) async {
    var message = error is SyncException ? error.message : '$error';
    if (message.length > 300) message = message.substring(0, 300);
    await _db.customStatement(
      'INSERT INTO sync_issues (tbl, row_key, message, at) VALUES (?, ?, ?, ?)',
      [row.table, row.key, message, DateTime.now().toIso8601String()],
    );
    await _db.customStatement(
      'DELETE FROM sync_issues WHERE id NOT IN '
      '(SELECT id FROM sync_issues ORDER BY id DESC LIMIT 200)',
    );
  }

  // ---- Upload ----

  Future<void> _pushAll(String token) async {
    while (true) {
      final queued = await _db
          .customSelect(
            'SELECT tbl, row_key, ver FROM sync_outbox ORDER BY rowid LIMIT ?',
            variables: [Variable.withInt(_pushBatch)],
          )
          .get();
      if (queued.isEmpty) return;
      final rows = <SyncRow>[];
      for (final q in queued) {
        final row = await _localRow(
          q.read<String>('tbl'),
          q.read<String>('row_key'),
        );
        if (row != null) rows.add(row);
      }
      if (rows.isNotEmpty) await _api.push(token, rows);
      await _db.transaction(() async {
        for (final q in queued) {
          await _db.customStatement(
            'DELETE FROM sync_outbox WHERE tbl = ? AND row_key = ? AND ver = ?',
            [
              q.read<String>('tbl'),
              q.read<String>('row_key'),
              q.read<int>('ver'),
            ],
          );
        }
      });
      emit(state.copyWith(pending: await _pendingCount()));
      if (queued.length < _pushBatch) return;
    }
  }

  Future<SyncRow?> _localRow(String table, String key) async {
    final spec = syncTablesByName[table];
    if (spec == null) return null;
    final parts = key.split(':');
    if (parts.length != spec.keyColumns.length) return null;
    final r = await _db
        .customSelect(
          'SELECT * FROM $table WHERE '
          '${spec.keyColumns.map((c) => '$c = ?').join(' AND ')}',
          variables: [for (final p in parts) Variable.withString(p)],
        )
        .getSingleOrNull();
    if (r == null) return null;
    final data = {
      for (final e in r.data.entries)
        if (spec.shares(e.key)) e.key: e.value,
    };
    final stamp = spec.stamp == null
        ? null
        : parseStamp(r.data[spec.stamp] as String?);
    return SyncRow(table, key, stamp ?? _epoch, data);
  }
}

/// Reads a date as Drift stores it (`2026-10-15T07:07:55.484083 +00:00`).
DateTime? parseStamp(String? s) {
  if (s == null) return null;
  return DateTime.tryParse(s.replaceFirst(RegExp(r' (?=[+-]\d\d:?\d\d$)'), ''));
}
