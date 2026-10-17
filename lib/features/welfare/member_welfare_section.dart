import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../data/database.dart';
import '../../core/format.dart';
import '../../data/repositories/welfare_repository.dart';
import '../../domain/permissions.dart';
import '../../domain/welfare_membership.dart';
import '../auth/auth_cubit.dart';
import 'new_case_screen.dart';
import 'welfare_common.dart';
import 'welfare_screen.dart';

/// Welfare cases on a member's page.
class MemberWelfareSection extends StatefulWidget {
  const MemberWelfareSection({
    super.key,
    required this.member,
    this.own = false,
  });
  final Member member;

  /// The signed-in person's own cases, which they may always see.
  final bool own;

  @override
  State<MemberWelfareSection> createState() => _MemberWelfareSectionState();
}

class _MemberWelfareSectionState extends State<MemberWelfareSection> {
  late final Stream<List<WelfareCaseView>> _cases = context
      .read<AppServices>()
      .welfare
      .watchCases(memberId: widget.member.id);

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit c) => c.user);
    if (!widget.own && !(user?.canViewWelfare ?? false)) {
      return const SizedBox.shrink();
    }
    final canPrepare = user?.can(Perm.welfarePrepare) ?? false;
    return StreamBuilder<List<WelfareCaseView>>(
      stream: _cases,
      builder: (context, snap) {
        final items = snap.data ?? const [];
        if (items.isEmpty && !canPrepare && !widget.own) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Welfare', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MembershipTile(
                      member: widget.member,
                      canChange: canPrepare || widget.own,
                      canReinstate: user?.can(Perm.welfareApprove) ?? false,
                    ),
                    if (items.isEmpty)
                      const ListTile(title: Text('No welfare cases')),
                    for (final v in items) WelfareCaseTile(view: v),
                    if (canPrepare)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  NewCaseScreen(member: widget.member),
                            ),
                          ),
                          icon: const Icon(Icons.volunteer_activism),
                          label: const Text('Report welfare case'),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Whether the member is in welfare, with the buttons to change it. Welfare
/// is by choice; three missed payments in a row disqualify.
class _MembershipTile extends StatelessWidget {
  const _MembershipTile({
    required this.member,
    required this.canChange,
    required this.canReinstate,
  });
  final Member member;
  final bool canChange;
  final bool canReinstate;

  Future<void> _run(
    BuildContext context,
    Future<void> Function(WelfareActor by) action,
  ) async {
    final services = context.read<AppServices>();
    final user = context.read<AuthCubit>().user!;
    try {
      await action(user.welfareActor(services.deviceId));
    } on WelfareException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final welfare = context.read<AppServices>().welfare;
    final (title, subtitle) = switch (member.welfareMembership) {
      WelfareMembership.member => (
        'Welfare member',
        member.welfareSince == null
            ? null
            : 'Since ${formatDate(member.welfareSince!)}',
      ),
      WelfareMembership.disqualified => (
        'Disqualified from welfare',
        'Missed ${WelfareRules.missedLimit} payments in a row. An officer '
            'can reinstate them.',
      ),
      WelfareMembership.none => (
        'Not a welfare member',
        'Welfare is by choice. Paying welfare dues or a welfare contribution '
            'also makes a member one.',
      ),
    };
    return ListTile(
      leading: Icon(
        member.welfareMembership == WelfareMembership.member
            ? Icons.verified_user
            : Icons.shield_outlined,
      ),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: switch (member.welfareMembership) {
        WelfareMembership.none when canChange => TextButton(
          onPressed: () =>
              _run(context, (by) => welfare.joinWelfare(member.id, by)),
          child: const Text('Join'),
        ),
        WelfareMembership.member when canChange => TextButton(
          onPressed: () =>
              _run(context, (by) => welfare.leaveWelfare(member.id, by)),
          child: const Text('Leave'),
        ),
        WelfareMembership.disqualified when canReinstate => TextButton(
          onPressed: () =>
              _run(context, (by) => welfare.reinstateWelfare(member.id, by)),
          child: const Text('Reinstate'),
        ),
        _ => null,
      },
    );
  }
}
