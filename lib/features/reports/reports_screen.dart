import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/money.dart';
import '../../core/share_file.dart';
import '../../data/repositories/finance_repository.dart';
import '../../domain/permissions.dart';
import '../auth/auth_cubit.dart';
import 'report_export.dart';

/// Daily, weekly, monthly and annual financial reports with exports.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.month;
  DateTime _anchor = DateTime.now();
  late Future<FinanceReport> _report = _load();
  bool _exporting = false;

  Future<FinanceReport> _load() {
    final (from, to) = _period.rangeFor(_anchor);
    return context.read<AppServices>().finance.report(
      from,
      to,
      title: _period.label,
    );
  }

  void _reload() => setState(() => _report = _load());

  void _step(int dir) {
    final a = _anchor;
    _anchor = switch (_period) {
      ReportPeriod.day => a.add(Duration(days: dir)),
      ReportPeriod.week => a.add(Duration(days: 7 * dir)),
      ReportPeriod.month => DateTime(a.year, a.month + dir, 1),
      ReportPeriod.year => DateTime(a.year + dir, 1, 1),
    };
    _reload();
  }

  Future<void> _export(FinanceReport r, String kind) async {
    setState(() => _exporting = true);
    try {
      final org = await context.read<AppServices>().payments.org();
      final stem = reportFileStem(r);
      switch (kind) {
        case 'pdf':
          await shareBytes(
            await reportPdf(r, org),
            '$stem.pdf',
            mimeType: 'application/pdf',
          );
        case 'xlsx':
          await shareBytes(
            reportXlsx(r, org),
            '$stem.xlsx',
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          );
        default:
          await shareBytes(
            reportCsv(r, org),
            '$stem.csv',
            mimeType: 'text/csv',
          );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit c) => c.user);
    final canExport = user?.can(Perm.reportsExport) ?? false;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Financial reports')),
      body: FutureBuilder<FinanceReport>(
        future: _report,
        builder: (context, snap) {
          final r = snap.data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<ReportPeriod>(
                showSelectedIcon: false,
                segments: [
                  for (final p in ReportPeriod.values)
                    ButtonSegment(
                      value: p,
                      label: Text(switch (p) {
                        ReportPeriod.day => 'Day',
                        ReportPeriod.week => 'Week',
                        ReportPeriod.month => 'Month',
                        ReportPeriod.year => 'Year',
                      }),
                    ),
                ],
                selected: {_period},
                onSelectionChanged: (s) {
                  _period = s.first;
                  _reload();
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous',
                    onPressed: () => _step(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      r == null ? '' : reportRange(r),
                      textAlign: TextAlign.center,
                      style: text.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next',
                    onPressed: () => _step(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              if (r == null)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        _Line('Opening balance', r.opening),
                        _Line('Income', r.totalIncome),
                        _Line('Spending', -r.totalExpense),
                        const Divider(),
                        _Line('Closing balance', r.closing, bold: true),
                      ],
                    ),
                  ),
                ),
                _Breakdown('Income by contribution type', r.incomeByType),
                _Breakdown('Income by zone', r.incomeByZone),
                _Breakdown('Income by method', r.incomeByMethod),
                _Breakdown('Spending', r.expenseByCategory),
                const SizedBox(height: 8),
                Text(
                  '${r.transactions.length} transactions in this period',
                  style: text.bodySmall,
                ),
                if (canExport) ...[
                  const SizedBox(height: 16),
                  Text('Export', style: text.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _exporting ? null : () => _export(r, 'pdf'),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('PDF'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _exporting ? null : () => _export(r, 'xlsx'),
                        icon: const Icon(Icons.table_chart),
                        label: const Text('Excel'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _exporting ? null : () => _export(r, 'csv'),
                        icon: const Icon(Icons.description),
                        label: const Text('CSV'),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.amount, {this.bold = false});
  final String label;
  final int amount;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.w700) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(formatMoney(amount), style: style),
        ],
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown(this.title, this.lines);
  final String title;
  final List<ReportLine> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Card(
            child: Column(
              children: [
                for (final l in lines)
                  ListTile(
                    dense: true,
                    title: Text(l.label),
                    subtitle: Text(
                      l.count == 1 ? '1 entry' : '${l.count} entries',
                    ),
                    trailing: Text(formatMoney(l.amount)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
