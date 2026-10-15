import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../data/sync/sync_api.dart';
import '../../data/sync/sync_service.dart';
import '../auth/auth_cubit.dart';

/// Shows how this phone is syncing with the organisation's other phones,
/// and lets the main phone add or remove phones.
class CloudSyncScreen extends StatefulWidget {
  const CloudSyncScreen({super.key});

  @override
  State<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends State<CloudSyncScreen> {
  late final _sync = context.read<SyncService>();
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _sync.refresh().ignore();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _working = true);
    try {
      await action();
    } on SyncException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _addPhone() => _run(() async {
    final admin = await showDialog<bool>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add a phone'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(false),
            child: const ListTile(
              title: Text('Officer phone'),
              subtitle: Text('Records and sees the shared data.'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(true),
            child: const ListTile(
              title: Text('Main phone'),
              subtitle: Text('Can also add and remove phones.'),
            ),
          ),
        ],
      ),
    );
    if (admin == null) return;
    final code = await _sync.createCode(admin: admin);
    if (!mounted) return;
    final org = _sync.state.credentials?.orgName ?? '';
    final message =
        'Your code to join $org on the JBF app: $code\n'
        'Open the app, tap "Join with a code" and enter it. '
        'It works once and expires in 7 days.';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Code for the new phone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              code,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                letterSpacing: 4,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'On the new phone, choose "Join with a code" and enter this '
              'code. It works once and expires in 7 days. Give each phone '
              'its own number series, such as Z3 for Zone 3.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.of(context).pop();
            },
            child: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              SharePlus.instance.share(ShareParams(text: message)).ignore();
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  });

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop cloud sync on this phone?'),
        content: const Text(
          'Records already on this phone stay here, and other phones keep '
          'theirs. Changes made here will no longer reach other phones. '
          'Changes not yet uploaded will not be sent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Stop sync'),
          ),
        ],
      ),
    );
    if (ok == true) await _run(_sync.leave);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cloud sync')),
      body: BlocBuilder<SyncService, SyncStatus>(
        builder: (context, s) {
          final c = s.credentials;
          if (c == null) return _NotSetUp(loaded: s.loaded);
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_done_outlined),
                title: Text(c.orgName),
                subtitle: Text(
                  'This phone: ${c.deviceName}'
                  '${c.series == null ? '' : ' (series ${c.series})'}'
                  '${c.isAdmin ? '\nMain phone: can add and remove phones' : ''}',
                ),
                isThreeLine: c.isAdmin,
              ),
              ListTile(
                leading: s.busy
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                title: Text(
                  s.busy
                      ? 'Syncing...'
                      : s.lastSyncAt == null
                      ? 'Not synced yet'
                      : 'Last synced ${formatDateTime(s.lastSyncAt!)}',
                ),
                subtitle: Text(
                  s.pending == 0
                      ? 'Everything on this phone has been uploaded.'
                      : '${s.pending} changes waiting to upload.',
                ),
              ),
              if (s.error != null)
                ListTile(
                  leading: Icon(
                    s.offline ? Icons.wifi_off : Icons.error_outline,
                    color: s.offline ? null : theme.colorScheme.error,
                  ),
                  title: Text(s.error!),
                ),
              if (s.issues > 0)
                ListTile(
                  leading: Icon(
                    Icons.warning_amber,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    '${s.issues} records from other phones could not be '
                    'saved here',
                  ),
                  subtitle: const Text('Tap to see why'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SyncIssuesScreen(),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: s.busy || _working ? null : _sync.syncNow,
                  icon: const Icon(Icons.sync),
                  label: const Text('Sync now'),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'The app works without internet. It syncs when it opens, '
                  'when you return to it and every few minutes while it is '
                  'open.',
                ),
              ),
              const Divider(height: 32),
              if (c.isAdmin) ...[
                ListTile(
                  leading: const Icon(Icons.add_to_home_screen),
                  title: const Text('Add a phone'),
                  subtitle: const Text('Get a one-time code for a new phone'),
                  enabled: !_working,
                  onTap: _addPhone,
                ),
                ListTile(
                  leading: const Icon(Icons.devices),
                  title: const Text('Phones'),
                  subtitle: const Text('See and remove phones'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CloudPhonesScreen(),
                    ),
                  ),
                ),
              ],
              ListTile(
                leading: const Icon(Icons.cloud_off_outlined),
                title: const Text('Stop cloud sync on this phone'),
                enabled: !_working,
                onTap: _leave,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NotSetUp extends StatelessWidget {
  const _NotSetUp({required this.loaded});
  final bool loaded;

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Icon(Icons.cloud_sync_outlined, size: 64),
        const SizedBox(height: 16),
        const Text(
          'Cloud sync keeps every officer\'s phone up to date over the '
          'internet: members, payments, welfare, events and more. Each '
          'phone still works offline and syncs when it has a connection.',
        ),
        const SizedBox(height: 12),
        const Text(
          'To start, enter the code you were given. The first phone to join '
          'uploads its records; every other phone joins with a code from '
          'the main phone.',
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const JoinCloudScreen()),
          ),
          icon: const Icon(Icons.key),
          label: const Text('Join with a code'),
        ),
      ],
    );
  }
}

