import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/repositories/finance_repository.dart';
import '../auth/auth_cubit.dart';

class RecordExpenseScreen extends StatefulWidget {
  const RecordExpenseScreen({super.key, this.eventId, this.eventName});

  /// Set when recording spending for an event.
  final String? eventId;
  final String? eventName;

  @override
  State<RecordExpenseScreen> createState() => _RecordExpenseScreenState();
}

class _RecordExpenseScreenState extends State<RecordExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _paidTo = TextEditingController();
  final _reference = TextEditingController();
  List<ExpenseCategory>? _categories;
  ExpenseCategory? _category;
  PaymentMethod _method = PaymentMethod.cash;
  DateTime _paidOn = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? select}) async {
    final c = await context.read<AppServices>().finance.activeCategories();
    if (!mounted) return;
    setState(() {
      _categories = c;
      _category = select == null
          ? (widget.eventId != null ? c.firstOrNull : _category)
          : c.where((x) => x.name == select).firstOrNull;
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _paidTo.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    final services = context.read<AppServices>();
    final user = context.read<AuthCubit>().user!;
    final ctl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New category'),
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
    if (name == null || name.trim().isEmpty) return;
    await services.finance.addCategory(name, user.actor(services.deviceId));
    await _load(select: name.trim());
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (_category == null) {
      setState(() => _error = 'Choose a category.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final services = context.read<AppServices>();
    final user = context.read<AuthCubit>().user!;
    setState(() => _saving = true);
    try {
      await services.finance.recordExpense(
        ExpenseDraft(
          categoryId: _category!.id,
          amount: parseMoney(_amount.text)!,
          description: _description.text,
          method: _method,
          paidOn: _paidOn,
          paidTo: _paidTo.text,
          reference: _reference.text,
          eventId: widget.eventId,
        ),
        user.actor(services.deviceId),
        recordedByName: user.displayName,
      );
      if (mounted) Navigator.of(context).pop();
    } on FinanceException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categories;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.eventName == null
              ? 'Record expense'
              : 'Expense: ${widget.eventName}',
        ),
      ),
      body: categories == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<ExpenseCategory>(
                    key: ValueKey(_category?.id),
                    initialValue: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      for (final c in categories)
                        DropdownMenuItem(value: c, child: Text(c.name)),
                    ],
                    onChanged: (c) => setState(() => _category = c),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _addCategory,
                      icon: const Icon(Icons.add),
                      label: const Text('New category'),
                    ),
                  ),
                  TextFormField(
                    controller: _description,
                    decoration: const InputDecoration(
                      labelText: 'What was it for?',
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Describe the expense'
                        : null,
                  ),
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
                      return a == null || a <= 0 ? 'Enter an amount' : null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _paidTo,
                    decoration: const InputDecoration(
                      labelText: 'Paid to (optional)',
                    ),
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
                      decoration: const InputDecoration(
                        labelText: 'Transaction ID or reference',
                      ),
                    ),
                  ],
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: const Text('Date paid'),
                    subtitle: Text(formatDate(_paidOn)),
                    onTap: () async {
                      final now = DateTime.now();
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _paidOn,
                        firstDate: DateTime(now.year - 5),
                        lastDate: now,
                      );
                      if (d != null) setState(() => _paidOn = d);
                    },
                  ),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: const Text('Save expense'),
                  ),
                ],
              ),
            ),
    );
  }
}
