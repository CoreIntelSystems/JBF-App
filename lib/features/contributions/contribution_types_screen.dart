import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/repositories/payment_repository.dart';
import '../../domain/permissions.dart';
import '../auth/auth_cubit.dart';

/// What members contribute towards, and the amounts. Editable by the
/// Founder, Treasurer and General Secretary.
class ContributionTypesScreen extends StatefulWidget {
  const ContributionTypesScreen({super.key});

  @override
  State<ContributionTypesScreen> createState() =>
      _ContributionTypesScreenState();
}

class _ContributionTypesScreenState extends State<ContributionTypesScreen> {
  late final Stream<List<ContributionType>> _types = context
      .read<AppServices>()
      .payments
      .watchTypes();

  void _edit(ContributionType? t) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ContributionTypeForm(existing: t)),
  );

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit c) => c.user);
    final canEdit = user?.can(Perm.duesManage) ?? false;
    final canApprove = user?.can(Perm.duesApprove) ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Contribution types')),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              tooltip: 'Add type',
              onPressed: () => _edit(null),
              child: const Icon(Icons.add),
            )
          : null,
      body: StreamBuilder<List<ContributionType>>(
        stream: _types,
        builder: (context, snap) {
          final items = snap.data;
          if (items == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              if (!canEdit)
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text(
                    'Only the Founder or Treasurer can change these. A new '
                    'amount from the Treasurer is approved by the Founder '
                    'or General Secretary.',
                  ),
                ),
              for (final t in items)
                ListTile(
                  title: Text(t.name),
                  subtitle: Text(
                    [
                      t.category.label,
                      t.frequency.label,
                      if (!t.appliesToAll) 'Executives only',
                      if (!t.isActive) 'Not in use',
                    ].join(' · '),
                  ),
                  trailing: Text(
                    t.amount == null
                        ? (t.frequency == ContributionFrequency.monthly
                              ? 'Not set'
                              : 'Any amount')
                        : formatMoney(t.amount!),
                    style:
                        t.amount == null &&
                            t.frequency == ContributionFrequency.monthly
                        ? TextStyle(color: Theme.of(context).colorScheme.error)
                        : null,
                  ),
                  onTap: canEdit ? () => _edit(t) : null,
                ),
              for (final t in items.where((t) => t.proposedAmount != null))
                _Proposal(type: t, canApprove: canApprove),
            ],
          );
        },
      ),
    );
  }
}

/// A new amount waiting for approval.
class _Proposal extends StatelessWidget {
  const _Proposal({required this.type, required this.canApprove});
  final ContributionType type;
  final bool canApprove;

  Future<void> _decide(BuildContext context, bool approve) async {
    final services = context.read<AppServices>();
    final user = context.read<AuthCubit>().user!;
    try {
      await services.payments.decideAmount(
        type.id,
        approve: approve,
        byName: user.displayName,
        actor: user.actor(services.deviceId),
      );
    } on PaymentException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = type;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${t.name}: new amount waiting for approval',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${formatMoney(t.proposedAmount!)} '
              '(now ${t.amount == null ? 'not set' : formatMoney(t.amount!)}), '
              'proposed by ${t.proposedByName ?? 'the Treasurer'}'
              '${t.proposedAt == null ? '' : ' on ${formatDate(t.proposedAt)}'}.',
            ),
            if (canApprove) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton(
                    onPressed: () => _decide(context, true),
                    child: const Text('Approve'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _decide(context, false),
                    child: const Text('Reject'),
                  ),
                ],
              ),
            ] else
              const Text('The Founder or General Secretary approves it.'),
          ],
        ),
      ),
    );
  }
}

class ContributionTypeForm extends StatefulWidget {
  const ContributionTypeForm({super.key, this.existing});
  final ContributionType? existing;

  @override
  State<ContributionTypeForm> createState() => _ContributionTypeFormState();
}

class _ContributionTypeFormState extends State<ContributionTypeForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _amount = TextEditingController(
    text: widget.existing?.amount == null
        ? ''
        : moneyInput(widget.existing!.amount!),
  );
  late final _notes = TextEditingController(text: widget.existing?.notes);
  late ContributionCategory _category =
      widget.existing?.category ?? ContributionCategory.voluntary;
  late ContributionFrequency _frequency =
      widget.existing?.frequency ?? ContributionFrequency.open;
  late bool _active = widget.existing?.isActive ?? true;
  late bool _appliesToAll = widget.existing?.appliesToAll ?? true;
  late DateTime? _start = widget.existing?.startDate;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _start ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (d != null) setState(() => _start = DateTime(d.year, d.month));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final services = context.read<AppServices>();
    final user = context.read<AuthCubit>().user!;
    final amountText = _amount.text.trim();
    final notes = _notes.text.trim();
    setState(() => _saving = true);
    try {
      await services.payments.saveType(
        widget.existing?.id,
        ContributionTypesCompanion(
          name: Value(_name.text.trim()),
          category: Value(_category),
          frequency: Value(_frequency),
          amount: Value(amountText.isEmpty ? null : parseMoney(amountText)),
          startDate: Value(_start),
          isActive: Value(_active),
          appliesToAll: Value(_appliesToAll),
          notes: Value(notes.isEmpty ? null : notes),
        ),
        user.actor(services.deviceId),
        proposedBy: user.can(Perm.duesApprove) ? null : user.displayName,
      );
      if (mounted) Navigator.of(context).pop();
    } on PaymentException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthly = _frequency == ContributionFrequency.monthly;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New type' : 'Edit type'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ContributionCategory>(
              isExpanded: true,
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in ContributionCategory.values)
                  DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: (c) => setState(() => _category = c!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ContributionFrequency>(
              isExpanded: true,
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: 'How often'),
              items: [
                for (final f in ContributionFrequency.values)
                  DropdownMenuItem(value: f, child: Text(f.label)),
              ],
              onChanged: (f) => setState(() => _frequency = f!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              decoration: InputDecoration(
                labelText: monthly ? 'Amount per month' : 'Fixed amount',
                helperText: monthly
                    ? 'Members build arrears from their join date once set'
                    : 'Leave empty for any amount',
                prefixText: 'GHS ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                final a = parseMoney(t);
                return a == null || a <= 0 ? 'Enter a valid amount' : null;
              },
            ),
            if (monthly) ...[
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: const Text('Dues start from'),
                subtitle: Text(
                  _start == null
                      ? 'Each member\'s join date'
                      : formatPeriod(
                          '${_start!.year}-${_start!.month.toString().padLeft(2, '0')}',
                        ),
                ),
                trailing: _start == null
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _start = null),
                      ),
                onTap: _pickStart,
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Applies to every member'),
              subtitle: const Text('Off for executive-only dues'),
              value: _appliesToAll,
              onChanged: (v) => setState(() => _appliesToAll = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('In use'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
