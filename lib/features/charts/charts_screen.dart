import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/money.dart';
import '../../data/repositories/analytics_repository.dart';

/// Collections, zone comparison, welfare and membership at a glance.
class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  late Future<Analytics> _data = _load();

  Future<Analytics> _load() => context.read<AppServices>().analytics.load();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Charts'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _data = _load()),
          ),
        ],
      ),
      body: FutureBuilder<Analytics>(
        future: _data,
        builder: (context, snap) {
          final a = snap.data;
          if (snap.hasError) {
            return Center(child: Text('Could not load charts: ${snap.error}'));
          }
          if (a == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _ChartCard(
                title: 'Monthly collections',
                subtitle:
                    'Last 12 months, total '
                    '${formatMoney(_sum(a.monthlyCollections))}',
                child: _Bars(a.monthlyCollections, scheme.primary, money: true),
              ),
              _ChartCard(
                title: 'Zone comparison',
                subtitle: 'Collections this year by member\'s main zone',
                child: _Bars(a.zoneCollections, scheme.tertiary, money: true),
              ),
              _ChartCard(
                title: 'Welfare',
                subtitle:
                    '${_sum(a.welfareCases)} cases and '
                    '${formatMoney(_sum(a.welfarePayouts))} paid out in 12 '
                    'months',
                child: Column(
                  children: [
                    SizedBox(
                      height: 140,
                      child: _Bars(a.welfareCases, scheme.secondary),
                    ),
                    const SizedBox(height: 4),
                    const Text('Cases reported per month'),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 140,
                      child: _Bars(a.welfarePayouts, scheme.error, money: true),
                    ),
                    const SizedBox(height: 4),
                    const Text('Paid out per month'),
                  ],
                ),
              ),
              _ChartCard(
                title: 'Member growth',
                subtitle:
                    '${a.memberTotals.last.value} members, '
                    '${_sum(a.newMembers)} joined in 12 months',
                child: _Line(a.memberTotals, scheme.primary),
              ),
            ],
          );
        },
      ),
    );
  }

  static int _sum(List<ChartPoint> p) => p.fold(0, (a, b) => a + b.value);
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: text.titleMedium),
            Text(subtitle, style: text.bodySmall),
            const SizedBox(height: 16),
            child is Column ? child : SizedBox(height: 200, child: child),
          ],
        ),
      ),
    );
  }
}

String _short(int v, {required bool money}) {
  final n = money ? v / 100 : v.toDouble();
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}m';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k';
  return n.toStringAsFixed(0);
}

FlTitlesData _titles(List<ChartPoint> points, {required bool money}) =>
    FlTitlesData(
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (value, meta) => Text(
            _short(value.round(), money: money),
            style: const TextStyle(fontSize: 10),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 22,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final i = value.round();
            if (i < 0 || i >= points.length || value != i.toDouble()) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                points[i].label,
                style: const TextStyle(fontSize: 10),
              ),
            );
          },
        ),
      ),
    );

class _Bars extends StatelessWidget {
  const _Bars(this.points, this.color, {this.money = false});
  final List<ChartPoint> points;
  final Color color;
  final bool money;

  @override
  Widget build(BuildContext context) {
    final max = points.fold(0, (a, p) => p.value > a ? p.value : a);
    return BarChart(
      BarChartData(
        maxY: max == 0 ? 1 : max * 1.15,
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: _titles(points, money: money),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              '${points[group.x].label}\n'
              '${money ? formatMoney(rod.toY.round()) : rod.toY.round()}',
              const TextStyle(color: Colors.white),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].value.toDouble(),
                  color: color,
                  width: points.length > 10 ? 10 : 16,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.points, this.color);
  final List<ChartPoint> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final max = points.fold(0, (a, p) => p.value > a ? p.value : a);
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: max == 0 ? 1 : max * 1.15,
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: _titles(points, money: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].value.toDouble()),
            ],
            color: color,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}
