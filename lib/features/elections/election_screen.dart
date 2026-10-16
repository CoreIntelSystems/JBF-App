import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/ui.dart';
import 'ballot_screen.dart';
import 'candidate_photo.dart';
import 'election_admin.dart';
import 'election_api.dart';
import 'results_screen.dart';

/// One election: the posts and candidates, and what the member can do.
class ElectionScreen extends StatefulWidget {
  const ElectionScreen({
    super.key,
    required this.api,
    required this.id,
    required this.isEc,
  });

  final ElectionApi api;
  final String id;
  final bool isEc;

  @override
  State<ElectionScreen> createState() => _ElectionScreenState();
}

class _ElectionScreenState extends State<ElectionScreen> {
  Map<String, dynamic>? _e;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final e = await widget.api.get(widget.id);
      if (mounted) {
        setState(() {
          _e = e;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = electionError(e));
    }
  }

  Future<void> _act(
    Future<void> Function() run, {
    required String confirm,
    required String done,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, continue'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await run();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(electionError(e))));
    }
    if (mounted) setState(() => _busy = false);
    _load();
  }

  Future<void> _vote() async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BallotScreen(api: widget.api, election: _e!),
      ),
    );
    if (done == true) _load();
  }

  Future<void> _history() async {
    try {
      final h = await widget.api.history(widget.id);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            shrinkWrap: true,
            children: [
              const Text(
                'Election record',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              const SizedBox(height: 8),
              for (final x in h)
                ListTile(
                  dense: true,
                  title: Text('${x['event']}'.toUpperCase()),
                  subtitle: Text(
                    [
                      formatDateTime(DateTime.parse('${x['at']}')),
                      if (x['by'] != null) '${x['by']}',
                      if (x['detail'] != null) '${x['detail']}',
                    ].join(' · '),
                  ),
                ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(electionError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    return Scaffold(
      appBar: AppBar(
        title: Text(e?['title'] as String? ?? 'Election'),
        actions: [
          if (widget.isEc && e != null)
            IconButton(
              tooltip: 'Election record',
              icon: const Icon(Icons.fact_check_outlined),
              onPressed: _history,
            ),
        ],
      ),
      body: e == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!),
                    ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [..._header(e), ..._posts(e)],
              ),
            ),
    );
  }

  List<Widget> _header(Map<String, dynamic> e) {
    final status = e['status'] as String;
    final closes = DateTime.tryParse('${e['closes_at']}');
    final posts = (e['posts'] as List).cast<Map>();
    final votedAll = posts.isNotEmpty && posts.every((p) => p['voted'] == true);
    final canVote = e['can_vote'] == true && !votedAll;
    final isEc = widget.isEc;
    return [
      if ((e['notes'] as String?)?.isNotEmpty ?? false)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(e['notes'] as String),
        ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(switch (status) {
                'open' =>
                  'Voting is open until '
                      '${closes == null ? '' : formatDateTime(closes)}',
                'closed' => 'Voting has closed',
                'cancelled' => 'This election was cancelled',
                _ => 'Being prepared. Voting has not opened.',
              }, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (status == 'open' || status == 'closed') ...[
                const SizedBox(height: 4),
                Text('${e['voters']} members may vote.'),
              ],
              if (status == 'open' && votedAll) ...[
                const SizedBox(height: 8),
                const Text(
                  'You have voted. Your vote is secret and cannot be '
                  'changed.',
                ),
              ],
              if (status == 'open' &&
                  e['can_vote'] != true &&
                  !isEc &&
                  !votedAll) ...[
                const SizedBox(height: 8),
                const Text(
                  'You were not on the voters list when this election opened.',
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (status == 'open' && canVote)
                    FilledButton.icon(
                      onPressed: _busy ? null : _vote,
                      icon: const Icon(Icons.how_to_vote_rounded),
                      label: const Text('Vote now'),
                    ),
                  if (status == 'closed')
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ResultsScreen(api: widget.api, id: widget.id),
                        ),
                      ),
                      icon: const Icon(Icons.emoji_events_outlined),
                      label: const Text('See results'),
                    ),
                  if (isEc && status == 'draft') ...[
                    FilledButton(
                      onPressed: _busy || e['created_by_me'] == true
                          ? null
                          : () => _act(
                              () => widget.api.open(widget.id),
                              confirm:
                                  'Open voting now? The voters list is fixed '
                                  'at this moment and candidates can no '
                                  'longer change.',
                              done: 'Voting is open.',
                            ),
                      child: const Text('Open voting'),
                    ),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _act(
                              () => widget.api.cancel(widget.id),
                              confirm: 'Cancel this election?',
                              done: 'Election cancelled.',
                            ),
                      child: const Text('Cancel election'),
                    ),
                  ],
                  if (isEc && status == 'open')
                    OutlinedButton(
                      onPressed: _busy || e['opened_by_me'] == true
                          ? null
                          : () => _act(
                              () => widget.api.close(widget.id),
                              confirm:
                                  'Close voting now? Nobody can vote after '
                                  'this and the results become visible.',
                              done: 'Voting closed.',
                            ),
                      child: const Text('Close voting early'),
                    ),
                ],
              ),
              if (isEc && status == 'draft' && e['created_by_me'] == true)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'A different Commission officer must open this election.',
                  ),
                ),
              if (isEc && status == 'open' && e['opened_by_me'] == true)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'A different Commission officer must close it early.',
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _posts(Map<String, dynamic> e) {
    final draft = e['status'] == 'draft';
    return [
      for (final p in (e['posts'] as List).cast<Map>()) ...[
        SectionTitle(
          '${p['title']}${(p['seats'] as int) > 1 ? ' · ${p['seats']} seats' : ''}',
          trailing: draft && widget.isEc
              ? TextButton.icon(
                  onPressed: () async {
                    final added = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => CandidateEditor(
                          api: widget.api,
                          postId: p['id'] as String,
                          postTitle: p['title'] as String,
                        ),
                      ),
                    );
                    if (added == true) _load();
                  },
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: const Text('Add candidate'),
                )
              : null,
        ),
        if ((p['candidates'] as List).isEmpty) const Text('No candidates yet.'),
        for (final c in (p['candidates'] as List).cast<Map>())
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CandidatePhoto(
                    name: c['name'] as String,
                    photo: c['photo'] as String?,
                    size: 72,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['name'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text('${c['member_no'] ?? ''}'),
                        if ((c['manifesto'] as String?)?.isNotEmpty ?? false)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(c['manifesto'] as String),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (e['status'] == 'open' && widget.isEc && p['turnout'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${p['turnout']} votes cast so far (counts stay hidden).',
            ),
          ),
      ],
    ];
  }
}
