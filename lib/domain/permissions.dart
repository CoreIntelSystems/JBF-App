import 'dart:convert';

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

  /// Mark who attended events and meetings, including by QR scan.
  static const attendanceRecord = 'attendance.record';

  /// Appoint executives and end their terms.
  static const executivesManage = 'executives.manage';
  static const electionsManage = 'elections.manage';
  static const backupManage = 'backup.manage';

  /// Assign and remove roles across the association (Founder, General
  /// Secretary).
  static const rolesAssign = 'roles.assign';

  /// Assign zone executive roles in the user's own zone (Zone Mayor).
  static const zoneRolesAssign = 'roles.assign_zone';

  /// Clear a member's sign-in so they activate again with their phone
  /// number. Zone roles may only do this in their own zone.
  static const signInReset = 'signin.reset';

  /// Approve the monthly dues amount. With [duesManage] as well, the amount
  /// is set directly; with [duesManage] alone it waits for approval.
  static const duesApprove = 'dues.approve';

  /// Send a complaint about a member to the Disciplinary Committee.
  static const disciplineFile = 'discipline.file';

  /// Read complaints and reports, and send warnings.
  static const disciplineHandle = 'discipline.handle';

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
    attendanceRecord,
    executivesManage,
    electionsManage,
    backupManage,
    rolesAssign,
    zoneRolesAssign,
    signInReset,
    duesApprove,
    disciplineFile,
    disciplineHandle,
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

/// Default roles from the JBF access plan (15 October 2026). Zone roles see
/// only the members of the zone(s) they are assigned to.
final defaultRoles = <RoleSeed>[
  // CoreIntel support, and the first account on a new phone.
  RoleSeed('super_admin', 'Super Administrator', 'system', Perm.all.toSet()),
  RoleSeed('founder', 'Founder / President', 'board', Perm.all.toSet()),
  RoleSeed('director', 'Director', 'board', {
    ..._memberRead,
    Perm.financeView,
    Perm.reportsExport,
  }),
  RoleSeed('patron', 'Patron', 'board', {
    ..._memberRead,
    Perm.financeView,
    Perm.reportsExport,
  }),
  RoleSeed('general_secretary', 'General Secretary', 'national', {
    ..._memberWrite,
    Perm.membersChangeStatus,
    Perm.zonesManage,
    Perm.duesApprove,
    Perm.welfarePrepare,
    Perm.welfareApprove,
    Perm.eventsManage,
    Perm.attendanceRecord,
    Perm.executivesManage,
    Perm.reportsExport,
    Perm.backupManage,
    Perm.rolesAssign,
    Perm.signInReset,
    Perm.disciplineFile,
  }),
  RoleSeed('organizer', 'Organizer', 'national', {
    ..._memberWrite,
    Perm.eventsManage,
    Perm.attendanceRecord,
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
  RoleSeed('welfare_secretary', 'Welfare Secretary', 'welfare', {
    ..._memberRead,
    Perm.welfarePrepare,
  }),
  RoleSeed('welfare_treasurer', 'Welfare Treasurer', 'welfare', {
    ..._memberRead,
    Perm.welfarePay,
  }),
  RoleSeed('welfare_member', 'Welfare Team Member', 'welfare', {
    ..._memberRead,
    Perm.welfarePrepare,
  }),
  RoleSeed('zone_mayor', 'Zone Mayor', 'zone', {
    ..._memberWrite,
    Perm.membersChangeStatus,
    Perm.attendanceRecord,
    Perm.zoneRolesAssign,
    Perm.signInReset,
    Perm.disciplineFile,
  }),
  RoleSeed('zone_deputy', 'Zone Deputy Mayor', 'zone', _memberWrite),
  RoleSeed('zone_secretary', 'Zone Secretary', 'zone', {
    ..._memberWrite,
    Perm.attendanceRecord,
    Perm.signInReset,
    Perm.disciplineFile,
  }),
  RoleSeed('zone_treasurer', 'Zone Treasurer', 'zone', {
    ..._memberRead,
    Perm.paymentsRecord,
  }),
  RoleSeed('zone_organizer', 'Zone Organizer', 'zone', {
    ..._memberRead,
    Perm.attendanceRecord,
  }),
  RoleSeed('zone_welfare_officer', 'Zone Welfare Officer', 'zone', {
    ..._memberRead,
    Perm.welfarePrepare,
  }),
  RoleSeed('discipline_member', 'Disciplinary Committee', 'oversight', {
    ..._memberRead,
    Perm.disciplineHandle,
  }),
  RoleSeed('auditor', 'Auditor', 'oversight', {
    ..._memberRead,
    Perm.financeView,
    Perm.auditView,
    Perm.reportsExport,
  }),
  RoleSeed(
    'electoral_commission',
    'Electoral Commission Chairperson',
    'oversight',
    {..._memberRead, Perm.electionsManage},
  ),
  RoleSeed('ec_secretary', 'Electoral Commission Secretary', 'oversight', {
    ..._memberRead,
    Perm.electionsManage,
  }),
  RoleSeed('member', 'Ordinary Member', 'member', {Perm.dashboardView}),
];

/// The stored form of a role's permissions (see `roles.permissions`).
String encodePermissions(Iterable<String> permissions) =>
    jsonEncode(permissions.toSet().toList()..sort());

Set<String> decodePermissions(String? stored) => stored == null
    ? <String>{}
    : {for (final p in jsonDecode(stored) as List) p as String};
