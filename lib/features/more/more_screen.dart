import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app.dart';
import '../../core/org_config.dart';
import '../../domain/permissions.dart';
import '../audit/audit_log_screen.dart';
import '../auth/auth_cubit.dart';
import '../contributions/contribution_types_screen.dart';
import '../users/users_screen.dart';
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
            leading: const Icon(Icons.price_change_outlined),
            title: const Text('Contribution types'),
            subtitle: const Text('Monthly dues and other contributions'),
            onTap: () => open(const ContributionTypesScreen()),
          ),
          if (user?.can(Perm.usersManage) ?? false)
            ListTile(
              leading: const Icon(Icons.manage_accounts),
              title: const Text('Users and roles'),
              subtitle: const Text('Give officers their own login'),
              onTap: () => open(const UsersScreen()),
            ),
          if (user?.can(Perm.auditView) ?? false)
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Audit log'),
              subtitle: const Text('Logins, edits and status changes'),
              onTap: () => open(const AuditLogScreen()),
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
              applicationVersion: '0.2.0 (Phase 2 preview)',
              applicationLegalese:
                  'Powered by ${OrgDefaults.poweredBy}.\n'
                  'All data stays on this device in an encrypted database.',
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
