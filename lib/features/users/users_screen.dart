import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../data/database.dart';
import '../../data/repositories/auth_repository.dart';
import '../auth/auth_cubit.dart';

/// Lets an administrator give officers their own login and role.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late final AppServices _services = context.read<AppServices>();
  late final Stream<List<UserWithRole>> _users = _services.auth.watchUsers();
  List<Role> _roles = const [];

  @override
  void initState() {
    super.initState();
    _services.auth.roles().then((r) {
      if (mounted) setState(() => _roles = r);
    });
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _edit([UserWithRole? existing]) async {
    final result = await showModalBottomSheet<_UserFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UserForm(roles: _roles, existing: existing),
    );
    if (result == null || !mounted) return;
    final actor = context.read<AuthCubit>().user!.actor(_services.deviceId);
    try {
      if (existing == null) {
        await _services.auth.createUser(
          displayName: result.displayName,
          username: result.username,
          password: result.password!,
          roleId: result.roleId,
          actor: actor,
        );
        _toast('User ${result.username} created.');
      } else {
        await _services.auth.updateUser(
          existing.user.id,
          roleId: result.roleId,
          isActive: result.isActive,
          actor: actor,
        );
        if (result.password != null && result.password!.isNotEmpty) {
          await _services.auth.resetPassword(
            existing.user.id,
            result.password!,
            actor: actor,
          );
        }
        _toast('Saved.');
      }
    } on AuthException catch (e) {
      _toast(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users and roles')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _roles.isEmpty ? null : () => _edit(),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add user'),
      ),
      body: StreamBuilder<List<UserWithRole>>(
        stream: _users,
        builder: (context, snap) {
          final users = snap.data;
          if (users == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: users.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final u = users[i];
              return ListTile(
                leading: Icon(
                  u.user.isActive ? Icons.person : Icons.person_off,
                ),
                title: Text(u.user.displayName),
                subtitle: Text(
                  '${u.user.username} · ${u.role.name}'
                  '${u.user.isActive ? '' : ' · deactivated'}'
                  '${u.user.lastLoginAt == null ? '' : '\nLast sign in ${formatDateTime(u.user.lastLoginAt!)}'}',
                ),
                isThreeLine: u.user.lastLoginAt != null,
                onTap: () => _edit(u),
              );
            },
          );
        },
      ),
    );
  }
}

class _UserFormResult {
  _UserFormResult(
    this.displayName,
    this.username,
    this.password,
    this.roleId,
    this.isActive,
  );
  final String displayName;
  final String username;
  final String? password;
  final String roleId;
  final bool isActive;
}

class _UserForm extends StatefulWidget {
  const _UserForm({required this.roles, this.existing});
  final List<Role> roles;
  final UserWithRole? existing;

  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.existing?.user.displayName,
  );
  late final _username = TextEditingController(
    text: widget.existing?.user.username,
  );
  final _password = TextEditingController();
  late String? _roleId = widget.existing?.role.id;
  late bool _active = widget.existing?.user.isActive ?? true;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                editing ? 'Edit user' : 'New user',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                enabled: !editing,
                decoration: const InputDecoration(labelText: 'Full name'),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter a name.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _username,
                enabled: !editing,
                decoration: const InputDecoration(labelText: 'Username'),
                autocorrect: false,
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter a username.' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _roleId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [
                  for (final r in widget.roles)
                    DropdownMenuItem(value: r.id, child: Text(r.name)),
                ],
                onChanged: (v) => setState(() => _roleId = v),
                validator: (v) => v == null ? 'Choose a role.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: editing
                      ? 'New password (leave blank to keep)'
                      : 'Temporary password',
                ),
                validator: (v) => editing && (v ?? '').isEmpty
                    ? null
                    : AuthRepository.validatePassword(v ?? ''),
              ),
              if (editing)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Can sign in'),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  if (!_form.currentState!.validate()) return;
                  Navigator.pop(
                    context,
                    _UserFormResult(
                      _name.text,
                      _username.text,
                      _password.text.isEmpty ? null : _password.text,
                      _roleId!,
                      _active,
                    ),
                  );
                },
                child: Text(editing ? 'Save' : 'Create user'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
