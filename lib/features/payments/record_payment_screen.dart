import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/repositories/payment_repository.dart';
import '../../domain/dues.dart';
import '../auth/auth_cubit.dart';
import '../members/member_picker.dart';
import 'payment_detail_screen.dart';

/// Records money received and issues a receipt.
class RecordPaymentScreen extends StatefulWidget {
  const RecordPaymentScreen({super.key, this.member, this.event});

  /// Pre-selected payer, when opened from a member's page.
  final Member? member;

  /// Set when collecting money for an event.
  final Event? event;

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _remarks = TextEditingController();

  List<ContributionType>? _types;
  Member? _member;
  ContributionType? _type;
  String? _period;
  PaymentMethod _method = PaymentMethod.cash;
  DateTime _paidOn = DateTime.now();
  DuesSummary? _dues;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _member = widget.member;
    context.read<AppServices>().payments.activeTypes().then((types) {
      if (!mounted) return;
      setState(() {
        _types = types;
        // Most payments are monthly dues, so start there; event
        // collections start at the per-event types.
        _type = widget.event != null
            ? types
                  .where((t) => t.frequency == ContributionFrequency.perEvent)
                  .lastOrNull
            : types
                  .where((t) => t.frequency == ContributionFrequency.monthly)
                  .where((t) => t.appliesToAll)
                  .firstOrNull;
      });
      _refreshDues();
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _remarks.dispose();
    super.dispose();
  }

  bool get _isMonthly => _type?.frequency == ContributionFrequency.monthly;

  /// Months offered for a monthly payment: two years back to one ahead.
  List<String> get _periodChoices {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month - 24);
    final to = DateTime(now.year, now.month + 12);
    final all = Dues.months(from, to).reversed.toList();
    if (_period != null && !all.contains(_period)) all.add(_period!);
    return all;
  }

  Future<void> _refreshDues() async {
    final type = _type;
    if (type?.amount != null && _amount.text.isEmpty) {
      _amount.text = moneyInput(type!.amount!);
    }
    if (!_isMonthly) {
      setState(() {
        _dues = null;
        _period = null;
      });
      return;
    }
    DuesSummary? dues;
    final member = _member;
    if (member != null && type != null) {
      dues = await context.read<AppServices>().payments.duesFor(
        member.id,
        type.id,
      );
    }
    if (!mounted) return;
    setState(() {
      _dues = dues;
      _period =
          dues?.nextUnpaidPeriod ?? _period ?? Dues.periodOf(DateTime.now());
    });
  }

  Future<void> _pickMember() async {
    final picked = await Navigator.of(
      context,
    ).push<Member>(MaterialPageRoute(builder: (_) => const MemberPicker()));
    if (picked == null) return;
    setState(() => _member = picked);
    _refreshDues();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _paidOn,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (d != null) setState(() => _paidOn = d);
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final type = _type;
    if (type == null) {
      setState(() => _error = 'Choose what the payment is for.');
      return;
    }
    final services = context.read<AppServices>();
    final user = context.read<AuthCubit>().user!;
    setState(() => _saving = true);
    try {
      final p = await services.payments.record(
        PaymentDraft(
          memberId: _member?.id,
          contributionTypeId: type.id,
          amount: parseMoney(_amount.text)!,
          method: _method,
          paidOn: _paidOn,
          period: _isMonthly ? _period : null,
          reference: _reference.text,
          remarks: _remarks.text,
          eventId: widget.event?.id,
        ),
        user.actor(services.deviceId),
        collectorName: user.displayName,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PaymentDetailScreen(paymentId: p.id, justSaved: true),
        ),
      );
    } on PaymentException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = _types;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.event == null
              ? 'Record payment'
              : 'Collect for ${widget.event!.name}',
        ),
      ),
      body: types == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.person_search),
                      title: Text(_member?.fullName ?? 'Choose member'),
                      subtitle: Text(
                        _member?.memberNo ??
                            (_isMonthly
                                ? 'Required for monthly dues'
                                : 'Leave empty for an anonymous donation'),
                      ),
                      trailing: _member != null && widget.member == null
                          ? IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _member = null;
                                  _dues = null;
                                });
                              },
                            )
                          : null,
                      onTap: widget.member == null ? _pickMember : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<ContributionType>(
                    isExpanded: true,
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'For'),
                    items: [
                      for (final t in types)
                        DropdownMenuItem(value: t, child: Text(t.name)),
                    ],
                    onChanged: (t) {
                      setState(() {
                        _type = t;
                        _amount.clear();
                      });
                      _refreshDues();
                    },
                  ),
                  if (_isMonthly) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      key: ValueKey('period-$_period'),
                      initialValue: _period,
                      decoration: const InputDecoration(
                        labelText: 'Month paid for',
                      ),
                      items: [
                        for (final p in _periodChoices)
                          DropdownMenuItem(
                            value: p,
                            child: Text(formatPeriod(p)),
                          ),
                      ],
                      onChanged: (p) => setState(() => _period = p),
                    ),
                    if (_type?.amount == null)
                      const _Hint(
                        'The monthly dues amount has not been set yet, so '
                        'arrears are not calculated. Set it under More > '
                        'Contribution types.',
                      )
                    else if (_dues != null)
                      _Hint(
                        _dues!.outstanding > 0
                            ? 'Owes ${formatMoney(_dues!.outstanding)} '
                                  '(${_dues!.monthsBehind} months).'
                            : 'Up to date with dues.',
                      ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amount,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: 'GHS ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      final a = parseMoney(v ?? '');
                      if (a == null || a <= 0) return 'Enter an amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<PaymentMethod>(
                    segments: [
                      for (final m in PaymentMethod.values)
                        ButtonSegment(value: m, label: Text(m.label)),
                    ],
                    selected: {_method},
                    onSelectionChanged: (s) =>
                        setState(() => _method = s.first),
                  ),
                  if (_method != PaymentMethod.cash) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _reference,
                      decoration: InputDecoration(
                        labelText: _method == PaymentMethod.momo
                            ? 'MoMo transaction ID'
                            : 'Bank reference',
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: const Text('Date received'),
                    subtitle: Text(formatDate(_paidOn)),
                    onTap: _pickDate,
                  ),
                  TextFormField(
                    controller: _remarks,
                    decoration: const InputDecoration(labelText: 'Remarks'),
                    maxLines: 2,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Save and issue receipt'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, left: 4),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}
