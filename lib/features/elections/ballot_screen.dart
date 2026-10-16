import 'package:flutter/material.dart';

import '../../core/ui.dart';
import 'candidate_photo.dart';
import 'election_api.dart';

/// The ballot paper: one choice for each post, then a check before the vote
/// is cast. Once cast it cannot be changed, and nobody can see who voted
/// for whom.
class BallotScreen extends StatefulWidget {
  const BallotScreen({super.key, required this.api, required this.election});

  final ElectionApi api;
  final Map<String, dynamic> election;

  @override
  State<BallotScreen> createState() => _BallotScreenState();
}

class _BallotScreenState extends State<BallotScreen> {
  final _choices = <String, String>{};
  bool _sending = false;
  bool _done = false;
  String? _error;

  List<Map> get _posts => (widget.election['posts'] as List).cast<Map>();

  bool get _complete => _posts.every((p) => _choices.containsKey(p['id']));

  String _label(Map post) {
    final pick = _choices[post['id']];
    if (pick == 'abstain') return 'No one (abstain)';
    for (final c in (post['candidates'] as List).cast<Map>()) {
      if (c['id'] == pick) return c['name'] as String;
    }
    return '';
  }

  Future<void> _cast() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Check your vote'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final p in _posts)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('${p['title']}: ${_label(p)}'),
              ),
            const SizedBox(height: 8),
            const Text('You cannot change your vote after this.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cast my vote'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.api.vote(widget.election['id'] as String, _choices);
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) setState(() => _error = electionError(e));
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vote cast')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const IconBadge(Icons.check_rounded, size: 72),
                const SizedBox(height: 20),
                const Text(
                  'Your vote has been recorded.',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'It is secret. Nobody can see how you voted, and it cannot '
                  'be changed.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.election['title'] as String)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const Text(
            'Choose one candidate for each post, or abstain. Your vote is '
            'secret.',
          ),
          for (final p in _posts) ...[
            SectionTitle('${p['title']}'),
            for (final c in (p['candidates'] as List).cast<Map>())
              _Choice(
                selected: _choices[p['id']] == c['id'],
                onTap: () =>
                    setState(() => _choices['${p['id']}'] = '${c['id']}'),
                leading: CandidatePhoto(
                  name: c['name'] as String,
                  photo: c['photo'] as String?,
                  size: 72,
                ),
                title: c['name'] as String,
                subtitle: [
                  '${c['member_no'] ?? ''}',
                  if ((c['manifesto'] as String?)?.isNotEmpty ?? false)
                    c['manifesto'] as String,
                ].join('\n'),
              ),
            _Choice(
              selected: _choices[p['id']] == 'abstain',
              onTap: () => setState(() => _choices['${p['id']}'] = 'abstain'),
              leading: const IconBadge(Icons.block_outlined, size: 48),
              title: 'Abstain',
              subtitle: 'I do not choose anyone for this post.',
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _complete && !_sending ? _cast : null,
            child: Text(_sending ? 'Casting...' : 'Review and cast my vote'),
          ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.onTap,
    required this.leading,
    required this.title,
    required this.subtitle,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? scheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if (subtitle.trim().isNotEmpty) Text(subtitle),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? scheme.primary : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
