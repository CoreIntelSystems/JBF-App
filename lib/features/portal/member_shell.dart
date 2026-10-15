import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../core/org_config.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/sync/sync_api.dart';
import '../auth/auth_cubit.dart';
import 'member_statement_screen.dart';

/// The app for an ordinary member on their own phone: their dues, events,
/// the executives and members, and their own record. Read-only, loaded from
/// the cloud and kept on the phone for when there is no internet.
class MemberShell extends StatefulWidget {
  const MemberShell({super.key, required this.session});

  final MemberSession session;

  @override
  State<MemberShell> createState() => _MemberShellState();
}

class _MemberShellState extends State<MemberShell> {
  static const _cacheKey = 'member_home';

  late final _services = context.read<AppServices>();
  MemberHome? _home;
  DateTime? _loadedAt;
  String? _error;
  bool _loading = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _loadCache().then((_) => _refresh());
  }

  Future<void> _loadCache() async {
    final raw = await _services.prefs.read(_cacheKey);
    if (raw == null || !mounted) return;
    final j = jsonDecode(raw) as Map;
    setState(() {
      _home = MemberHome.fromJson(j['home'] as Map);
      _loadedAt = DateTime.tryParse('${j['at']}');
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final json = await _services.sync.api.memberHome(widget.session.token);
      final now = DateTime.now();
      await _services.prefs.write(
        _cacheKey,
        jsonEncode({'home': json, 'at': now.toIso8601String()}),
      );
      if (!mounted) return;
      setState(() {
        _home = MemberHome.fromJson(json);
        _loadedAt = now;
      });
    } on SyncException catch (e) {
      if (!mounted) return;
      if (!e.offline &&
          (e.message.contains('sign in again') ||
              e.message.contains('was reset'))) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
        await context.read<AuthCubit>().memberSignOut();
        return;
      }
      setState(
        () => _error = e.offline
            ? 'No internet connection. Showing what was saved on this phone.'
            : e.message,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = _home;
    final banner = <Widget>[
      if (_error != null)
        MaterialBanner(
          content: Text(_error!),
          actions: [
            TextButton(onPressed: _refresh, child: const Text('Try again')),
          ],
        ),
      if (home?.officer ?? false)
        MaterialBanner(
          content: const Text(
            'You have been given an executive role. Sign out and sign in '
            'again to get the tools for your role.',
          ),
          actions: [
            TextButton(
              onPressed: () => context.read<AuthCubit>().memberSignOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
    ];
    final Widget body;
    if (home == null) {
      body = Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error ?? 'Nothing to show yet.',
                  textAlign: TextAlign.center,
                ),
              ),
      );
    } else {
      final updated = _loadedAt == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Updated ${formatDateTime(_loadedAt!)}. Pull down to refresh.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
      body = RefreshIndicator(
        onRefresh: _refresh,
        child: switch (_tab) {
          0 => StatementView(home.statement, header: updated),
          1 => _EventsTab(home),
          2 => _PeopleTab(home),
          _ => _MeTab(home: home, session: widget.session),
        },
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_tab) {
          0 => 'My dues',
          1 => 'Events and meetings',
          2 => 'People',
          _ => 'Me',
        }),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          ...banner,
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'My dues',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'People',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}

class _EventsTab extends StatelessWidget {
  const _EventsTab(this.home);
  final MemberHome home;

  @override
  Widget build(BuildContext context) {
    final events = home.events;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        for (final a in home.announcements)
          Card(
            child: ListTile(
              leading: const Icon(Icons.campaign_outlined),
              title: Text(a),
            ),
          ),
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No upcoming events or general meetings.',
              textAlign: TextAlign.center,
            ),
          ),
        for (final e in events)
          Card(
            child: ListTile(
              leading: Icon(
                e.meeting ? Icons.groups_outlined : Icons.celebration_outlined,
              ),
              title: Text(e.name),
              subtitle: Text(
                [
                  formatDate(e.date),
                  if (e.venue != null && e.venue!.isNotEmpty) e.venue!,
                  if (e.description != null && e.description!.isNotEmpty)
                    e.description!,
                ].join('\n'),
              ),
              isThreeLine: e.description != null && e.description!.isNotEmpty,
            ),
          ),
      ],
    );
  }
}

class _PeopleTab extends StatefulWidget {
  const _PeopleTab(this.home);
  final MemberHome home;

  @override
  State<_PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<_PeopleTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final q = _query.toLowerCase();
    final people = [
      for (final d in widget.home.directory)
        if (q.isEmpty || d.name.toLowerCase().contains(q)) d,
    ];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Text('Executives', style: text.titleMedium),
        if (widget.home.executives.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No executives listed yet.'),
          ),
        for (final x in widget.home.executives)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.workspace_premium_outlined),
            title: Text(x.name),
            subtitle: Text(
              x.zone == null ? x.position : '${x.position}, ${x.zone}',
            ),
          ),
        const Divider(height: 32),
        Text(
          'Members (${widget.home.directory.length})',
          style: text.titleMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search by name',
          ),
          onChanged: (v) => setState(() => _query = v.trim()),
        ),
        for (final p in people)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(p.name),
            subtitle: p.zones.isEmpty ? null : Text(p.zones.join(', ')),
          ),
      ],
    );
  }
}

class _MeTab extends StatelessWidget {
  const _MeTab({required this.home, required this.session});
  final MemberHome home;
  final MemberSession session;

  static const _statuses = {
    'pending': 'Waiting for approval',
    'approved': 'Approved',
    'rejected': 'Not approved',
    'paid': 'Paid',
  };

  Future<void> _changePassword(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
            TextField(
              controller: next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Change'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final err = AuthRepository.validatePassword(next.text);
    if (err != null) {
      messenger.showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    try {
      await context.read<AppServices>().sync.api.memberAuth(
        action: 'change_password',
        org: OrgDefaults.shortName,
        memberNo: session.memberNo,
        password: current.text,
        newPassword: next.text,
        check: true,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Password changed.')),
      );
    } on SyncException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.offline
                ? 'Connect to the internet to change your password.'
                : e.message.startsWith('Wrong')
                ? 'Current password is wrong.'
                : e.message,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = home.statement;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.orgName.isEmpty ? OrgDefaults.name : session.orgName,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text('MEMBER ID CARD', style: theme.textTheme.labelSmall),
                const SizedBox(height: 12),
                Text(s.name, style: theme.textTheme.titleLarge),
                Text(s.memberNo, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Zone: ${s.zones.isEmpty ? 'None' : s.zones.join(', ')}'),
                Text('Member since ${formatDate(s.joined)}'),
                Text('Status: ${capitalize(s.status)}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('My welfare cases', style: theme.textTheme.titleMedium),
        if (home.welfare.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No welfare cases.'),
          ),
        for (final w in home.welfare)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(w.type ?? 'Welfare case'),
            subtitle: Text(
              [
                w.caseNo,
                formatDate(w.occurredOn),
                _statuses[w.status] ?? capitalize(w.status),
              ].where((x) => x.isNotEmpty).join(' · '),
            ),
            trailing: Text(formatMoney(w.amount)),
          ),
        const Divider(height: 32),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.password),
          title: const Text('Change password'),
          onTap: () => _changePassword(context),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout),
          title: const Text('Sign out'),
          onTap: () => context.read<AuthCubit>().memberSignOut(),
        ),
        const SizedBox(height: 16),
        Text(
          'To correct your details, speak to your Zone Secretary.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
