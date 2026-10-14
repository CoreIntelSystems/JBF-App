import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/repositories/member_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../domain/permissions.dart';
import '../auth/auth_cubit.dart';
import '../members/member_detail_screen.dart';
import '../payments/defaulters_screen.dart';
import '../payments/payment_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final Stream<DashboardStats> _stats = context
      .read<AppServices>()
      .dashboard
      .watchStats();
  late final Stream<CollectionStats> _collections = context
      .read<AppServices>()
      .payments
      .watchCollectionStats();

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit c) => c.user);
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: StreamBuilder<DashboardStats>(
        stream: _stats,
        builder: (context, snap) {
          final stats = snap.data;
          if (stats == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Hello, ${user?.displayName ?? ''}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(user?.roleName ?? ''),
              const SizedBox(height: 16),
              if ((user?.can(Perm.financeView) ?? false) ||
                  (user?.can(Perm.paymentsRecord) ?? false))
                _Collections(_collections),
              // Rows that size to their content, so larger phone text
              // settings never overflow the tiles.
              _TileRow([
                _StatTile(
                  'Total members',
                  '${stats.total}',
                  Icons.groups,
                  highlight: true,
                ),
                _StatTile(
                  'Active',
                  '${stats.count(MemberStatus.active)}',
                  Icons.check_circle_outline,
                ),
              ]),
              const SizedBox(height: 12),
              _TileRow([
                _StatTile(
                  'Inactive / suspended',
                  '${stats.count(MemberStatus.inactive) + stats.count(MemberStatus.suspended)}',
                  Icons.pause_circle_outline,
                ),
                _StatTile(
                  'Deceased',
                  '${stats.count(MemberStatus.deceased)}',
                  Icons.local_florist_outlined,
                ),
              ]),
              const SizedBox(height: 24),
              Text(
                'Active members by zone',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (final zc in stats.byZone)
                      ListTile(
                        dense: true,
                        title: Text(zoneDisplayName(zc.zone)),
                        subtitle: zc.zone.isActive
                            ? null
                            : const Text('Not open yet'),
                        trailing: Text(
                          '${zc.members}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Recently registered',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (stats.recent.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No members yet. Add the first one from '
                      'the Members tab.',
                    ),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final m in stats.recent)
                        ListTile(
                          title: Text(m.fullName),
                          subtitle: Text(
                            '${m.memberNo} · joined ${formatDate(m.dateJoined)}',
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  MemberDetailScreen(memberId: m.id),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Collections extends StatelessWidget {
  const _Collections(this.stream);
  final Stream<CollectionStats> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CollectionStats>(
      stream: stream,
      builder: (context, snap) {
        final c = snap.data;
        if (c == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TileRow([
                _StatTile(
                  'Collected today',
                  formatMoney(c.today),
                  Icons.today,
                  highlight: true,
                ),
                _StatTile(
                  'This month',
                  formatMoney(c.thisMonth),
                  Icons.calendar_month,
                ),
              ]),
              const SizedBox(height: 12),
              if (c.duesConfigured)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DefaultersScreen(),
                    ),
                  ),
                  child: _TileRow([
                    _StatTile(
                      'Dues outstanding',
                      formatMoney(c.outstanding),
                      Icons.account_balance_wallet_outlined,
                    ),
                    _StatTile(
                      'Defaulters',
                      '${c.defaulters}',
                      Icons.warning_amber_outlined,
                    ),
                  ]),
                )
              else
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Set the monthly dues amount under More > Contribution '
                      'types to start tracking arrears and defaulters.',
                    ),
                  ),
                ),
              if (c.recent.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Latest payments',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [for (final v in c.recent) PaymentTile(view: v)],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TileRow extends StatelessWidget {
  const _TileRow(this.tiles);
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: tiles[0]),
          const SizedBox(width: 12),
          Expanded(child: tiles[1]),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.label, this.value, this.icon, {this.highlight = false});

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = highlight ? scheme.onPrimary : null;
    return Card(
      color: highlight ? scheme.primary : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: highlight ? scheme.secondary : null),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: fg),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
