import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../data/database.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/member_repository.dart';
import '../../data/sync/sync_api.dart';
import '../../domain/permissions.dart';
import '../auth/auth_cubit.dart';

/// On a member's page: the roles they hold in the app, and their sign-in.
/// The Founder and General Secretary give any role; a Zone Mayor gives zone
/// roles in their own zone. Sign-ins are reset by the Founder, General
/// Secretary, or the member's own Zone Mayor or Zone Secretary.
class MemberAccessSection extends StatefulWidget {
  const MemberAccessSection({
    super.key,
    required this.member,
    required this.zones,
  });

  final Member member;
  final List<Zone> zones;

  static bool visibleTo(AppUser? user) =>
      user != null &&
      (user.can(Perm.rolesAssign) ||
          user.can(Perm.zoneRolesAssign) ||
          user.can(Perm.helpersAssign) ||
          user.can(Perm.signInReset));

  @override
  State<MemberAccessSection> createState() => _MemberAccessSectionState();
}

class _MemberAccessSectionState extends State<MemberAccessSection> {
  late final _services = context.read<AppServices>();
  late final _roles = _services.auth.watchHeldRoles(widget.member.id);
  Future<MemberAccountStatus?>? _status;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  void _loadStatus() {
    final sync = _services.sync;
    _status = sync.state.enabled
        ? sync
              .memberAccountStatus(widget.member.id)
              .then<MemberAccountStatus?>((s) => s)
              .catchError((_) => null)
        : Future.value();
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _give(AppUser user) async {
    final roles = [
      for (final r in await _services.auth.roles())
        if (AuthRepository.canGive(user, r)) r,
    ];
    final zones = await _services.members.zones();
    final scope = user.can(Perm.rolesAssign) ? null : user.zoneScope;
    if (!mounted) return;
    final result = await showDialog<(Role, List<String>)>(
      context: context,
      builder: (_) => _GiveRoleDialog(
        roles: roles,
        zones: [
          for (final z in zones)
            if (scope == null || scope.contains(z.id)) z,
        ],
        memberZoneIds: {for (final z in widget.zones) z.id},
      ),
    );
    if (result == null || !mounted) return;
    try {
      await _services.auth.assignRole(
        memberId: widget.member.id,
        roleId: result.$1.id,
        zoneIds: result.$2,
        by: user,
        deviceId: _services.deviceId,
      );
      _toast('${widget.member.fullName} is now ${result.$1.name}.');
    } on AuthException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _end(AppUser user, HeldRole held) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${held.role.name}?'),
        content: Text(
          '${widget.member.fullName} will lose this role\'s access from now '
          'on, on every phone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _services.auth.endRole(
        held,
        by: user,
        deviceId: _services.deviceId,
      );
      _toast('Role removed.');
    } on AuthException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset sign-in?'),
        content: Text(
          '${widget.member.fullName} will be signed out on every phone and '
          'must activate again with their member ID and phone number '
          '(${widget.member.phone ?? 'none recorded'}).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _services.sync.resetMemberSignIn(widget.member.id);
      await _services.auth.forgetMember(widget.member.id);
      _toast('Sign-in reset. They can activate again now.');
      setState(_loadStatus);
    } on SyncException catch (e) {
      _toast(
        e.offline ? 'Connect to the internet to reset a sign-in.' : e.message,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit c) => c.user)!;
    final theme = Theme.of(context);
    final canReset =
        user.can(Perm.signInReset) &&
        (user.can(Perm.rolesAssign) ||
            user.zoneScope == null ||
            widget.zones.any((z) => user.zoneScope!.contains(z.id)));
    final canGiveAny =
        user.can(Perm.rolesAssign) ||
        user.can(Perm.zoneRolesAssign) ||
        user.can(Perm.helpersAssign);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Roles and access', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          StreamBuilder<List<HeldRole>>(
            stream: _roles,
            builder: (context, snap) {
              final held = snap.data ?? const <HeldRole>[];
              final zoneNames = {for (final z in widget.zones) z.id: z.name};
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (held.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Member only: sees their own dues, events and the '
                        'executives list.',
                      ),
                    ),
                  for (final h in held)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.verified_user_outlined),
                      title: Text(h.role.name),
                      subtitle: Text(
                        [
                          if (h.zoneIds.isNotEmpty)
                            h.zoneIds.map((z) => zoneNames[z] ?? z).join(', '),
                          'Since ${formatDate(h.assignment.startsOn)}',
                          if (h.assignment.assignedByName != null)
                            'by ${h.assignment.assignedByName}',
                        ].join(' · '),
                      ),
                      trailing: AuthRepository.canGive(user, h.role)
                          ? IconButton(
                              tooltip: 'Remove role',
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => _end(user, h),
                            )
                          : null,
                    ),
                ],
              );
            },
          ),
          if (canGiveAny)
            OutlinedButton.icon(
              onPressed: () => _give(user),
              icon: const Icon(Icons.add_moderator_outlined),
              label: const Text('Give a role'),
            ),
          if (canReset) ...[
            const SizedBox(height: 8),
            FutureBuilder<MemberAccountStatus?>(
              future: _status,
              builder: (context, snap) {
                final s = snap.data;
                final text = !_services.sync.state.enabled
                    ? 'Sign-in status needs cloud sync on this phone.'
                    : snap.connectionState == ConnectionState.waiting
                    ? 'Checking sign-in...'
                    : s == null
                    ? 'Sign-in status unavailable offline.'
                    : s.activated
                    ? 'Account active since ${formatDate(s.activatedAt)}.'
                    : s.resetAt != null
                    ? 'Sign-in reset ${formatDate(s.resetAt)}'
                          '${s.resetBy == null ? '' : ' by ${s.resetBy}'}. '
                          'Not activated again yet.'
                    : 'Not activated yet.';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.key_outlined),
                  title: const Text('Sign-in'),
                  subtitle: Text(text),
                  trailing: s?.activated ?? false
                      ? TextButton(
                          onPressed: _reset,
                          child: const Text('Reset'),
                        )
                      : null,
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _GiveRoleDialog extends StatefulWidget {
  const _GiveRoleDialog({
    required this.roles,
    required this.zones,
    required this.memberZoneIds,
  });

  final List<Role> roles;
  final List<Zone> zones;
  final Set<String> memberZoneIds;

  @override
  State<_GiveRoleDialog> createState() => _GiveRoleDialogState();
}

class _GiveRoleDialogState extends State<_GiveRoleDialog> {
  Role? _role;
  late final Set<String> _zones = {
    for (final z in widget.zones)
      if (widget.memberZoneIds.contains(z.id)) z.id,
  };

  @override
  Widget build(BuildContext context) {
    final zoneRole = _role?.level == 'zone';
    return AlertDialog(
      title: const Text('Give a role'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<Role>(
              key: const Key('giveRole'),
              initialValue: _role,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Role'),
              items: [
                for (final r in widget.roles)
                  DropdownMenuItem(value: r, child: Text(r.name)),
              ],
              onChanged: (r) => setState(() => _role = r),
            ),
            if (zoneRole) ...[
              const SizedBox(height: 12),
              const Text('Zones this role looks after (at most 2)'),
              for (final z in widget.zones)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _zones.contains(z.id),
                  title: Text(zoneDisplayName(z)),
                  onChanged: (on) => setState(
                    () => on! ? _zones.add(z.id) : _zones.remove(z.id),
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _role == null
              ? null
              : () => Navigator.of(
                  context,
                ).pop((_role!, zoneRole ? _zones.toList() : <String>[])),
          child: const Text('Give role'),
        ),
      ],
    );
  }
}
