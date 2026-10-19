import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/format.dart';
import '../../core/money.dart';
import '../../core/org_config.dart';
import '../../data/sync/sync_api.dart';
import '../../data/sync/sync_service.dart';
import '../auth/brand_header.dart';

/// Lets an ordinary member check their own dues and receipts online with
/// their member ID and phone number, without an app account.
class MemberStatementScreen extends StatefulWidget {
  const MemberStatementScreen({super.key});

  @override
  State<MemberStatementScreen> createState() => _MemberStatementScreenState();
}

class _MemberStatementScreenState extends State<MemberStatementScreen> {
  final _memberNo = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;
  String? _error;
  MemberStatement? _statement;

  @override
  void dispose() {
    _memberNo.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final memberNo = _memberNo.text.trim();
    final phone = _phone.text.trim();
    if (memberNo.isEmpty || phone.isEmpty) {
      setState(() => _error = 'Enter your member ID and phone number.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final s = await context.read<SyncService>().api.memberStatement(
        OrgDefaults.shortName,
        memberNo,
        phone,
      );
      if (mounted) setState(() => _statement = s);
    } on SyncException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.offline
              ? 'No internet connection. Connect and try again.'
              : e.message,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _another() => setState(() {
    _statement = null;
    _memberNo.clear();
    _phone.clear();
  });

  @override
  Widget build(BuildContext context) {
    final s = _statement;
    return Scaffold(
      appBar: AppBar(title: const Text('Check my dues')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: s == null
                ? _form(context)
                : StatementView(s, onAnother: _another),
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BrandHeader(subtitle: 'Check your dues and receipts'),
        const SizedBox(height: 16),
        Text(
          'Enter your member ID and registered phone number.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('statementMemberNo'),
          controller: _memberNo,
          decoration: const InputDecoration(
            labelText: 'Member ID',
            hintText: 'e.g. JBF-000123',
          ),
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('statementPhone'),
          controller: _phone,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            hintText: 'e.g. 024 123 4567',
          ),
          keyboardType: TextInputType.phone,
          onSubmitted: (_) => _check(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _check,
          child: _busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('View my statement'),
        ),
      ],
    ),
  );
}

/// A member's dues and payments.
class StatementView extends StatelessWidget {
  const StatementView(this.s, {super.key, this.onAnother, this.header});

  final MemberStatement s;

  /// Shown as "Check another member" when set.
  final VoidCallback? onAnother;

  /// Shown above the statement.
  final Widget? header;

  static const _methods = {
    'cash': 'Cash',
    'momo': 'Mobile money',
    'bank': 'Bank',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Text(value),
        ],
      ),
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        ?header,
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, style: text.titleLarge),
                const SizedBox(height: 8),
                row('Member ID', s.memberNo),
                row('Zone', s.zones.isEmpty ? 'None' : s.zones.join(', ')),
                row('Member since', formatDate(s.joined)),
                row('Status', capitalize(s.status)),
              ],
            ),
          ),
        ),
        for (final d in s.dues)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.name, style: text.titleMedium),
                  const SizedBox(height: 4),
                  if (d.outstanding > 0) ...[
                    Text(
                      formatMoney(d.outstanding),
                      style: text.headlineSmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Owed: ${d.monthsBehind} month'
                      '${d.monthsBehind == 1 ? '' : 's'} behind, from '
                      '${formatPeriod(d.nextUnpaid)}.',
                    ),
                  ] else ...[
                    Text(
                      'Up to date',
                      style: text.headlineSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('Thank you for keeping your dues paid.'),
                  ],
                  const SizedBox(height: 8),
                  row('Monthly amount', formatMoney(d.monthly)),
                  row('Months due so far', '${d.months}'),
                  row('Expected', formatMoney(d.expected)),
                  row('Paid', formatMoney(d.paid)),
                ],
              ),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payments', style: text.titleMedium),
                if (s.payments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('No payments recorded yet.'),
                  ),
                for (final p in s.payments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.type ?? 'Payment'),
                    subtitle: Text(
                      [
                        formatDate(p.paidOn),
                        if (p.period != null) 'for ${formatPeriod(p.period)}',
                        _methods[p.method] ?? p.method ?? '',
                        p.receiptNo ?? '',
                      ].where((x) => x.isNotEmpty).join(' · '),
                    ),
                    trailing: Text(formatMoney(p.amount)),
                  ),
              ],
            ),
          ),
        ),
        if (s.updated != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Updated ${formatDateTime(s.updated!)}',
              style: text.bodySmall,
            ),
          ),
        if (onAnother != null)
          TextButton(
            onPressed: onAnother,
            child: const Text('Check another member'),
          ),
      ],
    );
  }
}
