import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../core/org_config.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/database.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/repositories/member_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/welfare_repository.dart';
import '../../domain/permissions.dart';
import '../auth/auth_cubit.dart';
import '../members/member_detail_screen.dart';
import '../payments/defaulters_screen.dart';
import '../payments/payment_widgets.dart';
import '../welfare/welfare_common.dart';
import '../welfare/welfare_screen.dart';

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
  late final Stream<WelfareSummary> _welfare = context
      .read<AppServices>()
      .welfare
      .watchSummary();

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
          final canMembers = user?.can(Perm.membersView) ?? false;
          final maxZone = stats.byZone.fold<int>(
            1,
            (m, z) => z.members > m ? z.members : m,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Hero(
                greeting: 'Hello, ${user?.displayName ?? ''}',
                role: user?.roleName ?? '',
                figures: canMembers
                    ? [
                        ('Members', '${stats.total}'),
                        ('Active', '${stats.count(MemberStatus.active)}'),
                        (
                          'Zones',
                          '${stats.byZone.where((z) => z.zone.isActive && z.zone.code != 0).length}',
                        ),
                      ]
                    : const [],
              ),
              const SizedBox(height: 16),
              if ((user?.can(Perm.financeView) ?? false) ||
                  (user?.can(Perm.paymentsRecord) ?? false))
                _Collections(_collections),
              if (user?.canViewWelfare ?? false) _WelfareCard(_welfare),
              if (!canMembers)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Dues, receipts and welfare are under My dues.',
                    ),
                  ),
                ),
              if (canMembers) ...[
                const _ActivationCard(),
                // Rows that size to their content, so larger phone text
                // settings never overflow the tiles.
                _TileRow([
                  MetricTile(
                    label: 'Total members',
                    value: '${stats.total}',
                    icon: Icons.groups_rounded,
                  ),
                  MetricTile(
                    label: 'Active',
                    value: '${stats.count(MemberStatus.active)}',
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF1B8A4B),
                  ),
                ]),
                const SizedBox(height: 12),
                _TileRow([
                  MetricTile(
                    label: 'Inactive / suspended',
                    value:
                        '${stats.count(MemberStatus.inactive) + stats.count(MemberStatus.suspended)}',
                    icon: Icons.pause_circle_rounded,
                    color: const Color(0xFFB7791F),
                  ),
                  MetricTile(
                    label: 'Deceased',
                    value: '${stats.count(MemberStatus.deceased)}',
                    icon: Icons.local_florist_rounded,
                    color: const Color(0xFF6B7A72),
                  ),
                ]),
                const SectionTitle('Active members by zone'),
                GroupCard(
                  children: [
                    for (final zc in stats.byZone)
                      _ZoneRow(
                        name: zoneDisplayName(zc.zone),
                        note: zc.zone.isActive ? null : 'Not open yet',
                        count: zc.members,
                        share: zc.members / maxZone,
                        holding: zc.zone.code == 0,
                      ),
                  ],
                ),
                const SectionTitle('Recently registered'),
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
                  GroupCard(
                    children: [
                      for (final m in stats.recent)
                        ListTile(
                          leading: InitialsAvatar(m.fullName),
                          title: Text(
                            m.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${m.memberNo} · joined ${formatDate(m.dateJoined)}',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  MemberDetailScreen(memberId: m.id),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }
}

/// Branded header: who is signed in and the organisation's key figures.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.greeting,
    required this.role,
    required this.figures,
  });

  final String greeting;
  final String role;
  final List<(String, String)> figures;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final top = dark ? const Color(0xFF14573A) : scheme.primary;
    final bottom = dark ? const Color(0xFF0B3524) : const Color(0xFF064D29);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, bottom],
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  OrgDefaults.logoAsset,
                  width: 52,
                  height: 52,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      OrgDefaults.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: scheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      greeting,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (role.isNotEmpty) ...[
            const SizedBox(height: 14),
            Pill(role, onDark: true),
          ],
          if (figures.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  for (final f in figures)
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            f.$2,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            f.$1,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: .75),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ZoneRow extends StatelessWidget {
  const _ZoneRow({
    required this.name,
    required this.count,
    required this.share,
    this.note,
    this.holding = false,
  });

  final String name;
  final String? note;
  final int count;
  final double share;
  final bool holding;

  @override
  Widget build(BuildContext context) {
    final ink = Tones.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (note != null)
            Text(note!, style: TextStyle(fontSize: 12, color: ink.muted)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: share.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: ink.border,
              color: holding ? scheme.secondary : scheme.primary,
            ),
          ),
        ],
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
                MetricTile(
                  label: 'Collected today',
                  value: formatMoney(c.today),
                  icon: Icons.today_rounded,
                ),
                MetricTile(
                  label: 'This month',
                  value: formatMoney(c.thisMonth),
                  icon: Icons.calendar_month_rounded,
                  color: const Color(0xFF2B6CB0),
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
                    MetricTile(
                      label: 'Dues outstanding',
                      value: formatMoney(c.outstanding),
                      icon: Icons.account_balance_wallet_rounded,
                      color: const Color(0xFFB7791F),
                    ),
                    MetricTile(
                      label: 'Defaulters',
                      value: '${c.defaulters}',
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFC53030),
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
                const SectionTitle('Latest payments'),
                GroupCard(
                  children: [for (final v in c.recent) PaymentTile(view: v)],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _WelfareCard extends StatelessWidget {
  const _WelfareCard(this.stream);
  final Stream<WelfareSummary> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WelfareSummary>(
      stream: stream,
      builder: (context, snap) {
        final s = snap.data;
        if (s == null) return const SizedBox.shrink();
        final waiting = [
          if (s.pendingCases > 0) '${s.pendingCases} awaiting approval',
          if (s.approvedUnpaid > 0) '${s.approvedUnpaid} to pay',
          if (s.pendingBenefitChanges > 0)
            '${s.pendingBenefitChanges} amount change'
                '${s.pendingBenefitChanges == 1 ? '' : 's'} to approve',
        ];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            color: waiting.isEmpty
                ? null
                : Theme.of(context).colorScheme.tertiaryContainer,
            child: ListTile(
              leading: const IconBadge(Icons.volunteer_activism_rounded),
              title: Text(
                'Welfare fund ${formatMoney(s.fundBalance)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                waiting.isEmpty
                    ? 'Paid out this month ${formatMoney(s.paidThisMonth)}'
                    : waiting.join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WelfareScreen(
                    initialFilter: s.pendingCases > 0
                        ? WelfareStatus.pending
                        : s.approvedUnpaid > 0
                        ? WelfareStatus.approved
                        : null,
                  ),
                ),
              ),
            ),
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

/// Officers see how many members have activated their sign-in.
class _ActivationCard extends StatefulWidget {
  const _ActivationCard();

  @override
  State<_ActivationCard> createState() => _ActivationCardState();
}

class _ActivationCardState extends State<_ActivationCard> {
  ({int members, int activated})? _summary;

  @override
  void initState() {
    super.initState();
    final sync = context.read<AppServices>().sync;
    if (sync.state.enabled) {
      sync
          .activationSummary()
          .then((s) {
            if (mounted) setState(() => _summary = s);
          })
          .catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    if (s == null || s.members == 0) return const SizedBox.shrink();
    final share = (s.activated / s.members).clamp(0.0, 1.0);
    final ink = Tones.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconBadge(Icons.how_to_reg_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Member sign-ins activated',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${s.activated} of ${s.members}',
                    style: TextStyle(color: ink.muted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: share, minHeight: 8),
              ),
              const SizedBox(height: 8),
              Text(
                s.activated >= s.members
                    ? 'Everyone has activated.'
                    : 'Use the WhatsApp button in Members to send the '
                          'remaining IDs.',
                style: TextStyle(fontSize: 13, color: ink.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
