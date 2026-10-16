import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../data/database.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/permissions.dart';
import '../auth/auth_cubit.dart';

/// What each role can do. The Founder changes any role; a Zone Mayor adds
/// extra zone roles with access they hold themselves. Roles are given to
/// people on their member page.
class RolesScreen extends StatelessWidget {
  const RolesScreen({super.key});

  static const levels = {
    'system': 'CoreIntel support',
    'board': 'Board',
    'national': 'National executives',
    'welfare': 'Welfare team',
    'zone': 'Zone roles',
    'oversight': 'Committees and oversight',
    'member': 'Members',
  };

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit c) => c.user)!;
    final services = context.read<AppServices>();
    return Scaffold(
      appBar: AppBar(title: const Text('Roles')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const RoleEditScreen())),
        icon: const Icon(Icons.add),
        label: Text(user.can(Perm.rolesManage) ? 'Add role' : 'Add zone role'),
      ),
      body: StreamBuilder<List<Role>>(
        stream: services.auth.watchRoles(),
        builder: (context, snap) {
          final roles = snap.data ?? const <Role>[];
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  'Give roles to people on their member page. Changes here '
                  'reach every phone at the next sync.',
                ),
              ),
              for (final MapEntry(key: level, value: title) in levels.entries)
                if (roles.any((r) => r.level == level)) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  for (final r in roles.where((r) => r.level == level))
                    ListTile(
                      title: Text(r.name),
                      subtitle: Text(
                        '${AuthRepository.permissionsOf(r).length} of '
                        '${Perm.all.length} kinds of access',
                      ),
                      trailing: AuthRepository.canEditRole(user, r)
                          ? const Icon(Icons.chevron_right)
                          : null,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => RoleEditScreen(existing: r),
                        ),
                      ),
                    ),
                ],
            ],
          );
        },
      ),
    );
  }
}

class RoleEditScreen extends StatefulWidget {
  const RoleEditScreen({super.key, this.existing});

  final Role? existing;

  @override
  State<RoleEditScreen> createState() => _RoleEditScreenState();
}

class _RoleEditScreenState extends State<RoleEditScreen> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late String _level = widget.existing?.level ?? 'zone';
  late final Set<String> _perms = widget.existing == null
      ? {Perm.dashboardView, Perm.membersView}
      : AuthRepository.permissionsOf(widget.existing!);
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save(AppUser user) async {
    final services = context.read<AppServices>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await services.auth.saveRole(
        existing: widget.existing,
        name: _name.text,
        level: _level,
        permissions: _perms,
        by: user,
        deviceId: services.deviceId,
      );
      nav.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Role saved.')));
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit c) => c.user)!;
    final existing = widget.existing;
    final editable =
        existing == null || AuthRepository.canEditRole(user, existing);
    final full = user.can(Perm.rolesManage);
    return Scaffold(
      appBar: AppBar(
        title: Text(existing == null ? 'Add role' : existing.name),
        actions: [
          if (editable)
            TextButton(
              onPressed: _busy ? null : () => _save(user),
              child: const Text('Save'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('roleName'),
            controller: _name,
            enabled: editable,
            decoration: const InputDecoration(labelText: 'Role name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          if (existing == null && full)
            DropdownButtonFormField<String>(
              initialValue: _level,
              decoration: const InputDecoration(labelText: 'Group'),
              items: [
                for (final MapEntry(key: k, value: v)
                    in RolesScreen.levels.entries)
                  if (k != 'system') DropdownMenuItem(value: k, child: Text(v)),
              ],
              onChanged: (v) => setState(() => _level = v!),
            )
          else
            Text(
              RolesScreen.levels[_level] ?? _level,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (_level == 'zone')
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Zone roles only see the zones they are given.'),
            ),
          const SizedBox(height: 12),
          Text(
            'What this role can do',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final p in Perm.all)
            if (full || user.can(p) || _perms.contains(p))
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _perms.contains(p),
                title: Text(Perm.labels[p] ?? p),
                onChanged: editable && (full || user.can(p))
                    ? (on) =>
                          setState(() => on! ? _perms.add(p) : _perms.remove(p))
                    : null,
              ),
        ],
      ),
    );
  }
}
