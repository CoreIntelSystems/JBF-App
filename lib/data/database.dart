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

  /// Receipt numbers look like `RCP-2026-000045`.
  TextColumn get receiptPrefix => text().withDefault(const Constant('RCP'))();
  IntColumn get nextReceiptNo => integer().withDefault(const Constant(1))();

  /// Welfare case numbers look like `WEL-2026-0007`.
  IntColumn get nextWelfareCaseNo => integer().withDefault(const Constant(1))();

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

/// The six contribution categories from the JBF specification.
enum ContributionCategory {
  welfare('Welfare'),
  emergency('Emergency'),
  charity('Charity project'),
  executive('Executive council'),
  event('Event'),
  voluntary('Voluntary donation');

  const ContributionCategory(this.label);
  final String label;
}

enum ContributionFrequency {
  /// Owed every month from the member's join date: drives arrears.
  monthly('Monthly'),

  /// A single levy, e.g. a funeral contribution.
  oneOff('One-off'),

  /// Collected at an event, e.g. Silver Collection. No arrears.
  perEvent('Per event'),

  /// Any amount, any time, e.g. donations.
  open('Any time');

  const ContributionFrequency(this.label);
  final String label;
}

/// What members contribute towards. Amounts are configurable per
/// organisation; a null amount means "any amount".
class ContributionTypes extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get category => textEnum<ContributionCategory>()();
  TextColumn get frequency => textEnum<ContributionFrequency>()();
  IntColumn get amount => integer().nullable()();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// False for executive-only dues; those get arrears once executives are
  /// recorded (Phase 3).
  BoolColumn get appliesToAll => boolean().withDefault(const Constant(true))();
  TextColumn get notes => text().nullable()();
}

enum PaymentMethod {
  cash('Cash'),
  momo('Mobile money'),
  bank('Bank');

  const PaymentMethod(this.label);
  final String label;
}

enum PaymentStatus { valid, voided }

