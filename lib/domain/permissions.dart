/// Permission keys checked by the app. Roles map to a set of these keys in
/// the `role_permissions` table, so each role can be customised later.
abstract final class Perm {
  static const dashboardView = 'dashboard.view';
  static const membersView = 'members.view';
  static const membersCreate = 'members.create';
  static const membersEdit = 'members.edit';
  static const membersChangeStatus = 'members.status';
  static const zonesManage = 'zones.manage';
  static const usersManage = 'users.manage';
  static const rolesManage = 'roles.manage';
  static const auditView = 'audit.view';
  static const settingsManage = 'settings.manage';

  // Declared now so roles are complete; the screens arrive in later phases.
  static const paymentsRecord = 'payments.record';
  static const paymentsVoid = 'payments.void';

  /// Set and confirm the monthly dues amount and frequency.
  static const duesManage = 'dues.manage';
  static const welfarePrepare = 'welfare.prepare';

  /// Set the fixed benefit amount for each welfare case type. Changes
  /// take effect once someone with [welfareApprove] approves them.
  static const welfareSetBenefits = 'welfare.set_benefits';

  /// Approve welfare cases and benefit amounts (Welfare Chairman, with the
  /// General Secretary standing in when the Chairman is away).
  static const welfareApprove = 'welfare.approve';

  /// Pay out approved welfare cases.
  static const welfarePay = 'welfare.pay';

  /// Record money spent. Voiding uses [paymentsVoid].
  static const expensesRecord = 'expenses.record';
  static const financeView = 'finance.view';
  static const reportsExport = 'reports.export';
  static const eventsManage = 'events.manage';
  static const electionsManage = 'elections.manage';
  static const backupManage = 'backup.manage';

  static const all = <String>[
    dashboardView,
    membersView,
    membersCreate,
    membersEdit,
    membersChangeStatus,
    zonesManage,
    usersManage,
    rolesManage,
    auditView,
    settingsManage,
    paymentsRecord,
    paymentsVoid,
    duesManage,
    welfarePrepare,
    welfareSetBenefits,
    welfareApprove,
    welfarePay,
    expensesRecord,
    financeView,
    reportsExport,
    eventsManage,
    electionsManage,
    backupManage,
  ];
}

/// A role seeded on first run.
class RoleSeed {
  const RoleSeed(this.key, this.name, this.level, this.permissions);

  final String key;
  final String name;

  /// board, national, welfare, zone, oversight or member.
  final String level;
  final Set<String> permissions;
}

const _memberRead = {Perm.dashboardView, Perm.membersView};
const _memberWrite = {..._memberRead, Perm.membersCreate, Perm.membersEdit};

/// Default roles from the JBF specification. Zone roles will be limited to
/// their own zone(s) once zone-scoped access lands (Phase 3).
final defaultRoles = <RoleSeed>[
  RoleSeed('super_admin', 'Super Administrator', 'system', Perm.all.toSet()),
  RoleSeed('founder', 'Founder', 'board', {
    ..._memberRead,
    Perm.duesManage,
    Perm.financeView,
    Perm.auditView,
    Perm.reportsExport,
  }),
  RoleSeed('director', 'Director', 'board', {
    ..._memberRead,
    Perm.financeView,
    Perm.reportsExport,
  }),
  RoleSeed('general_secretary', 'General Secretary', 'national', {
    ..._memberWrite,
    Perm.membersChangeStatus,
    Perm.zonesManage,
    Perm.duesManage,
    Perm.welfarePrepare,
    Perm.welfareApprove,
    Perm.eventsManage,
    Perm.reportsExport,
    Perm.backupManage,
  }),
  RoleSeed('organizer', 'Organizer', 'national', {
    ..._memberWrite,
    Perm.eventsManage,
  }),
  RoleSeed('treasurer', 'Treasurer', 'national', {
    ..._memberRead,
    Perm.paymentsRecord,
    Perm.paymentsVoid,
    Perm.duesManage,
    Perm.welfareSetBenefits,
    Perm.welfarePay,
    Perm.expensesRecord,
    Perm.financeView,
    Perm.reportsExport,
    Perm.backupManage,
  }),
  RoleSeed('welfare_chairman', 'Welfare Chairman', 'welfare', {
    ..._memberRead,
    Perm.welfarePrepare,
    Perm.welfareApprove,
  }),
  RoleSeed('welfare_member', 'Welfare Team Member', 'welfare', {
    ..._memberRead,
    Perm.welfarePrepare,
  }),
  RoleSeed('zone_mayor', 'Zone Mayor', 'zone', {
    ..._memberWrite,
    Perm.membersChangeStatus,
  }),
  RoleSeed('zone_deputy', 'Zone Deputy Mayor', 'zone', _memberWrite),
  RoleSeed('zone_secretary', 'Zone Secretary', 'zone', _memberWrite),
  RoleSeed('zone_treasurer', 'Zone Treasurer', 'zone', {
    ..._memberRead,
    Perm.paymentsRecord,
  }),
  RoleSeed('zone_organizer', 'Zone Organizer', 'zone', _memberRead),
  RoleSeed('zone_welfare_officer', 'Zone Welfare Officer', 'zone', {
    ..._memberRead,
    Perm.welfarePrepare,
  }),
  RoleSeed('auditor', 'Auditor', 'oversight', {
    ..._memberRead,
    Perm.financeView,
    Perm.auditView,
    Perm.reportsExport,
  }),
  RoleSeed('electoral_commission', 'JBF Electoral Commission', 'oversight', {
    ..._memberRead,
    Perm.electionsManage,
  }),
  RoleSeed('member', 'Ordinary Member', 'member', {Perm.dashboardView}),
];
