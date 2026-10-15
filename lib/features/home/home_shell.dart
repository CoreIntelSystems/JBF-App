import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/permissions.dart';
import '../auth/auth_cubit.dart';
import '../dashboard/dashboard_screen.dart';
import '../members/member_detail_screen.dart';
import '../members/members_screen.dart';
import '../more/more_screen.dart';
import '../payments/payments_screen.dart';

/// Bottom navigation for signed-in users. Each tab only appears when the
/// user's role may use it.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _Tab {
  const _Tab(this.key, this.page, this.destination);
  final String key;
  final Widget page;
  final NavigationDestination destination;
}

class _HomeShellState extends State<HomeShell> {
  String _current = 'dashboard';

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit c) => c.user);
    final memberId = user?.memberId;
    final tabs = [
      const _Tab(
        'dashboard',
        DashboardScreen(),
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
      ),
      if (memberId != null)
        _Tab(
          'me',
          MemberDetailScreen(
            key: ValueKey(memberId),
            memberId: memberId,
            self: true,
          ),
          const NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle),
            label: 'My dues',
          ),
        ),
      if (user?.can(Perm.membersView) ?? false)
        const _Tab(
          'members',
          MembersScreen(),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Members',
          ),
        ),
      if ((user?.can(Perm.paymentsRecord) ?? false) ||
          (user?.can(Perm.financeView) ?? false))
        const _Tab(
          'payments',
          PaymentsScreen(),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Payments',
          ),
        ),
      const _Tab(
        'more',
        MoreScreen(),
        NavigationDestination(icon: Icon(Icons.menu), label: 'More'),
      ),
    ];
    final index = tabs.indexWhere((t) => t.key == _current).clamp(0, 99);
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [
          for (final t in tabs)
            KeyedSubtree(key: ValueKey(t.key), child: t.page),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _current = tabs[i].key),
        destinations: [for (final t in tabs) t.destination],
      ),
    );
  }
}
