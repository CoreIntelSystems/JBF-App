import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../core/ui.dart';
import '../../core/org_config.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/sync/sync_api.dart';
import '../auth/auth_cubit.dart';
import '../chats/chats_screen.dart';
import '../elections/elections_screen.dart';
import '../offices/offices_screen.dart';
import '../pay_requests/pay_requests_screen.dart';
import 'member_profile_screen.dart';
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
          3 => ChatsScreen(
            access: ChatAccess(widget.session.token),
            embedded: true,
          ),
          _ => _MeTab(home: home, session: widget.session, onChanged: _refresh),
        },
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_tab) {
          0 => 'My dues',
          1 => 'Events and meetings',
          2 => 'People',
          3 => 'Chats',
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
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: 'Chats',
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
        if (q.isEmpty ||
            d.name.toLowerCase().contains(q) ||
            (d.whatsappName ?? '').toLowerCase().contains(q))
          d,
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
            hintText: 'Search by name or WhatsApp name',
          ),
          onChanged: (v) => setState(() => _query = v.trim()),
        ),
        for (final p in people)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(p.name),
            subtitle: p.zones.isEmpty && p.whatsappName == null
                ? null
                : Text(
                    [
                      if (p.whatsappName != null) 'WhatsApp: ${p.whatsappName}',
                      if (p.zones.isNotEmpty) p.zones.join(', '),
                    ].join(' · '),
                  ),
          ),
      ],
    );
  }
}

class _MeTab extends StatelessWidget {
  const _MeTab({
    required this.home,
    required this.session,
    required this.onChanged,
  });
  final MemberHome home;
  final MemberSession session;
  final Future<void> Function() onChanged;

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

  /// Every member may set the name they use on WhatsApp.
  Future<void> _editWhatsappName(BuildContext context) async {
    final name = TextEditingController(text: home.whatsappName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('My WhatsApp name'),
        content: TextField(
          key: const Key('whatsappNameField'),
          controller: name,
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(
            helperText: 'The name others see for you on WhatsApp',
          ),
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
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AppServices>().sync.api.memberUpdateProfile(
        session.token,
        {'whatsapp_name': name.text},
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('WhatsApp name saved.')),
      );
      await onChanged();
    } on SyncException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.offline
                ? 'Connect to the internet to save your WhatsApp name.'
                : e.message,
          ),
        ),
      );
    }
  }

  Future<void> _setWelfare(BuildContext context, bool join) async {
    final messenger = ScaffoldMessenger.of(context);
    final api = context.read<AppServices>().sync.api;
    try {
      if (join) {
        await api.welfareJoin(session.token);
      } else {
        await api.welfareLeave(session.token);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(join ? 'You are now in welfare.' : 'You left welfare.'),
        ),
      );
      await onChanged();
    } on SyncException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.offline ? 'Connect to the internet to do this.' : e.message,
          ),
        ),
      );
    }
  }

  Widget _welfareCard(BuildContext context) {
    final w = home.standing;
    final (title, body) = switch (w.status) {
      'member' => (
        'You are a welfare member',
        w.duesBehind > 0 || w.roundsMissed > 0
            ? 'Missing 3 payments in a row ends your welfare benefits. '
                  'Months of dues missed: ${w.duesBehind}. '
                  'Welfare contributions missed: ${w.roundsMissed}.'
            : 'Keep paying welfare dues and contributions. Missing 3 in a '
                  'row ends your welfare benefits.',
      ),
      'disqualified' => (
        'Welfare benefits stopped',
        '${w.note ?? 'You missed 3 payments in a row.'} Speak to the Welfare '
            'Committee to be reinstated.',
      ),
      _ => (
        'You are not in welfare',
        'Welfare is by choice. Join, or pay welfare dues or a welfare '
            'contribution, to be covered.',
      ),
    };
    return Card(
      child: ListTile(
        leading: Icon(w.isMember ? Icons.verified_user : Icons.shield_outlined),
        title: Text(title),
        subtitle: Text(body),
        isThreeLine: true,
        trailing: w.disqualified
            ? null
            : TextButton(
                onPressed: () => _setWelfare(context, !w.isMember),
                child: Text(w.isMember ? 'Leave' : 'Join'),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _MemberCard(
          orgName: session.orgName.isEmpty ? OrgDefaults.name : session.orgName,
          home: home,
        ),
        for (final (at, details) in home.warnings)
          Card(
            color: theme.colorScheme.errorContainer,
            child: ListTile(
              leading: const Icon(Icons.warning_amber_outlined),
              title: const Text('Warning from the Disciplinary Committee'),
              subtitle: Text('${formatDate(at)}\n$details'),
              isThreeLine: true,
            ),
          ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const IconBadge(Icons.how_to_vote_rounded),
            title: const Text('Elections'),
            subtitle: const Text('Vote, or see candidates and results'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    ElectionsScreen(access: ChatAccess(session.token)),
              ),
            ),
          ),
        ),
        MyPaymentRequests(access: ChatAccess(session.token)),
        CommitteeNotices(access: ChatAccess(session.token)),
        MyOffices(access: ChatAccess(session.token)),
        PayRequestsEntry(access: ChatAccess(session.token)),
        const SizedBox(height: 8),
        _welfareCard(context),
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
        if (home.selfEdit)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit my details and zones'),
            subtitle: const Text('Check your name, phone and zone'),
            onTap: () async {
              final saved = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) =>
                      MemberProfileScreen(home: home, session: session),
                ),
              );
              if (saved == true) await onChanged();
            },
          )
        else ...[
          ListTile(
            key: const Key('myWhatsappName'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.chat_outlined),
            title: const Text('My WhatsApp name'),
            subtitle: Text(home.whatsappName ?? 'Not set yet'),
            onTap: () => _editWhatsappName(context),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'To correct your other details, speak to your Zone Secretary.',
            ),
          ),
        ],
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
      ],
    );
  }
}

/// The member's ID card: the same layout as the printed card.
class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.orgName, required this.home});

  final String orgName;
  final MemberHome home;

  @override
  Widget build(BuildContext context) {
    final s = home.statement;
    final green = Color(OrgDefaults.primaryColor);
    final gold = Color(OrgDefaults.accentColor);
    final roles = home.roles.isEmpty ? const ['Member'] : home.roles;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: green,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Image.asset(OrgDefaults.logoAsset, height: 36),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        orgName.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'MEMBERSHIP CARD',
                        style: TextStyle(
                          color: gold,
                          fontSize: 11,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(height: 3, color: gold),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  s.memberNo,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: green,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                if (home.whatsappName != null)
                  Text('WhatsApp: ${home.whatsappName}'),
                Text('Zone: ${s.zones.isEmpty ? 'None' : s.zones.join(', ')}'),
                Text('Member since ${formatDate(s.joined)}'),
                Text('Status: ${capitalize(s.status)}'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < roles.length; i++)
                      Chip(
                        label: Text(
                          roles[i],
                          style: TextStyle(
                            color: i == 0 ? Colors.white : green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        backgroundColor: i == 0
                            ? green
                            : gold.withValues(alpha: 0.2),
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
