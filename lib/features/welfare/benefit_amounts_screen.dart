import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/repositories/welfare_repository.dart';
import '../../domain/permissions.dart';
import '../auth/auth_cubit.dart';
import 'welfare_common.dart';

/// Fixed benefit amounts per type of case. The Treasurer proposes; the
/// Welfare Chairman (or General Secretary standing in) approves.
class BenefitAmountsScreen extends StatefulWidget {
  const BenefitAmountsScreen({super.key});

  @override
  State<BenefitAmountsScreen> createState() => _BenefitAmountsScreenState();
}

class _BenefitAmountsScreenState extends State<BenefitAmountsScreen> {
  late final Stream<List<WelfareCaseType>> _types = context
      .read<AppServices>()
      .welfare
      .watchCaseTypes();

  WelfareActor _actor() {
    final services = context.read<AppServices>();
    return context.read<AuthCubit>().user!.welfareActor(services.deviceId);
  }

  Future<void> _try(Future<void> Function() f, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await f();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } on WelfareException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _propose(WelfareCaseType t) async {
    final welfare = context.read<AppServices>().welfare;
    final ctl = TextEditingController(
      text: t.benefitAmount == null ? '' : moneyInput(t.benefitAmount!),
    );
    final amount = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.name),
        content: TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Benefit amount',
            prefixText: 'GHS ',
            helperText: 'Applies to new cases once approved',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(parseMoney(ctl.text)),
            child: const Text('Send for approval'),
          ),
        ],
      ),
    );
    if (amount == null) return;
    await _try(
      () => welfare.proposeBenefit(t.id, amount, _actor()),
      'Sent to the Welfare Chairman for approval',
    );
  }

  Future<void> _add() async {
    final welfare = context.read<AppServices>().welfare;
    final ctl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New type of case'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctl.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null) return;
    await _try(() => welfare.addCaseType(name, _actor()).then((_) {}), 'Added');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit c) => c.user);
    final canSet = user?.can(Perm.welfareSetBenefits) ?? false;
    final canApprove = user?.can(Perm.welfareApprove) ?? false;
    final welfare = context.read<AppServices>().welfare;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Benefit amounts'),
        actions: [
          if (canSet)
            IconButton(
              tooltip: 'Add type',
              icon: const Icon(Icons.add),
              onPressed: _add,
            ),
        ],
      ),
      body: StreamBuilder<List<WelfareCaseType>>(
        stream: _types,
        builder: (context, snap) {
          final items = snap.data;
          if (items == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(
                  canSet
                      ? 'Tap a type to set its amount. It applies once the '
                            'Welfare Chairman approves.'
                      : 'The Treasurer sets these amounts and the Welfare '
                            'Chairman approves them.',
                ),
              ),
              for (final t in items)
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        title: Text(t.name),
                        subtitle: t.benefitApprovedByName == null
                            ? (t.description == null
                                  ? null
                                  : Text(t.description!))
                            : Text(
                                'Approved by ${t.benefitApprovedByName}, '
                                '${formatDate(t.benefitApprovedAt)}',
                              ),
                        trailing: Text(
                          t.benefitAmount == null
                              ? 'Not set'
                              : formatMoney(t.benefitAmount!),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onTap: canSet ? () => _propose(t) : null,
                      ),
                      if (t.proposedAmount != null)
                        Container(
                          color: Theme.of(
                            context,
                          ).colorScheme.tertiaryContainer,
                          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Change to ${formatMoney(t.proposedAmount!)} '
                                'proposed by ${t.proposedByName ?? ''}, '
                                'awaiting approval',
                              ),
                              if (canApprove)
                                OverflowBar(
                                  alignment: MainAxisAlignment.end,
                                  spacing: 8,
                                  overflowAlignment: OverflowBarAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () => _try(
                                        () => welfare.decideBenefit(
                                          t.id,
                                          _actor(),
                                          approve: false,
                                        ),
                                        'Change rejected',
                                      ),
                                      child: const Text('Reject'),
                                    ),
                                    FilledButton(
                                      onPressed: () => _try(
                                        () => welfare.decideBenefit(
                                          t.id,
                                          _actor(),
                                          approve: true,
                                        ),
                                        'Amount approved',
                                      ),
                                      child: const Text('Approve'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
