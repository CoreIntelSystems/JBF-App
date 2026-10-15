import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app.dart';
import '../../core/org_config.dart';
import '../../domain/permissions.dart';
import '../audit/audit_log_screen.dart';
import '../auth/auth_cubit.dart';
import '../charts/charts_screen.dart';
import '../contributions/contribution_types_screen.dart';
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
    void open(Widget page) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.account_circle),
            title: Text(user?.displayName ?? ''),
            subtitle: Text('${user?.username} · ${user?.roleName}'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('My login and security'),
            subtitle: const Text('Password, PIN and fingerprint'),
            onTap: () => open(const AccountScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.event),
            title: const Text('Events and meetings'),
            subtitle: const Text('Budgets, collections and attendance'),
            onTap: () => open(const EventsScreen()),
          ),
          if (user?.can(Perm.membersView) ?? false)
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Executives'),
              subtitle: const Text('Positions, terms and meeting attendance'),
              onTap: () => open(const ExecutivesScreen()),
            ),
          if (user?.canViewWelfare ?? false)
            ListTile(
              leading: const Icon(Icons.volunteer_activism),
              title: const Text('Welfare'),
              subtitle: const Text('Cases, approvals, payouts and the fund'),
              onTap: () => open(const WelfareScreen()),
            ),
          if ((user?.can(Perm.financeView) ?? false) ||
              (user?.can(Perm.expensesRecord) ?? false))
            ListTile(
              leading: const Icon(Icons.outbox),
              title: const Text('Expenses'),
              subtitle: const Text('Money spent, with vouchers'),
              onTap: () => open(const ExpensesScreen()),
            ),
          if ((user?.can(Perm.financeView) ?? false) ||
              (user?.can(Perm.membersView) ?? false))
            ListTile(
              leading: const Icon(Icons.insights),
              title: const Text('Charts'),
              subtitle: const Text('Collections, zones, welfare and growth'),
              onTap: () => open(const ChartsScreen()),
            ),
          if (user?.can(Perm.financeView) ?? false)
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Financial reports'),
              subtitle: const Text('Daily to annual; PDF, Excel and CSV'),
              onTap: () => open(const ReportsScreen()),
            ),
          ListTile(
            leading: const Icon(Icons.price_change_outlined),
            title: const Text('Contribution types'),
            subtitle: const Text('Monthly dues and other contributions'),
            onTap: () => open(const ContributionTypesScreen()),
          ),
          if (user?.can(Perm.backupManage) ?? false)
            ListTile(
              leading: const Icon(Icons.cloud_sync_outlined),
              title: const Text('Cloud sync'),
              subtitle: const Text('Share records with other phones online'),
              onTap: () => open(const CloudSyncScreen()),
            ),
          if ((user?.can(Perm.paymentsRecord) ?? false) ||
              (user?.can(Perm.backupManage) ?? false))
            ListTile(
              leading: const Icon(Icons.phonelink_ring_outlined),
              title: const Text('Field phones'),
              subtitle: const Text('Send or receive collections by file'),
              onTap: () => open(const SyncScreen()),
            ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Reminders'),
            subtitle: const Text('Monthly dues day notification'),
            onTap: () => open(const RemindersScreen()),
          ),
          if (user?.can(Perm.settingsManage) ?? false)
            ListTile(
              leading: const Icon(Icons.business_outlined),
              title: const Text('Organisation settings'),
              subtitle: const Text('Name, ID and receipt prefixes, colours'),
              onTap: () => open(const OrgSettingsScreen()),
            ),
          if ((user?.can(Perm.rolesManage) ?? false) ||
              (user?.can(Perm.zoneRolesAssign) ?? false))
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Roles'),
              subtitle: const Text('What each role can do'),
              onTap: () => open(const RolesScreen()),
            ),
          if (user?.can(Perm.usersManage) ?? false)
            ListTile(
              leading: const Icon(Icons.manage_accounts),
              title: const Text('Old username logins'),
              subtitle: const Text('Logins made before member sign-in'),
              onTap: () => open(const UsersScreen()),
            ),
          if (user?.can(Perm.auditView) ?? false)
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Audit log'),
              subtitle: const Text('Logins, edits and status changes'),
              onTap: () => open(const AuditLogScreen()),
            ),
          if (user?.can(Perm.backupManage) ?? false)
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Backup and restore'),
              subtitle: const Text('Encrypted backup file and daily copies'),
              onTap: () => open(const BackupScreen()),
            ),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('Appearance'),
            trailing: DropdownButton<ThemeMode>(
              value: themeMode,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('System'),
                ),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
              onChanged: (m) {
                if (m != null) context.read<ThemeModeCubit>().set(m);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: OrgDefaults.name,
              applicationVersion: '0.9.2 (member sign-in and roles)',
              applicationLegalese:
                  'Powered by ${OrgDefaults.poweredBy}.\n'
                  'Data is kept on this device in an encrypted database. '
                  'With cloud sync on, it is also shared with your '
                  'organisation\'s other phones.',
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () => context.read<AuthCubit>().logout(),
          ),
        ],
      ),
    );
  }
}
