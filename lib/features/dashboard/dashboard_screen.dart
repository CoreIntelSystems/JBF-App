import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../data/database.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/repositories/member_repository.dart';
import '../auth/auth_cubit.dart';
import '../members/member_detail_screen.dart';

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
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _StatTile(
                    'Total members',
                    stats.total,
                    Icons.groups,
                    highlight: true,
                  ),
                  _StatTile(
                    'Active',
                    stats.count(MemberStatus.active),
                    Icons.check_circle_outline,
                  ),
                  _StatTile(
                    'Inactive / suspended',
                    stats.count(MemberStatus.inactive) +
                        stats.count(MemberStatus.suspended),
                    Icons.pause_circle_outline,
                  ),
                  _StatTile(
                    'Deceased',
                    stats.count(MemberStatus.deceased),
                    Icons.local_florist_outlined,
                  ),
                ],
              ),
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
              const SizedBox(height: 24),
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Contributions, arrears, emergency fund and welfare '
                    'alerts will appear here once payments are added.',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.label, this.value, this.icon, {this.highlight = false});

  final String label;
  final int value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = highlight ? scheme.onPrimary : null;
    return Card(
      color: highlight ? scheme.primary : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: highlight ? scheme.secondary : null),
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: fg),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
