import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/repositories/events_repository.dart';
import '../../data/repositories/finance_repository.dart';
import '../../domain/permissions.dart';
import '../auth/auth_cubit.dart';
import '../finance/record_expense_screen.dart';
import '../payments/record_payment_screen.dart';
import 'attendance_screen.dart';
import 'event_form_screen.dart';
import 'events_common.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});
  final String eventId;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late final _services = context.read<AppServices>();
  late final Stream<Event> _event = _services.events.watchEvent(widget.eventId);
  late final Stream<EventMoney> _money = _services.events.watchEventMoney(
    widget.eventId,
  );
  late final Stream<List<Payment>> _payments = _services.events
      .watchEventPayments(widget.eventId);
  late final Stream<List<ExpenseView>> _expenses = _services.finance
      .watchExpenses(eventId: widget.eventId);
  late final Stream<List<AttendanceEntry>> _attendance = _services.events
      .watchAttendance(widget.eventId);

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  Future<void> _setStatus(EventStatus s) async {
    final user = context.read<AuthCubit>().user!;
    await _services.events.setEventStatus(
      widget.eventId,
      s,
      user.actor(_services.deviceId),
    );
    if (s == EventStatus.cancelled) {
      await _services.reminders.cancel(reminderId(widget.eventId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit c) => c.user);
    final canManage = user?.can(Perm.eventsManage) ?? false;
    final canCollect = user?.can(Perm.paymentsRecord) ?? false;
    final canSpend = user?.can(Perm.expensesRecord) ?? false;
    final canAttend = (user?.can(Perm.attendanceRecord) ?? false) || canManage;
    final canSeeMoney =
        (user?.can(Perm.financeView) ?? false) || canCollect || canSpend;
    final text = Theme.of(context).textTheme;

    return StreamBuilder<Event>(
      stream: _event,
      builder: (context, snap) {
        final e = snap.data;
        if (e == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(e.name),
            actions: [
              if (canManage)
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _open(EventFormScreen(event: e)),
                ),
              if (canManage)
                PopupMenuButton<EventStatus>(
                  tooltip: 'Status',
                  onSelected: _setStatus,
                  itemBuilder: (_) => [
                    for (final s in EventStatus.values)
                      if (s != e.status)
                        PopupMenuItem(
                          value: s,
                          child: Text('Mark as ${s.label.toLowerCase()}'),
                        ),
                  ],
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(e.kind.label, style: text.labelLarge),
              const SizedBox(height: 4),
              Text(formatDateTime(e.startsOn), style: text.titleMedium),
              if (e.venue != null) Text(e.venue!),
              const SizedBox(height: 4),
              Chip(label: Text(e.status.label)),
              if (e.description != null) ...[
                const SizedBox(height: 8),
                Text(e.description!),
              ],
              if (canSeeMoney) ...[
                const SizedBox(height: 16),
                Text('Money', style: text.titleMedium),
                StreamBuilder<EventMoney>(
                  stream: _money,
                  builder: (context, snap) {
                    final m = snap.data;
                    if (m == null) return const LinearProgressIndicator();
                    return Column(
                      children: [
                        if (e.budget != null)
                          InfoRow('Budget', formatMoney(e.budget!)),
                        InfoRow(
                          'Collected',
                          '${formatMoney(m.collected)} '
                              '(${m.collections} receipts)',
                        ),
                        InfoRow(
                          'Spent',
                          '${formatMoney(m.spent)} (${m.expenses} vouchers)',
                        ),
                        InfoRow('Balance', formatMoney(m.balance)),
                        if (e.budget != null)
                          InfoRow(
                            'Budget left',
                            formatMoney(e.budget! - m.spent),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (canCollect)
                      FilledButton.tonalIcon(
                        onPressed: () => _open(RecordPaymentScreen(event: e)),
                        icon: const Icon(Icons.add_card),
                        label: const Text('Collect money'),
                      ),
                    if (canSpend)
                      OutlinedButton.icon(
                        onPressed: () => _open(
                          RecordExpenseScreen(eventId: e.id, eventName: e.name),
                        ),
                        icon: const Icon(Icons.outbox),
                        label: const Text('Record expense'),
                      ),
                  ],
                ),
                StreamBuilder<List<Payment>>(
                  stream: _payments,
                  builder: (context, snap) => Column(
                    children: [
                      for (final p in (snap.data ?? const <Payment>[]).take(20))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.call_received),
                          title: Text(p.receiptNo),
                          subtitle: Text(formatDate(p.paidOn)),
                          trailing: Text(
                            formatMoney(p.amount),
                            style: p.status == PaymentStatus.voided
                                ? const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
                StreamBuilder<List<ExpenseView>>(
                  stream: _expenses,
                  builder: (context, snap) => Column(
                    children: [
                      for (final v in snap.data ?? const <ExpenseView>[])
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.call_made),
                          title: Text(v.expense.description),
                          subtitle: Text(
                            '${v.expense.voucherNo}, ${v.category.name}',
                          ),
                          trailing: Text(
                            formatMoney(v.expense.amount),
                            style: v.expense.status == PaymentStatus.voided
                                ? const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text('Attendance', style: text.titleMedium),
              StreamBuilder<List<AttendanceEntry>>(
                stream: _attendance,
                builder: (context, snap) {
                  final c = EventsRepository.count(snap.data ?? const []);
                  return Text(
                    '${c.present} present, ${c.absent} absent, '
                    '${c.excused} excused',
                  );
                },
              ),
              if (canAttend) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () =>
                      _open(AttendanceScreen(occasionId: e.id, title: e.name)),
                  icon: const Icon(Icons.how_to_reg),
                  label: const Text('Take attendance'),
                ),
              ],
              if (e.transportNotes != null) ...[
                const SizedBox(height: 16),
                Text('Transport', style: text.titleMedium),
                Text(e.transportNotes!),
              ],
              if (e.accommodationNotes != null) ...[
                const SizedBox(height: 16),
                Text('Accommodation', style: text.titleMedium),
                Text(e.accommodationNotes!),
              ],
            ],
          ),
        );
      },
    );
  }
}
