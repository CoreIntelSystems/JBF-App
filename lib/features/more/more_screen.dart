import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app.dart';
import '../../core/org_config.dart';
import '../../core/ui.dart';
import '../../domain/permissions.dart';
import '../audit/audit_log_screen.dart';
import '../auth/auth_cubit.dart';
import '../charts/charts_screen.dart';
import '../chats/chats_screen.dart';
import '../contributions/contribution_types_screen.dart';
import '../discipline/discipline_screen.dart';
import '../backup/backup_screen.dart';
import '../cloud/cloud_sync_screen.dart';
import '../events/events_screen.dart';
import '../executives/executives_screen.dart';
import '../finance/expenses_screen.dart';
import '../reminders/reminders_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/org_settings_screen.dart';
import '../sync/sync_screen.dart';
import '../users/roles_screen.dart';
import '../users/users_screen.dart';
import '../welfare/welfare_common.dart';
import '../welfare/welfare_screen.dart';
import 'account_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit c) => c.user);
    final themeMode = context.watch<ThemeModeCubit>().state;
    final chat = officerChatAccess(context);
    void open(Widget page) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: InitialsAvatar(user?.displayName ?? '', size: 44),
              title: Text(
                user?.displayName ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('${user?.username} · ${user?.roleName}'),
            ),
          ),
          const SectionTitle('Tools and settings'),
          GroupCard(
            children: [
              ListTile(
                leading: const IconBadge(Icons.lock_outline, size: 36),
                title: const Text('My login and security'),
                subtitle: const Text('Password, PIN and fingerprint'),
                onTap: () => open(const AccountScreen()),
              ),
              if (chat != null)
                ListTile(
                  leading: const IconBadge(Icons.forum_outlined, size: 36),
                  title: const Text('Chats'),
                  subtitle: const Text('Board, council, committees and zones'),
                  onTap: () => open(ChatsScreen(access: chat)),
                ),
              if (chat != null && (user?.can(Perm.disciplineHandle) ?? false))
                ListTile(
                  leading: const IconBadge(Icons.gavel_outlined, size: 36),
                  title: const Text('Discipline'),
                  subtitle: const Text('Complaints and warnings'),
                  onTap: () => open(DisciplineScreen(access: chat)),
                ),
              ListTile(
                leading: const IconBadge(Icons.event, size: 36),
                title: const Text('Events and meetings'),
                subtitle: const Text('Budgets, collections and attendance'),
                onTap: () => open(const EventsScreen()),
              ),
              if (user?.can(Perm.membersView) ?? false)
                ListTile(
                  leading: const IconBadge(Icons.badge_outlined, size: 36),
                  title: const Text('Executives'),
                  subtitle: const Text(
                    'Positions, terms and meeting attendance',
                  ),
                  onTap: () => open(const ExecutivesScreen()),
                ),
              if (user?.canViewWelfare ?? false)
                ListTile(
                  leading: const IconBadge(Icons.volunteer_activism, size: 36),
                  title: const Text('Welfare'),
                  subtitle: const Text(
                    'Cases, approvals, payouts and the fund',
                  ),
                  onTap: () => open(const WelfareScreen()),
                ),
              if ((user?.can(Perm.financeView) ?? false) ||
                  (user?.can(Perm.expensesRecord) ?? false))
                ListTile(
                  leading: const IconBadge(Icons.outbox, size: 36),
                  title: const Text('Expenses'),
                  subtitle: const Text('Money spent, with vouchers'),
                  onTap: () => open(const ExpensesScreen()),
                ),
              if ((user?.can(Perm.financeView) ?? false) ||
                  (user?.can(Perm.membersView) ?? false))
                ListTile(
                  leading: const IconBadge(Icons.insights, size: 36),
                  title: const Text('Charts'),
                  subtitle: const Text(
                    'Collections, zones, welfare and growth',
                  ),
                  onTap: () => open(const ChartsScreen()),
                ),
              if (user?.can(Perm.financeView) ?? false)
                ListTile(
                  leading: const IconBadge(Icons.bar_chart, size: 36),
                  title: const Text('Financial reports'),
                  subtitle: const Text('Daily to annual; PDF, Excel and CSV'),
                  onTap: () => open(const ReportsScreen()),
                ),
              ListTile(
                leading: const IconBadge(Icons.price_change_outlined, size: 36),
                title: const Text('Contribution types'),
                subtitle: const Text('Monthly dues and other contributions'),
                onTap: () => open(const ContributionTypesScreen()),
              ),
              if (user?.can(Perm.backupManage) ?? false)
                ListTile(
                  leading: const IconBadge(Icons.cloud_sync_outlined, size: 36),
                  title: const Text('Cloud sync'),
                  subtitle: const Text(
                    'Share records with other phones online',
                  ),
                  onTap: () => open(const CloudSyncScreen()),
                ),
              if (!kIsWeb &&
                  ((user?.can(Perm.paymentsRecord) ?? false) ||
                      (user?.can(Perm.backupManage) ?? false)))
                ListTile(
                  leading: const IconBadge(
                    Icons.phonelink_ring_outlined,
                    size: 36,
                  ),
                  title: const Text('Field phones'),
                  subtitle: const Text('Send or receive collections by file'),
                  onTap: () => open(const SyncScreen()),
                ),
              ListTile(
                leading: const IconBadge(
                  Icons.notifications_outlined,
                  size: 36,
                ),
                title: const Text('Reminders'),
                subtitle: const Text('Monthly dues day notification'),
                onTap: () => open(const RemindersScreen()),
              ),
              if (user?.can(Perm.settingsManage) ?? false)
                ListTile(
                  leading: const IconBadge(Icons.business_outlined, size: 36),
                  title: const Text('Organisation settings'),
                  subtitle: const Text(
                    'Name, ID and receipt prefixes, colours',
                  ),
                  onTap: () => open(const OrgSettingsScreen()),
                ),
              if ((user?.can(Perm.rolesManage) ?? false) ||
                  (user?.can(Perm.zoneRolesAssign) ?? false))
                ListTile(
                  leading: const IconBadge(
                    Icons.admin_panel_settings_outlined,
                    size: 36,
                  ),
                  title: const Text('Roles'),
                  subtitle: const Text('What each role can do'),
                  onTap: () => open(const RolesScreen()),
                ),
              if (user?.can(Perm.usersManage) ?? false)
                ListTile(
                  leading: const IconBadge(Icons.manage_accounts, size: 36),
                  title: const Text('Old username logins'),
                  subtitle: const Text('Logins made before member sign-in'),
                  onTap: () => open(const UsersScreen()),
                ),
              if (user?.can(Perm.auditView) ?? false)
                ListTile(
                  leading: const IconBadge(Icons.history, size: 36),
                  title: const Text('Audit log'),
                  subtitle: const Text('Logins, edits and status changes'),
                  onTap: () => open(const AuditLogScreen()),
                ),
              if (!kIsWeb && (user?.can(Perm.backupManage) ?? false))
                ListTile(
                  leading: const IconBadge(Icons.backup_outlined, size: 36),
                  title: const Text('Backup and restore'),
                  subtitle: const Text(
                    'Encrypted backup file and daily copies',
                  ),
                  onTap: () => open(const BackupScreen()),
                ),
              ListTile(
                leading: const IconBadge(Icons.dark_mode_outlined, size: 36),
                title: const Text('Appearance'),
                trailing: DropdownButton<ThemeMode>(
                  value: themeMode,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('System'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark'),
                    ),
                  ],
                  onChanged: (m) {
                    if (m != null) context.read<ThemeModeCubit>().set(m);
                  },
                ),
              ),
              ListTile(
                leading: const IconBadge(Icons.info_outline, size: 36),
                title: const Text('About'),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: OrgDefaults.name,
                  applicationVersion: '0.10.0 (roles, chats and discipline)',
                  applicationLegalese:
                      'Powered by ${OrgDefaults.poweredBy}.\n'
                      'Data is kept on this device in an encrypted database. '
                      'With cloud sync on, it is also shared with your '
                      'organisation\'s other phones.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GroupCard(
            children: [
              ListTile(
                leading: const IconBadge(Icons.logout, size: 36),
                title: const Text('Sign out'),
                onTap: () => context.read<AuthCubit>().logout(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
