import 'package:drift/drift.dart';

import '../core/ids.dart';
import '../core/org_config.dart';
import '../domain/permissions.dart';

part 'database.g.dart';

/// Columns every syncable table carries, so cloud sync and multi-device
/// batch imports can be added later without reshaping the data.
mixin SyncColumns on Table {
  TextColumn get id => text().clientDefault(newId)();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();
  TextColumn get createdBy => text().nullable()();
  TextColumn get deviceId => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Single-row organisation settings (id is always 1).
class OrgSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get name => text()();
  TextColumn get shortName => text()();
  TextColumn get memberIdPrefix => text()();
  IntColumn get nextMemberNo => integer().withDefault(const Constant(1))();
  TextColumn get currency => text().withDefault(const Constant('GHS'))();
  TextColumn get poweredBy => text().nullable()();
  TextColumn get logoPath => text().nullable()();

  /// Brand colours as ARGB integers, so each organisation can use its own.
  IntColumn get primaryColor =>
      integer().withDefault(const Constant(OrgDefaults.primaryColor))();
  IntColumn get accentColor =>
      integer().withDefault(const Constant(OrgDefaults.accentColor))();

  @override
  Set<Column> get primaryKey => {id};
}

class Zones extends Table with SyncColumns {
  IntColumn get code => integer().unique()();
  TextColumn get name => text()();
  TextColumn get nickname => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

enum MemberStatus { active, inactive, suspended, deceased }

@TableIndex(name: 'members_full_name', columns: {#fullName})
@TableIndex(name: 'members_phone', columns: {#phone})
class Members extends Table with SyncColumns {
  TextColumn get memberNo => text().unique()();
  TextColumn get fullName => text()();
  TextColumn get gender => text().nullable()();
  DateTimeColumn get dateOfBirth => dateTime().nullable()();
  TextColumn get nationality => text().nullable()();
  TextColumn get occupation => text().nullable()();
  TextColumn get maritalStatus => text().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get whatsapp => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get gpsAddress => text().nullable()();
  TextColumn get emergencyName => text().nullable()();
  TextColumn get emergencyPhone => text().nullable()();
  DateTimeColumn get dateJoined => dateTime()();
  TextColumn get status => textEnum<MemberStatus>().withDefault(
    Constant(MemberStatus.active.name),
  )();
  DateTimeColumn get statusDate => dateTime().nullable()();
  TextColumn get photoPath => text().nullable()();
}

@TableIndex(name: 'member_zones_member', columns: {#memberId})
class MemberZones extends Table with SyncColumns {
  TextColumn get memberId => text().references(Members, #id)();
  TextColumn get zoneId => text().references(Zones, #id)();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  DateTimeColumn get assignedOn =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  List<Set<Column>> get uniqueKeys => [
    {memberId, zoneId},
  ];
}

class Roles extends Table with SyncColumns {
  TextColumn get key => text().unique()();
  TextColumn get name => text()();
  TextColumn get level => text()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
}

class RolePermissions extends Table {
  TextColumn get roleId => text().references(Roles, #id)();
  TextColumn get permission => text()();

  @override
  Set<Column> get primaryKey => {roleId, permission};
}

class Users extends Table with SyncColumns {
  TextColumn get username => text().unique()();
  TextColumn get displayName => text()();
  TextColumn get memberId => text().nullable().references(Members, #id)();
  TextColumn get roleId => text().references(Roles, #id)();
  TextColumn get passwordHash => text()();
  TextColumn get pinHash => text().nullable()();
  BoolColumn get biometricEnabled =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get failedAttempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get lockedUntil => dateTime().nullable()();
  DateTimeColumn get lastLoginAt => dateTime().nullable()();
}

/// Append-only audit trail. The app never edits or deletes these rows.
@TableIndex(name: 'audit_logs_at', columns: {#at})
class AuditLogs extends Table {
  TextColumn get id => text().clientDefault(newId)();
  TextColumn get userId => text().nullable()();
  TextColumn get username => text().nullable()();
  TextColumn get action => text()();
  TextColumn get entity => text().nullable()();
  TextColumn get entityId => text().nullable()();
  TextColumn get oldValue => text().nullable()();
  TextColumn get newValue => text().nullable()();
  DateTimeColumn get at => dateTime().clientDefault(() => DateTime.now())();
  TextColumn get deviceId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

const maxZonesTriggerMessage = 'A member cannot belong to more than 2 zones';

@DriftDatabase(
  tables: [
    OrgSettings,
    Zones,
    Members,
    MemberZones,
    Roles,
    RolePermissions,
    Users,
    AuditLogs,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createGuards();
      await _seed();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Database-level guards that back up the domain rules, so no code path
  /// (including future imports) can break them.
  Future<void> _createGuards() async {
    // Zone limit on insert.
    await customStatement('''
      CREATE TRIGGER member_zones_max_two_insert
      BEFORE INSERT ON member_zones
      WHEN NEW.deleted_at IS NULL AND (
        SELECT COUNT(*) FROM member_zones
        WHERE member_id = NEW.member_id AND deleted_at IS NULL
      ) >= 2
      BEGIN SELECT RAISE(ABORT, '$maxZonesTriggerMessage'); END
    ''');
    // Zone limit when a removed assignment is restored.
    await customStatement('''
      CREATE TRIGGER member_zones_max_two_restore
      BEFORE UPDATE OF deleted_at ON member_zones
      WHEN OLD.deleted_at IS NOT NULL AND NEW.deleted_at IS NULL AND (
        SELECT COUNT(*) FROM member_zones
        WHERE member_id = NEW.member_id AND deleted_at IS NULL
      ) >= 2
      BEGIN SELECT RAISE(ABORT, '$maxZonesTriggerMessage'); END
    ''');
    // The audit trail is append-only.
    await customStatement('''
      CREATE TRIGGER audit_logs_no_update BEFORE UPDATE ON audit_logs
      BEGIN SELECT RAISE(ABORT, 'Audit logs cannot be changed'); END
    ''');
    await customStatement('''
      CREATE TRIGGER audit_logs_no_delete BEFORE DELETE ON audit_logs
      BEGIN SELECT RAISE(ABORT, 'Audit logs cannot be deleted'); END
    ''');
  }

  Future<void> _seed() async {
    await into(orgSettings).insert(
      OrgSettingsCompanion.insert(
        name: OrgDefaults.name,
        shortName: OrgDefaults.shortName,
        memberIdPrefix: OrgDefaults.memberIdPrefix,
        currency: const Value(OrgDefaults.currency),
        poweredBy: const Value(OrgDefaults.poweredBy),
      ),
    );
    await batch((b) {
      for (final (code, name, nickname, active) in OrgDefaults.zones) {
        b.insert(
          zones,
          ZonesCompanion.insert(
            code: code,
            name: name,
            nickname: Value(nickname),
            isActive: Value(active),
            sortOrder: Value(code),
          ),
        );
      }
    });
    for (final seed in defaultRoles) {
      final role = await into(roles).insertReturning(
        RolesCompanion.insert(
          key: seed.key,
          name: seed.name,
          level: seed.level,
          isSystem: Value(seed.key == 'super_admin'),
        ),
      );
      await batch((b) {
        b.insertAll(rolePermissions, [
          for (final p in seed.permissions)
            RolePermissionsCompanion.insert(roleId: role.id, permission: p),
        ]);
      });
    }
  }
}
