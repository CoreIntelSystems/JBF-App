import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/repositories/payment_repository.dart';
import 'payment_detail_screen.dart';

/// One line in a payments list; opens the receipt.
class PaymentTile extends StatelessWidget {
  const PaymentTile({super.key, required this.view, this.showPayer = true});

  final PaymentView view;
  final bool showPayer;

  @override
  Widget build(BuildContext context) {
    final p = view.payment;
    final voided = p.status == PaymentStatus.voided;
    final purpose = p.period == null
        ? view.type.name
        : '${view.type.name} · ${formatPeriod(p.period)}';
    return ListTile(
      leading: CircleAvatar(
        child: Icon(voided ? Icons.block : Icons.receipt_long, size: 20),
      ),
      title: Text(showPayer ? view.payerName : purpose),
      subtitle: Text(
        [
          if (showPayer) purpose,
          '${p.receiptNo} · ${formatDate(p.paidOn)}',
          if (voided) 'VOIDED',
        ].join('\n'),
      ),
      isThreeLine: showPayer || voided,
      trailing: Text(
        formatMoney(p.amount),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          decoration: voided ? TextDecoration.lineThrough : null,
        ),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PaymentDetailScreen(paymentId: p.id),
        ),
      ),
    );
  }
}
