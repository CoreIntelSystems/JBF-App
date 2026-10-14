import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../data/database.dart';
import '../../data/repositories/welfare_repository.dart';
import '../../domain/permissions.dart';
import '../auth/auth_cubit.dart';
import 'new_case_screen.dart';
import 'welfare_common.dart';
import 'welfare_screen.dart';

/// Welfare cases on a member's page.
class MemberWelfareSection extends StatefulWidget {
  const MemberWelfareSection({super.key, required this.member});
  final Member member;

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
    if (!(user?.canViewWelfare ?? false)) return const SizedBox.shrink();
    final canPrepare = user?.can(Perm.welfarePrepare) ?? false;
    return StreamBuilder<List<WelfareCaseView>>(
      stream: _cases,
      builder: (context, snap) {
        final items = snap.data ?? const [];
        if (items.isEmpty && !canPrepare) return const SizedBox.shrink();
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
