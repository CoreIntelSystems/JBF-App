/// Which local tables cloud sync shares between phones, and the triggers
/// that record local changes for upload.
library;

/// How one table is shared.
class SyncTable {
  const SyncTable(
    this.name, {
    this.keyColumns = const ['id'],
    this.stamp = 'updated_at',
    this.localOnly = const {},
    this.only,
    this.insertOnly = false,
  });

  final String name;

  /// Columns that identify a row on every phone. Joined with `:` to form
  /// the cloud key.
  final List<String> keyColumns;

  /// The column holding when the row last changed, or null when rows never
  /// change after they are added.
  final String? stamp;

  /// Columns that describe this phone only (login attempts, file paths).
  final Set<String> localOnly;

  /// When set, only these columns (plus the key) are shared.
  final Set<String>? only;

  /// Rows are added but never changed (audit trail, role permissions).
  final bool insertOnly;

  bool shares(String column) =>
      !localOnly.contains(column) &&
      (only == null ||
          only!.contains(column) ||
          keyColumns.contains(column) ||
          column == stamp);

  /// SQL expression for the cloud key of the row named [alias].
  String keyExpr([String alias = 'NEW']) =>
      keyColumns.map((c) => '$alias.$c').join(" || ':' || ");
}

/// Shared tables. Parents come before children.
const syncTables = <SyncTable>[
  SyncTable(
    'org_settings',
    // Counters, prefixes and the logo file stay with each phone.
    only: {
      'name',
      'short_name',
      'member_id_prefix',
      'currency',
      'powered_by',
      'primary_color',
      'accent_color',
    },
  ),
  SyncTable('zones'),
  SyncTable('members', localOnly: {'photo_path'}),
  SyncTable('member_zones'),
  SyncTable('roles'),
  SyncTable(
    'role_permissions',
    keyColumns: ['role_id', 'permission'],
    stamp: null,
    insertOnly: true,
  ),
  SyncTable(
    'users',
    localOnly: {
      'failed_attempts',
      'locked_until',
      'last_login_at',
      'biometric_enabled',
    },
  ),
  SyncTable('audit_logs', stamp: 'at', insertOnly: true),
  SyncTable('contribution_types'),
  SyncTable('payments'),
  SyncTable('welfare_case_types'),
  SyncTable('welfare_cases'),
  SyncTable('expense_categories'),
  SyncTable('expenses'),
  SyncTable('events'),
  SyncTable('meetings'),
  SyncTable('attendance_records', keyColumns: ['occasion_id', 'member_id']),
  SyncTable('executive_positions'),
  SyncTable('executives'),
];

final syncTablesByName = {for (final t in syncTables) t.name: t};

/// Same text form Drift uses for dates, in UTC.
const sqlNowStamp = "strftime('%Y-%m-%dT%H:%M:%f', 'now') || ' +00:00'";

/// True while cloud sync is on and the change came from this phone.
const _recording =
    '(SELECT enabled = 1 AND applying = 0 FROM sync_flags WHERE id = 1)';

/// Creates the bookkeeping tables. Safe to run more than once.
Future<void> createSyncTables(Future<void> Function(String sql) exec) async {
  // Rows changed on this phone and not yet uploaded.
  await exec('''
    CREATE TABLE IF NOT EXISTS sync_outbox (
      tbl TEXT NOT NULL,
      row_key TEXT NOT NULL,
      ver INTEGER NOT NULL DEFAULT 1,
      PRIMARY KEY (tbl, row_key)
    )
  ''');
  await exec('''
    CREATE TABLE IF NOT EXISTS sync_flags (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      enabled INTEGER NOT NULL DEFAULT 0,
      applying INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await exec('INSERT OR IGNORE INTO sync_flags (id) VALUES (1)');
  await exec('''
    CREATE TABLE IF NOT EXISTS sync_state (
      k TEXT PRIMARY KEY,
      v TEXT
    )
  ''');
  // Rows from other phones that could not be applied here.
  await exec('''
    CREATE TABLE IF NOT EXISTS sync_issues (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tbl TEXT NOT NULL,
      row_key TEXT NOT NULL,
      message TEXT NOT NULL,
      at TEXT NOT NULL
    )
  ''');
}

/// Records every local change in `sync_outbox`, and stamps rows changed
/// without a new `updated_at` so the newest edit wins on every phone.
Future<void> createSyncTriggers(
  Future<void> Function(String sql) exec,
  Future<List<String>> Function(String table) columnsOf,
) async {
  for (final t in syncTables) {
    final enqueue =
        "INSERT INTO sync_outbox (tbl, row_key, ver) "
        "VALUES ('${t.name}', ${t.keyExpr()}, 1) "
        'ON CONFLICT (tbl, row_key) DO UPDATE SET ver = ver + 1;';
    await exec('DROP TRIGGER IF EXISTS sync_${t.name}_ins');
    await exec('DROP TRIGGER IF EXISTS sync_${t.name}_upd');
    await exec('DROP TRIGGER IF EXISTS sync_${t.name}_stamp');
    await exec('''
      CREATE TRIGGER sync_${t.name}_ins AFTER INSERT ON ${t.name}
      WHEN $_recording
      BEGIN $enqueue END
    ''');
    if (t.insertOnly) continue;
    final shared = (await columnsOf(t.name)).where(t.shares).toList();
    final watched = shared.where((c) => c != t.stamp).join(', ');
    final of = t.localOnly.isEmpty && t.only == null ? '' : 'OF $watched ';
    await exec('''
      CREATE TRIGGER sync_${t.name}_upd AFTER UPDATE $of ON ${t.name}
      WHEN $_recording
      BEGIN $enqueue END
    ''');
    await exec('''
      CREATE TRIGGER sync_${t.name}_stamp AFTER UPDATE $of ON ${t.name}
      WHEN NEW.${t.stamp} IS OLD.${t.stamp} AND $_recording
      BEGIN
        UPDATE ${t.name} SET ${t.stamp} = $sqlNowStamp WHERE rowid = NEW.rowid;
      END
    ''');
  }
}
