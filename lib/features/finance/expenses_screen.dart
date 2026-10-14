import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/repositories/finance_repository.dart';
import '../../domain/permissions.dart';
import '../auth/auth_cubit.dart';
import '../reports/reports_screen.dart';
import 'record_expense_screen.dart';

/// Money spent, newest first, with void for mistakes.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  late final Stream<List<ExpenseView>> _items = context
      .read<AppServices>()
      .finance
      .watchExpenses();

  Future<void> _show(ExpenseView v) async {
    final user = context.read<AuthCubit>().user!;
    final services = context.read<AppServices>();
    final e = v.expense;
    final voided = e.status == PaymentStatus.voided;
    final doVoid = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(e.voucherNo, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              formatMoney(e.amount),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                decoration: voided ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(height: 8),
            Text('${v.category.name}: ${e.description}'),
            if (e.paidTo != null) Text('Paid to ${e.paidTo}'),
            Text(
              '${formatDate(e.paidOn)} · ${e.method.label}'
              '${e.reference == null ? '' : ' · ${e.reference}'}',
            ),
            Text('Recorded by ${e.recordedByName}'),
            if (voided) ...[
              const SizedBox(height: 8),
              Text(
                'VOIDED: ${e.voidReason ?? ''}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (!voided && user.can(Perm.paymentsVoid)) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.block),
                label: const Text('Void this expense'),
              ),
            ],
          ],
        ),
      ),
    );
    if (doVoid != true || !mounted) return;
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Void this expense?'),
        content: TextField(
          controller: reason,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Void'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await services.finance.voidExpense(
        e.id,
        reason.text,
        user.actor(services.deviceId),
      );
    } on FinanceException catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(err.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit c) => c.user);
    final canRecord = user?.can(Perm.expensesRecord) ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            tooltip: 'Reports',
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ReportsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: canRecord
          ? FloatingActionButton.extended(
              heroTag: 'expenses-fab',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RecordExpenseScreen(),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Record expense'),
            )
          : null,
      body: StreamBuilder<List<ExpenseView>>(
        stream: _items,
        builder: (context, snap) {
          final items = snap.data;
          if (items == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No expenses yet. Welfare payouts are recorded on the '
                  'welfare case and appear in reports automatically.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final v = items[i];
              final e = v.expense;
              final voided = e.status == PaymentStatus.voided;
              return ListTile(
                leading: CircleAvatar(
                  child: Icon(voided ? Icons.block : Icons.outbox, size: 20),
                ),
                title: Text(e.description),
                subtitle: Text(
                  '${v.category.name}\n${e.voucherNo} · ${formatDate(e.paidOn)}'
                  '${voided ? ' · VOIDED' : ''}',
                ),
                isThreeLine: true,
                trailing: Text(
                  formatMoney(e.amount),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: voided ? TextDecoration.lineThrough : null,
                  ),
                ),
                onTap: () => _show(v),
              );
            },
          );
        },
      ),
    );
  }
}
