import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/repositories/payment_repository.dart';
import '../../domain/permissions.dart';
import '../auth/auth_cubit.dart';
import 'receipt_pdf.dart';

/// A payment's receipt, with share, print and void.
class PaymentDetailScreen extends StatefulWidget {
  const PaymentDetailScreen({
    super.key,
    required this.paymentId,
    this.justSaved = false,
  });

  final String paymentId;
  final bool justSaved;

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  late final Stream<PaymentView?> _view = context
      .read<AppServices>()
      .payments
      .watchPayment(widget.paymentId);

  Future<void> _share(PaymentView v, {bool print = false}) async {
    final payments = context.read<AppServices>().payments;
    final org = await payments.org();
    final bytes = await buildReceiptPdf(v, org);
    final name = 'receipt-${v.payment.receiptNo}.pdf';
    if (print) {
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
    } else {
      await Printing.sharePdf(bytes: bytes, filename: name);
    }
  }

  Future<void> _void(PaymentView v) async {
    final services = context.read<AppServices>();
    final user = context.read<AuthCubit>().user!;
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Void this receipt?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The payment stops counting towards totals. The receipt stays '
              'on record marked VOID and this is written to the audit log.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Reason'),
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
            child: const Text('Void receipt'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await services.payments.voidPayment(
        v.payment.id,
        reason.text,
        user.actor(services.deviceId),
      );
    } on PaymentException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit c) => c.user);
    final canVoid = user?.can(Perm.paymentsVoid) ?? false;
    return StreamBuilder<PaymentView?>(
      stream: _view,
      builder: (context, snap) {
        final v = snap.data;
        if (v == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final p = v.payment;
        final voided = p.status == PaymentStatus.voided;
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(
            title: Text(p.receiptNo),
            actions: [
              if (canVoid && !voided)
                PopupMenuButton<String>(
                  onSelected: (_) => _void(v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'void', child: Text('Void receipt')),
                  ],
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.justSaved && !voided)
                Card(
                  color: scheme.primaryContainer,
                  child: const ListTile(
                    leading: Icon(Icons.check_circle),
                    title: Text('Payment saved'),
                    subtitle: Text('Share the receipt with the member below.'),
                  ),
                ),
              if (voided)
                Card(
                  color: scheme.errorContainer,
                  child: ListTile(
                    leading: const Icon(Icons.block),
                    title: const Text('This receipt was voided'),
                    subtitle: Text(
                      '${p.voidReason ?? ''}\n${formatDate(p.voidedAt)}',
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  formatMoney(p.amount),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    decoration: voided ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      _Row('Received from', v.payerName),
                      if (v.member != null)
                        _Row('Member ID', v.member!.memberNo),
                      _Row('For', v.type.name),
                      if (p.period != null)
                        _Row('Month', formatPeriod(p.period)),
                      _Row('Method', p.method.label),
                      if (p.reference != null) _Row('Reference', p.reference!),
                      _Row('Date', formatDate(p.paidOn)),
                      _Row('Collected by', p.collectorName),
                      if (p.remarks != null) _Row('Remarks', p.remarks!),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _share(v),
                icon: const Icon(Icons.share),
                label: const Text('Share receipt (PDF)'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _share(v, print: true),
                icon: const Icon(Icons.print),
                label: const Text('Print'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(flex: 3, child: Text(value)),
      ],
    ),
  );
}