/// Enter a one-time code to connect this phone to the organisation.
class JoinCloudScreen extends StatefulWidget {
  const JoinCloudScreen({super.key, this.fromSetup = false});

  /// Joined from the first-run screen: the organisation's users arrive
  /// with the records, so the next step is signing in.
  final bool fromSetup;

  @override
  State<JoinCloudScreen> createState() => _JoinCloudScreenState();
}

class _JoinCloudScreenState extends State<JoinCloudScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _series = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_code, _name, _series]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final sync = context.read<SyncService>();
    try {
      final outcome = await sync.join(
        code: _code.text,
        deviceName: _name.text,
        series: _series.text,
      );
      sync.startAuto();
      if (!mounted) return;
      final org = sync.state.credentials?.orgName ?? '';
      final message = switch (outcome) {
        JoinOutcome.founded =>
          'This phone started $org in the cloud. Add other phones from '
              'More > Cloud sync.',
        JoinOutcome.received =>
          'Joined $org. Sign in with the username and password the main '
              'phone gave you.',
        JoinOutcome.merged => 'Joined $org. Records are now shared.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      final auth = context.read<AuthCubit>();
      Navigator.of(context).pop();
      if (widget.fromSetup) await auth.start();
    } on SyncException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not join: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join with a code')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Ask the main phone for a code (More > Cloud sync > Add a '
              'phone). This phone needs internet to join.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _code,
              decoration: const InputDecoration(labelText: 'Code'),
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter the code.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Name for this phone',
                hintText: 'e.g. Treasurer, Zone 3 Secretary',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Name this phone.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _series,
              decoration: const InputDecoration(
                labelText: 'Number series',
                hintText: 'e.g. Z3',
                helperText:
                    'Added to member, receipt and voucher numbers made on '
                    'this phone, so they never clash. Leave empty only on '
                    'the first (main) phone.',
                helperMaxLines: 3,
              ),
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              maxLength: 4,
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return null;
                return RegExp(r'^[A-Za-z0-9]{1,4}$').hasMatch(s)
                    ? null
                    : 'Use 1 to 4 letters or numbers.';
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Join'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The organisation's phones, for the main phone.
class CloudPhonesScreen extends StatefulWidget {
  const CloudPhonesScreen({super.key});

  @override
  State<CloudPhonesScreen> createState() => _CloudPhonesScreenState();
}

class _CloudPhonesScreenState extends State<CloudPhonesScreen> {
  late final _sync = context.read<SyncService>();
  late Future<List<CloudDevice>> _devices = _sync.devices();

  Future<void> _remove(CloudDevice d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${d.name}?'),
        content: const Text(
          'It will stop syncing straight away. Use this for a lost phone or '
          'an officer who has left. Records it already uploaded stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _sync.removeDevice(d.id);
    } on SyncException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
    setState(() => _devices = _sync.devices());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phones')),
      body: FutureBuilder<List<CloudDevice>>(
        future: _devices,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snap.error}', textAlign: TextAlign.center),
              ),
            );
          }
          final list = snap.data;
          if (list == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            children: [
              for (final d in list)
                ListTile(
                  leading: Icon(
                    d.revoked ? Icons.phonelink_erase : Icons.smartphone,
                  ),
                  title: Text(
                    '${d.name}${d.isThisPhone ? ' (this phone)' : ''}',
                  ),
                  subtitle: Text(
                    [
                      if (d.series != null) 'Series ${d.series}',
                      if (d.isAdmin) 'Main phone',
                      if (d.revoked)
                        'Removed'
                      else if (d.lastSeenAt != null)
                        'Last seen ${formatDateTime(d.lastSeenAt!)}',
                    ].join(' · '),
                  ),
                  trailing: d.revoked || d.isThisPhone
                      ? null
                      : IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _remove(d),
                        ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Records from other phones that could not be saved on this one.
class SyncIssuesScreen extends StatefulWidget {
  const SyncIssuesScreen({super.key});

  @override
  State<SyncIssuesScreen> createState() => _SyncIssuesScreenState();
}

class _SyncIssuesScreenState extends State<SyncIssuesScreen> {
  late final _sync = context.read<SyncService>();
  late Future<List<SyncIssue>> _issues = _sync.issues();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync issues'),
        actions: [
          TextButton(
            onPressed: () async {
              await _sync.clearIssues();
              setState(() => _issues = _sync.issues());
            },
            child: const Text('Clear'),
          ),
        ],
      ),
      body: FutureBuilder<List<SyncIssue>>(
        future: _issues,
        builder: (context, snap) => ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Usually two phones recorded the same thing (for example the '
                'same username). Fix it on the main phone; the corrected '
                'record will come through on the next sync.',
              ),
            ),
            for (final i in snap.data ?? const <SyncIssue>[])
              ListTile(
                title: Text(i.message),
                subtitle: Text(
                  '${i.table.replaceAll('_', ' ')} · '
                  '${formatDateTime(i.at)}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
