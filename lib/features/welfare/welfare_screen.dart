import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/repositories/welfare_repository.dart';
import '../../domain/permissions.dart';
import '../auth/auth_cubit.dart';
import 'benefit_amounts_screen.dart';
import 'case_detail_screen.dart';
import 'new_case_screen.dart';
import 'welfare_common.dart';

/// Welfare cases, the welfare fund, and what is waiting on whom.
class WelfareScreen extends StatefulWidget {
  const WelfareScreen({super.key, this.initialFilter});

  final WelfareStatus? initialFilter;

  @override
  State<WelfareScreen> createState() => _WelfareScreenState();
}

class _WelfareScreenState extends State<WelfareScreen> {
  late WelfareStatus? _filter = widget.initialFilter;
  late Stream<List<WelfareCaseView>> _cases = _watch();
  late final Stream<WelfareSummary> _summary = context
      .read<AppServices>()
      .welfare
      .watchSummary();

  Stream<List<WelfareCaseView>> _watch() =>
      context.read<AppServices>().welfare.watchCases(status: _filter);

  void _setFilter(WelfareStatus? f) => setState(() {
    _filter = f;
    _cases = _watch();
  });

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit c) => c.user);
    final canPrepare = user?.can(Perm.welfarePrepare) ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welfare'),
        actions: [
          IconButton(
            tooltip: 'Benefit amounts',
            icon: const Icon(Icons.price_check),
            onPressed: () => _open(const BenefitAmountsScreen()),
          ),
        ],
      ),
      floatingActionButton: canPrepare
          ? FloatingActionButton.extended(
              heroTag: 'welfare-fab',
              onPressed: () => _open(const NewCaseScreen()),
              icon: const Icon(Icons.add),
              label: const Text('New case'),
            )
          : null,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: StreamBuilder<WelfareSummary>(
              stream: _summary,
              builder: (context, snap) {
                final s = snap.data;
                if (s == null) return const SizedBox(height: 8);
                return _SummaryCard(
                  summary: s,
                  onBenefits: () => _open(const BenefitAmountsScreen()),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final f in <WelfareStatus?>[
                    WelfareStatus.pending,
                    WelfareStatus.approved,
                    WelfareStatus.paid,
                    WelfareStatus.rejected,
                    null,
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(switch (f) {
                          null => 'All',
                          WelfareStatus.pending => 'Awaiting approval',
                          WelfareStatus.approved => 'To pay',
                          WelfareStatus.paid => 'Paid',
                          WelfareStatus.rejected => 'Rejected',
                        }),
                        selected: _filter == f,
                        onSelected: (_) => _setFilter(f),
                      ),
                    ),
                ],
              ),
            ),
          ),
          StreamBuilder<List<WelfareCaseView>>(
            stream: _cases,
            builder: (context, snap) {
              final items = snap.data;
              if (items == null) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              if (items.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No cases here.', textAlign: TextAlign.center),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.only(bottom: 88),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => WelfareCaseTile(view: items[i]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class WelfareCaseTile extends StatelessWidget {
  const WelfareCaseTile({super.key, required this.view});
  final WelfareCaseView view;

  @override
  Widget build(BuildContext context) {
    final c = view.welfareCase;
    return ListTile(
      title: Text(view.member.fullName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${view.type.name} · ${c.caseNo}'),
          const SizedBox(height: 4),
          WelfareStatusChip(status: c.status),
        ],
      ),
      trailing: Text(
        formatMoney(c.amount),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => CaseDetailScreen(caseId: c.id)),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.onBenefits});
  final WelfareSummary summary;
  final VoidCallback onBenefits;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      color: scheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: scheme.onPrimary),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Welfare fund balance'),
              Text(
                formatMoney(s.fundBalance),
                style: text.headlineSmall?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Collected ${formatMoney(s.fundCollected)} · '
                'paid out ${formatMoney(s.fundPaidOut)}',
              ),
              if (s.pendingCases > 0 || s.approvedUnpaid > 0) ...[
                const SizedBox(height: 8),
                Text(
                  [
                    if (s.pendingCases > 0)
                      '${s.pendingCases} awaiting approval',
                    if (s.approvedUnpaid > 0) '${s.approvedUnpaid} to pay',
                  ].join(' · '),
                  style: TextStyle(
                    color: scheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (s.pendingBenefitChanges > 0)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.secondary,
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: onBenefits,
                  child: Text(
                    '${s.pendingBenefitChanges} benefit amount '
                    'change${s.pendingBenefitChanges == 1 ? '' : 's'} '
                    'awaiting approval',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
