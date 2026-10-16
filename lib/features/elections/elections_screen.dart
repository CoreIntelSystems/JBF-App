import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../core/ui.dart';
import '../../data/sync/sync_api.dart';
import '../chats/chats_screen.dart' show ChatAccess;
import '../offices/office_api.dart';
import '../offices/office_screen.dart';
import 'election_screen.dart';
import 'commission_screen.dart';
import 'election_admin.dart';
import 'election_api.dart';

/// Every election the member can see. The Electoral Commission also gets
/// the button to start one.
class ElectionsScreen extends StatefulWidget {
  const ElectionsScreen({super.key, required this.access});

  final ChatAccess access;

  @override
  State<ElectionsScreen> createState() => _ElectionsScreenState();
}

class _ElectionsScreenState extends State<ElectionsScreen> {
  late final _api = ElectionApi(
    context.read<AppServices>().sync.api,
    widget.access.token,
  );
  late final _office = OfficeApi(
    context.read<AppServices>().sync.api,
    widget.access.token,
  );
  bool _isEc = false;
  List<Map<String, dynamic>>? _items;
  List<Map<String, dynamic>> _notices = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _office
        .notices(committee: 'ec')
        .then((n) {
          if (mounted) setState(() => _notices = n);
        })
        .catchError((Object _) {});
    try {
      final r = await _api.list();
      if (!mounted) return;
      setState(() {
        _isEc = r.isEc;
        _items = r.elections;
        _error = null;
      });
    } on SyncException catch (e) {
      if (mounted) setState(() => _error = electionError(e));
    }
  }

  Future<void> _open(Map<String, dynamic> e) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ElectionScreen(api: _api, id: e['id'] as String, isEc: _isEc),
      ),
    );
    _load();
  }

  Future<void> _create() async {
    final made = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => CreateElectionScreen(api: _api)),
    );
    if (made != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Elections')),
      floatingActionButton: _isEc
          ? FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.how_to_vote_outlined),
              label: const Text('New election'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Card(
              child: ListTile(
                leading: const IconBadge(Icons.balance_rounded),
                title: const Text(
                  'Electoral Commission',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Who runs the elections'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CommissionScreen(api: _api),
                  ),
                ),
              ),
            ),
            if (_isEc)
              Card(
                child: ListTile(
                  leading: const IconBadge(Icons.work_outline_rounded),
                  title: const Text(
                    'Commission office',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Tasks, minutes, notices, voter roll and chat',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => OfficeScreen(
                          api: _office,
                          committee: 'ec',
                          title: 'Electoral Commission',
                        ),
                      ),
                    );
                    _load();
                  },
                ),
              ),
            for (final n in _notices)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.campaign_outlined),
                  title: Text(
                    '${n['title']}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    [
                      '${n['body']}',
                      [
                        'From the ${n['from'] ?? 'Electoral Commission'}',
                        if (DateTime.tryParse('${n['at']}') case final at?)
                          formatDate(at),
                      ].join(' · '),
                    ].join('\n'),
                  ),
                  isThreeLine: true,
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_error!),
              ),
            if (items == null && _error == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (items != null && items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('There are no elections yet.'),
              ),
            for (final e in items ?? const <Map<String, dynamic>>[])
              Card(
                child: ListTile(
                  leading: const IconBadge(Icons.how_to_vote_rounded),
                  title: Text(
                    e['title'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(_subtitle(e)),
                  trailing: _StatusPill(e),
                  onTap: () => _open(e),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _subtitle(Map<String, dynamic> e) {
    final closes = DateTime.tryParse('${e['closes_at']}');
    return switch (e['status']) {
      'open' => 'Closes ${closes == null ? '' : formatDateTime(closes)}',
      'closed' => 'Voting closed',
      'cancelled' => 'Cancelled',
      _ => 'Being prepared',
    };
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.e);
  final Map<String, dynamic> e;

  @override
  Widget build(BuildContext context) {
    final open = e['status'] == 'open';
    if (open && e['can_vote'] == true && e['voted_all'] != true) {
      return const Pill('Vote now', color: Color(0xFF1B8A4B));
    }
    if (open && e['voted_all'] == true) {
      return const Pill('Voted', color: Color(0xFF1B8A4B));
    }
    return Pill(switch (e['status']) {
      'open' => 'Open',
      'closed' => 'Results',
      'cancelled' => 'Cancelled',
      _ => 'Draft',
    }, color: e['status'] == 'closed' ? null : Colors.grey.shade600);
  }
}
