import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/repositories/payment_repository.dart';
import '../../domain/permissions.dart';
import '../auth/auth_cubit.dart';
import 'payment_widgets.dart';
import 'record_payment_screen.dart';

/// Dues balance and payment history on a member's page.
class MemberLedgerSection extends StatefulWidget {
  const MemberLedgerSection({super.key, required this.member});
  final Member member;

  @override
  State<MemberLedgerSection> createState() => _MemberLedgerSectionState();
}

class _MemberLedgerSectionState extends State<MemberLedgerSection> {
  late final Stream<MemberLedger> _ledger = context
      .read<AppServices>()
      .payments
      .watchLedger(widget.member.id);

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit c) => c.user);
    final canRecord = user?.can(Perm.paymentsRecord) ?? false;
    final text = Theme.of(context).textTheme;
    return StreamBuilder<MemberLedger>(
      stream: _ledger,
      builder: (context, snap) {
        final l = snap.data;
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Contributions', style: text.titleMedium),
              const SizedBox(height: 4),
              if (l == null)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Total paid'),
                        subtitle: l.lastPaymentDate == null
                            ? const Text('No payments yet')
                            : Text(
                                'Last paid ${formatDate(l.lastPaymentDate)}',
                              ),
                        trailing: Text(
                          formatMoney(l.totalPaid),
                          style: text.titleMedium,
                        ),
                      ),
                      for (final d in l.dues)
                        ListTile(
                          title: Text(d.type.name),
                          subtitle: Text(
                            d.summary.outstanding > 0
                                ? '${d.summary.monthsBehind} months behind, '
                                      'from ${formatPeriod(d.summary.nextUnpaidPeriod)}'
                                : 'Up to date',
                          ),
                          trailing: Text(
                            d.summary.outstanding > 0
                                ? 'Owes ${formatMoney(d.summary.outstanding)}'
                                : 'Paid',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: d.summary.outstanding > 0
                                  ? Theme.of(context).colorScheme.error
                                  : null,
                            ),
                          ),
                        ),
                      if (canRecord)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          child: FilledButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    RecordPaymentScreen(member: widget.member),
                              ),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Record payment'),
                          ),
                        ),
                      if (l.payments.isNotEmpty) const Divider(height: 1),
                      for (final v in l.payments.take(20))
                        PaymentTile(view: v, showPayer: false),
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