/// A money received. Never deleted or edited: a mistake is voided with a
/// reason, and the void is audited.
@TableIndex(name: 'payments_member', columns: {#memberId})
@TableIndex(name: 'payments_paid_on', columns: {#paidOn})
class Payments extends Table with SyncColumns {
  TextColumn get receiptNo => text().unique()();

  /// Null for anonymous donations.
  TextColumn get memberId => text().nullable().references(Members, #id)();
  TextColumn get contributionTypeId =>
      text().references(ContributionTypes, #id)();

  /// For monthly dues, the month paid for as `YYYY-MM`.
  TextColumn get period => text().nullable()();
  IntColumn get amount => integer()();
  TextColumn get method => textEnum<PaymentMethod>()();
  TextColumn get reference => text().nullable()();
  DateTimeColumn get paidOn => dateTime()();
  TextColumn get collectedBy => text().nullable()();
  TextColumn get collectorName => text()();
  TextColumn get remarks => text().nullable()();
  TextColumn get status => textEnum<PaymentStatus>().withDefault(
    Constant(PaymentStatus.valid.name),
  )();
  TextColumn get voidReason => text().nullable()();
  TextColumn get voidedBy => text().nullable()();
  DateTimeColumn get voidedAt => dateTime().nullable()();
}

/// Kinds of welfare support, each with a fixed benefit amount. The
/// Treasurer proposes the amount; the Welfare Chairman (or the General
/// Secretary standing in) approves it before it applies to new cases.
class WelfareCaseTypes extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();

  /// The approved amount in pesewas. Null until first approved, in which
  /// case each case states the amount requested.
  IntColumn get benefitAmount => integer().nullable()();
  TextColumn get benefitApprovedBy => text().nullable()();
  TextColumn get benefitApprovedByName => text().nullable()();
  DateTimeColumn get benefitApprovedAt => dateTime().nullable()();

  /// A change waiting for approval.
  IntColumn get proposedAmount => integer().nullable()();
  TextColumn get proposedBy => text().nullable()();
  TextColumn get proposedByName => text().nullable()();
  DateTimeColumn get proposedAt => dateTime().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

enum WelfareStatus {
  pending('Awaiting approval'),
  approved('Approved, not yet paid'),
  rejected('Rejected'),
  paid('Paid');

  const WelfareStatus(this.label);
  final String label;
}

/// A request for welfare support for a member. Moves pending -> approved
/// or rejected, then approved -> paid. Never deleted.
@TableIndex(name: 'welfare_cases_member', columns: {#memberId})
@TableIndex(name: 'welfare_cases_status', columns: {#status})
class WelfareCases extends Table with SyncColumns {
  TextColumn get caseNo => text().unique()();
  TextColumn get memberId => text().references(Members, #id)();
  TextColumn get caseTypeId => text().references(WelfareCaseTypes, #id)();

  /// Who the support is for when it is not the member, e.g. "Mother".
  TextColumn get beneficiary => text().nullable()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get occurredOn => dateTime()();
  IntColumn get amount => integer()();

  /// True when [amount] came from the case type's approved benefit.
  BoolColumn get amountIsFixed => boolean().withDefault(const Constant(true))();
  TextColumn get status => textEnum<WelfareStatus>().withDefault(
    Constant(WelfareStatus.pending.name),
  )();
  TextColumn get preparedByName => text()();

  TextColumn get decidedBy => text().nullable()();
  TextColumn get decidedByName => text().nullable()();

  /// The approver's role at the time, so a stand-in approval by the
  /// General Secretary is visible.
  TextColumn get decidedByRole => text().nullable()();
  DateTimeColumn get decidedAt => dateTime().nullable()();
  TextColumn get decisionNote => text().nullable()();

  DateTimeColumn get paidOn => dateTime().nullable()();
  TextColumn get payMethod => textEnum<PaymentMethod>().nullable()();
  TextColumn get payReference => text().nullable()();
  TextColumn get paidBy => text().nullable()();
  TextColumn get paidByName => text().nullable()();
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
    ContributionTypes,
    Payments,
    WelfareCaseTypes,
    WelfareCases,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createGuards();
      await _createPaymentGuards();
      await _seed();
      await _seedContributionTypes();
      await _createWelfareGuards();
      await _seedWelfareCaseTypes();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(orgSettings, orgSettings.receiptPrefix);
        await m.addColumn(orgSettings, orgSettings.nextReceiptNo);
        await m.createTable(contributionTypes);
        await m.createTable(payments);
        await m.createIndex(paymentsMember);
        await m.createIndex(paymentsPaidOn);
        await _createPaymentGuards();
        await _seedContributionTypes();
      }
      if (from < 3) {
        await m.addColumn(orgSettings, orgSettings.nextWelfareCaseNo);
        await m.createTable(welfareCaseTypes);
        await m.createTable(welfareCases);
        await m.createIndex(welfareCasesMember);
        await m.createIndex(welfareCasesStatus);
        await _createWelfareGuards();
        await _seedWelfareCaseTypes();
        await _grantNewPermissions({
          for (final r in defaultRoles)
            if (r.permissions.contains(Perm.welfarePay))
              r.key: {Perm.welfarePay},
        });
      }
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

  /// Payments can be voided but never deleted or have their money changed.
  Future<void> _createPaymentGuards() async {
    await customStatement('''
      CREATE TRIGGER payments_no_delete BEFORE DELETE ON payments
      BEGIN SELECT RAISE(ABORT, 'Payments cannot be deleted; void them'); END
    ''');
    await customStatement('''
      CREATE TRIGGER payments_no_edit BEFORE UPDATE ON payments
      WHEN NEW.amount IS NOT OLD.amount
        OR NEW.member_id IS NOT OLD.member_id
        OR NEW.contribution_type_id IS NOT OLD.contribution_type_id
        OR NEW.receipt_no IS NOT OLD.receipt_no
        OR NEW.period IS NOT OLD.period
        OR NEW.paid_on IS NOT OLD.paid_on
        OR (OLD.status = 'voided' AND NEW.status = 'valid')
      BEGIN SELECT RAISE(ABORT, 'Payments cannot be edited; void and re-enter'); END
    ''');
  }

  /// Welfare cases are never deleted, and only move forward:
  /// pending -> approved/rejected, approved -> paid. The amount is locked
  /// once a decision is made.
  Future<void> _createWelfareGuards() async {
    await customStatement('''
      CREATE TRIGGER welfare_cases_no_delete BEFORE DELETE ON welfare_cases
      BEGIN SELECT RAISE(ABORT, 'Welfare cases cannot be deleted'); END
    ''');
    await customStatement('''
      CREATE TRIGGER welfare_cases_flow BEFORE UPDATE ON welfare_cases
      WHEN (NEW.amount IS NOT OLD.amount AND OLD.status <> 'pending')
        OR NEW.member_id IS NOT OLD.member_id
        OR NEW.case_no IS NOT OLD.case_no
        OR NOT (
          NEW.status = OLD.status
          OR (OLD.status = 'pending' AND NEW.status IN ('approved', 'rejected'))
          OR (OLD.status = 'approved' AND NEW.status = 'paid')
        )
      BEGIN SELECT RAISE(ABORT, 'This welfare case can no longer be changed'); END
    ''');
  }

  Future<void> _seedWelfareCaseTypes() async {
    await batch((b) {
      var order = 0;
      for (final (name, description) in OrgDefaults.welfareCaseTypes) {
        b.insert(
          welfareCaseTypes,
          WelfareCaseTypesCompanion.insert(
            name: name,
            description: Value(description),
            sortOrder: Value(order++),
          ),
        );
      }
    });
  }

  /// Adds permissions introduced after a database was created to the
  /// matching seeded roles, leaving any customised roles otherwise intact.
  Future<void> _grantNewPermissions(Map<String, Set<String>> byRoleKey) async {
    for (final MapEntry(key: roleKey, value: perms) in byRoleKey.entries) {
      final role = await (select(
        roles,
      )..where((r) => r.key.equals(roleKey))).getSingleOrNull();
      if (role == null) continue;
      await batch((b) {
        b.insertAll(rolePermissions, [
          for (final p in perms)
            RolePermissionsCompanion.insert(roleId: role.id, permission: p),
        ], mode: InsertMode.insertOrIgnore);
      });
    }
  }

  Future<void> _seedContributionTypes() async {
    await batch((b) {
      for (final (name, cat, freq, notes) in OrgDefaults.contributionTypes) {
        b.insert(
          contributionTypes,
          ContributionTypesCompanion.insert(
            name: name,
            category: cat,
            frequency: freq,
            notes: Value(notes),
            appliesToAll: Value(cat != ContributionCategory.executive),
          ),
        );
      }
    });
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
