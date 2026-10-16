import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/welfare_repository.dart';
import '../../domain/permissions.dart';
import '../auth/auth_cubit.dart';
import '../members/member_detail_screen.dart';
import 'welfare_common.dart';

/// One welfare case: details, who did what, and the next action for the
/// signed-in user (approve or reject, then pay).
class CaseDetailScreen extends StatefulWidget {
  const CaseDetailScreen({super.key, required this.caseId});

  final String caseId;

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  late final Stream<WelfareCaseView?> _view = context
      .read<AppServices>()
      .welfare
      .watchCase(widget.caseId);
  Future<MemberLedger>? _ledger;
  bool _busy = false;

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  /// Runs [action]; the page itself shows the new status, so only errors
  /// get a message.
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on WelfareException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decide(WelfareCaseView v, {required bool approve}) async {
    final services = context.read<AppServices>();
    final user = context.read<AuthCubit>().user!;
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Approve this case?' : 'Reject this case?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${v.member.fullName}: ${v.type.name}, '
              '${formatMoney(v.welfareCase.amount)}',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              autofocus: !approve,
              decoration: InputDecoration(
                labelText: approve ? 'Comment (optional)' : 'Reason',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => services.welfare.decideCase(
        v.welfareCase.id,
        user.welfareActor(services.deviceId),
        approve: approve,
        note: note.text,
      ),
    );
  }

  Future<void> _pay(WelfareCaseView v) async {
    final services = context.read<AppServices>();
    final user = context.read<AuthCubit>().user!;
    final result = await showDialog<(PaymentMethod, String, DateTime)>(
      context: context,
      builder: (_) => _PayDialog(amount: v.welfareCase.amount),
    );
    if (result == null) return;
    final (method, reference, paidOn) = result;
    await _run(
      () => services.welfare.markPaid(
        v.welfareCase.id,
        user.welfareActor(services.deviceId),
        method: method,
        paidOn: paidOn,
        reference: reference,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit c) => c.user);
    final canApprove = user?.can(Perm.welfareApprove) ?? false;
    final canPay = user?.can(Perm.welfarePay) ?? false;
    return StreamBuilder<WelfareCaseView?>(
      stream: _view,
      builder: (context, snap) {
        final v = snap.data;
        if (v == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        _ledger ??= context.read<AppServices>().payments.ledger(v.member.id);
        final c = v.welfareCase;
        final standIn =
            c.decidedByRole != null &&
            c.decidedByRole != 'Welfare Chairman' &&
            c.decidedByRole != 'Super Administrator';
        return Scaffold(
          appBar: AppBar(title: Text(c.caseNo)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      v.type.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  WelfareStatusChip(status: c.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                formatMoney(c.amount),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                c.amountIsFixed
                    ? 'Fixed benefit amount'
                    : 'Amount requested (no fixed amount set)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  title: Text(v.member.fullName),
                  subtitle: FutureBuilder<MemberLedger>(
                    future: _ledger,
                    builder: (context, s) {
                      final l = s.data;
                      final parts = [
                        v.member.memberNo,
                        capitalize(v.member.status.name),
                        if (l != null)
                          l.outstanding > 0
                              ? 'owes ${formatMoney(l.outstanding)} in dues'
                              : 'dues up to date',
                      ];
                      return Text(parts.join(' · '));
                    },
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MemberDetailScreen(memberId: v.member.id),
                    ),
                  ),
                ),
              ),
              _Details([
                ('Happened on', formatDate(c.occurredOn)),
                if (c.beneficiary != null) ('For', c.beneficiary!),
                if (c.description != null) ('Details', c.description!),
                (
                  'Reported by',
                  '${c.preparedByName}, ${formatDate(c.createdAt)}',
                ),
                if (c.decidedByName != null)
                  (
                    c.status == WelfareStatus.rejected
                        ? 'Rejected by'
                        : 'Approved by',
                    '${c.decidedByName} (${c.decidedByRole}'
                        '${standIn ? ', standing in for the Chairman' : ''}), '
                        '${formatDate(c.decidedAt)}',
                  ),
                if (c.decisionNote != null) ('Comment', c.decisionNote!),
                if (c.status == WelfareStatus.paid) ...[
                  (
                    'Paid',
                    '${formatDate(c.paidOn)} by ${c.paidByName}, '
                        '${c.payMethod?.label ?? ''}',
                  ),
                  if (c.payReference != null) ('Reference', c.payReference!),
                ],
              ]),
              const SizedBox(height: 24),
              if (c.status == WelfareStatus.pending && canApprove) ...[
                FilledButton.icon(
                  onPressed: _busy ? null : () => _decide(v, approve: true),
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _decide(v, approve: false),
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                ),
              ] else if (c.status == WelfareStatus.pending)
                const _Note(
                  'Waiting for the Welfare Chairman, or the General '
                  'Secretary when the Chairman is away.',
                ),
              if (c.status == WelfareStatus.approved && canPay)
                FilledButton.icon(
                  onPressed: _busy ? null : () => _pay(v),
                  icon: const Icon(Icons.payments),
                  label: const Text('Record payout'),
                )
              else if (c.status == WelfareStatus.approved)
                const _Note('Approved. Waiting for the Treasurer to pay out.'),
            ],
          ),
        );
      },
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: Padding(padding: const EdgeInsets.all(16), child: Text(text)),
  );
}

class _Details extends StatelessWidget {
  const _Details(this.rows);
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Expanded(flex: 3, child: Text(value)),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _PayDialog extends StatefulWidget {
  const _PayDialog({required this.amount});
  final int amount;

  @override
  State<_PayDialog> createState() => _PayDialogState();
}

class _PayDialogState extends State<_PayDialog> {
  PaymentMethod _method = PaymentMethod.momo;
  final _reference = TextEditingController();
  DateTime _paidOn = DateTime.now();

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Pay out ${formatMoney(widget.amount)}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<PaymentMethod>(
              isExpanded: true,
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Paid by'),
              items: [
                for (final m in PaymentMethod.values)
                  DropdownMenuItem(value: m, child: Text(m.label)),
              ],
              onChanged: (m) => setState(() => _method = m!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reference,
              decoration: const InputDecoration(
                labelText: 'Reference (optional)',
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date paid'),
              subtitle: Text(formatDate(_paidOn)),
              onTap: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  initialDate: _paidOn,
                  firstDate: DateTime(now.year - 1),
                  lastDate: now,
                );
                if (d != null) setState(() => _paidOn = d);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop((_method, _reference.text, _paidOn)),
          child: const Text('Mark as paid'),
        ),
      ],
    );
  }
}
