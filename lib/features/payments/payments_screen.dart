import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../data/repositories/payment_repository.dart';
import '../../domain/permissions.dart';
import '../auth/auth_cubit.dart';
import 'defaulters_screen.dart';
import 'payment_widgets.dart';
import 'record_payment_screen.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  late final Stream<List<PaymentView>> _recent = context
      .read<AppServices>()
      .payments
      .watchRecent(limit: 200);

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit c) => c.user);
    final canRecord = user?.can(Perm.paymentsRecord) ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
        actions: [
          IconButton(
            tooltip: 'Defaulters',
            icon: const Icon(Icons.warning_amber_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const DefaultersScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: canRecord
          ? FloatingActionButton.extended(
              heroTag: 'payments-fab',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RecordPaymentScreen(),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Record payment'),
            )
          : null,
      body: StreamBuilder<List<PaymentView>>(
        stream: _recent,
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
                  'No payments yet. Tap Record payment to issue the '
                  'first receipt.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) => PaymentTile(view: items[i]),
          );
        },
      ),
    );
  }
}
