import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/repositories/member_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../domain/dues.dart';
import '../auth/auth_cubit.dart';

/// Tick off everyone who paid at a meeting and save all receipts at once.
class BatchPaymentScreen extends StatefulWidget {
  const BatchPaymentScreen({super.key});

  @override
  State<BatchPaymentScreen> createState() => _BatchPaymentScreenState();
}

class _BatchPaymentScreenState extends State<BatchPaymentScreen> {
  final _amount = TextEditingController();
  List<ContributionType>? _types;
  List<Zone> _zones = const [];
  ContributionType? _type;
  String? _zoneId;
  String _period = Dues.periodOf(DateTime.now());
  PaymentMethod _method = PaymentMethod.cash;
  late Stream<List<MemberWithZones>> _members = _watch();

  /// Member id -> amount in pesewas for those ticked.
  final Map<String, int> _ticked = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final services = context.read<AppServices>();
    services.payments.activeTypes().then((t) {
      if (!mounted) return;
      setState(() {
        _types = t;
        _type = t
            .where(
              (x) =>
                  x.frequency == ContributionFrequency.monthly &&
                  x.appliesToAll,
            )
            .firstOrNull;
        _syncAmount();
      });
    });
    services.members.zones().then((z) {
      if (mounted) setState(() => _zones = z.where((x) => x.isActive).toList());
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Stream<List<MemberWithZones>> _watch() => context
      .read<AppServices>()
      .members
      .watchMembers(MemberFilter(zoneId: _zoneId, status: MemberStatus.active));

  void _syncAmount() {
    final a = _type?.amount;
    _amount.text = a == null ? '' : moneyInput(a);
  }

  int? get _defaultAmount => parseMoney(_amount.text);

  bool get _monthly => _type?.frequency == ContributionFrequency.monthly;

  Future<void> _editAmount(Member m) async {
    final ctl = TextEditingController(
      text: moneyInput(_ticked[m.id] ?? _defaultAmount ?? 0),
    );
    final v = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(m.fullName),
        content: TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Amount paid',
            prefixText: 'GHS ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(parseMoney(ctl.text)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (v != null && v > 0) setState(() => _ticked[m.id] = v);
  }

  Future<void> _save() async {
    final type = _type;
    if (type == null || _ticked.isEmpty) return;
    final services = context.read<AppServices>();
    final user = context.read<AuthCubit>().user!;
    final total = _ticked.values.fold(0, (a, b) => a + b);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Save ${_ticked.length} payments?'),
        content: Text(
          '${type.name}${_monthly ? ' for ${formatPeriod(_period)}' : ''}\n'
          'Total ${formatMoney(total)} by ${_method.label.toLowerCase()}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final saved = await services.payments.recordBatch(
        [
          for (final MapEntry(key: id, value: amount) in _ticked.entries)
            PaymentDraft(
              memberId: id,
              contributionTypeId: type.id,
              amount: amount,
              method: _method,
              paidOn: now,
              period: _monthly ? _period : null,
              remarks: 'Recorded at a meeting',
            ),
        ],
        user.actor(services.deviceId),
        collectorName: user.displayName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved ${saved.length} receipts '
            '(${saved.first.receiptNo} to ${saved.last.receiptNo})',
          ),
        ),
      );
      Navigator.of(context).pop();
    } on PaymentException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = _types;
    final total = _ticked.values.fold(0, (a, b) => a + b);
    final now = DateTime.now();
    final periods = Dues.months(
      DateTime(now.year, now.month - 12),
      DateTime(now.year, now.month + 3),
    ).reversed.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Meeting collection')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: _saving || _ticked.isEmpty ? null : _save,
            child: Text(
              _ticked.isEmpty
                  ? 'Tick the members who paid'
                  : 'Save ${_ticked.length} · ${formatMoney(total)}',
            ),
          ),
        ),
      ),
      body: types == null
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.list(
                    children: [
                      DropdownButtonFormField<ContributionType>(
                        initialValue: _type,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'For'),
                        items: [
                          for (final t in types)
                            DropdownMenuItem(value: t, child: Text(t.name)),
                        ],
                        onChanged: (t) => setState(() {
                          _type = t;
                          _syncAmount();
                        }),
                      ),
                      if (_monthly) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _period,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Month'),
                          items: [
                            for (final p in periods)
                              DropdownMenuItem(
                                value: p,
                                child: Text(formatPeriod(p)),
                              ),
                          ],
                          onChanged: (p) => setState(() => _period = p!),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: _amount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Amount each',
                          prefixText: 'GHS ',
                          helperText: 'Tap a ticked amount to change it',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        initialValue: _zoneId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Zone'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All zones'),
                          ),
                          for (final z in _zones)
                            DropdownMenuItem(
                              value: z.id,
                              child: Text(zoneDisplayName(z)),
                            ),
                        ],
                        onChanged: (z) => setState(() {
                          _zoneId = z;
                          _members = _watch();
                        }),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<PaymentMethod>(
                        segments: [
                          for (final m in PaymentMethod.values)
                            ButtonSegment(value: m, label: Text(m.label)),
                        ],
                        selected: {_method},
                        onSelectionChanged: (s) =>
                            setState(() => _method = s.first),
                      ),
                    ],
                  ),
                ),
                StreamBuilder<List<MemberWithZones>>(
                  stream: _members,
                  builder: (context, snap) {
                    final items = snap.data ?? const [];
                    return SliverList.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final m = items[i].member;
                        final amount = _ticked[m.id];
                        return CheckboxListTile(
                          value: amount != null,
                          title: Text(m.fullName),
                          subtitle: Text(m.memberNo),
                          secondary: amount == null
                              ? null
                              : TextButton(
                                  onPressed: () => _editAmount(m),
                                  child: Text(formatMoney(amount)),
                                ),
                          onChanged: (on) {
                            if (on == true) {
                              final a = _defaultAmount;
                              if (a == null || a <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Enter the amount first.'),
                                  ),
                                );
                                return;
                              }
                              setState(() => _ticked[m.id] = a);
                            } else {
                              setState(() => _ticked.remove(m.id));
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ),
    );
  }
}
