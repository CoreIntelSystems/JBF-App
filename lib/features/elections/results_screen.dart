import 'package:flutter/material.dart';

import '../../core/ui.dart';
import 'candidate_photo.dart';
import 'election_api.dart';

/// The result of a closed election, for every member.
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key, required this.api, required this.id});

  final ElectionApi api;
  final String id;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  Map<String, dynamic>? _r;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.api
        .results(widget.id)
        .then((r) {
          if (mounted) setState(() => _r = r);
        })
        .catchError((Object e) {
          if (mounted) setState(() => _error = electionError(e));
        });
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: r == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!),
                    ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  r['title'] as String,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  r['log_ok'] == true
                      ? 'Record checked: no step of this election was altered.'
                      : 'Warning: the election record does not check out.',
                ),
                for (final p in (r['posts'] as List).cast<Map>())
                  _PostResult(p, voters: r['voters'] as int),
              ],
            ),
    );
  }
}

class _PostResult extends StatelessWidget {
  const _PostResult(this.post, {required this.voters});
  final Map post;
  final int voters;

  @override
  Widget build(BuildContext context) {
    final candidates = (post['candidates'] as List).cast<Map>();
    final seats = post['seats'] as int;
    final ballots = post['ballots'] as int;
    final scheme = Theme.of(context).colorScheme;
    // Winners are the top [seats]; a tie for the last seat is flagged.
    final tie =
        candidates.length > seats &&
        candidates[seats - 1]['votes'] == candidates[seats]['votes'];
    final balanced = ballots == post['voted'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('${post['title']}'),
        for (var i = 0; i < candidates.length; i++)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CandidatePhoto(
                    name: candidates[i]['name'] as String,
                    photo: candidates[i]['photo'] as String?,
                    size: 56,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                candidates[i]['name'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (i < seats && !tie && ballots > 0) ...[
                              const SizedBox(width: 8),
                              const Pill('Elected', color: Color(0xFF1B8A4B)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            minHeight: 8,
                            value: ballots == 0
                                ? 0
                                : (candidates[i]['votes'] as int) / ballots,
                            color: i < seats ? scheme.primary : scheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${candidates[i]['votes']}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Text(
          '$ballots votes cast out of $voters members · '
          '${post['abstained']} abstained',
        ),
        if (tie)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'There is a tie for the last seat. The Electoral Commission '
              'decides how it is settled.',
            ),
          ),
        if (!balanced)
          Text(
            'Warning: the number of votes does not match the voted list.',
            style: TextStyle(color: scheme.error),
          ),
      ],
    );
  }
}
