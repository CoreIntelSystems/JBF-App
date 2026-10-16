import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/sync/sync_api.dart' show ChatChannel;
import '../chats/chats_screen.dart';
import '../discipline/discipline_screen.dart';
import 'office_api.dart';

/// A committee's digital office: its people, tasks, minutes and decisions,
/// notices to members and a private chat. The Electoral Commission's office
/// also shows its elections with their checklists and the voter roll.
/// Only the committee's own members get in; the cloud checks every call.
class OfficeScreen extends StatefulWidget {
  const OfficeScreen({
    super.key,
    required this.api,
    required this.committee,
    required this.title,
  });

  final OfficeApi api;
  final String committee;
  final String title;

  @override
  State<OfficeScreen> createState() => _OfficeScreenState();
}

class _OfficeScreenState extends State<OfficeScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 4, vsync: this)
    ..addListener(() => setState(() {}));
  Map<String, dynamic>? _home;
  String? _error;
  String _taskFilter = 'open';

  OfficeApi get _api => widget.api;
  String get _c => widget.committee;
  bool get _lead => _home?['lead'] == true;
  String? get _me => _home?['me'] as String?;

  List<Map<String, dynamic>> _items(String key) => [
    for (final x in (_home?[key] as List?) ?? const [])
      Map<String, dynamic>.from(x as Map),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final h = await _api.home(_c);
      if (mounted) {
        setState(() {
          _home = h;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = officeError(e));
    }
  }

  /// Runs a change, says how it went and reloads the office.
  Future<bool> _run(Future<void> Function() change, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await change();
      messenger.showSnackBar(SnackBar(content: Text(done)));
      await _load();
      return true;
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(officeError(e))));
      return false;
    }
  }

  Future<bool> _confirm(String question, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(question),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(action),
            ),
          ],
        ),
      ) ==
      true;

  void _openChat() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChatScreen(
        access: ChatAccess(_api.token),
        channel: ChatChannel(
          id: '${_home?['chat'] ?? 'office:$_c'}',
          name: widget.title,
          canPost: true,
        ),
      ),
    ),
  );

  // ---------- tasks ----------

  Future<void> _editTask([Map<String, dynamic>? task]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TaskSheet(
        task: task,
        members: _items('members'),
        elections: _items('elections'),
        canRemove: task != null && (_lead || task['mine'] == true),
        onSave: (t) => _run(
          () => _api.saveTask(
            _c,
            id: task?['id'] as String?,
            title: t.title,
            details: t.details,
            assignee: t.assignee,
            dueOn: t.dueOn,
            electionId: t.electionId,
          ),
          task == null ? 'Task added.' : 'Task saved.',
        ),
        onRemove: () async {
          if (!await _confirm('Remove this task?', 'Remove')) return false;
          return _run(
            () => _api.removeTask(_c, task!['id'] as String),
            'Task removed.',
          );
        },
      ),
    );
    if (saved == true && mounted) setState(() {});
  }

  bool _canEditTask(Map<String, dynamic> t) =>
      _lead ||
      t['mine'] == true ||
      (t['assignee'] != null && t['assignee'] == _me);

  Widget _tasksTab() {
    final elections = {
      for (final e in _items('elections')) e['id']: '${e['title']}',
      for (final c in _cases())
        c['id']: 'Case: ${c['member_name'] ?? 'member'}',
      for (final e in _items('events')) e['id']: '${e['name']}',
      for (final w in _welfareCases())
        w['id']: '${w['case_no'] ?? 'Case'} · ${w['member_name'] ?? 'member'}',
      for (final m in _items('meetings')) m['id']: '${m['title']}',
      for (final m in _councilMeetings()) m['id']: '${m['title']}',
    };
    final tasks = _items('tasks').where((t) {
      return switch (_taskFilter) {
        'mine' => t['assignee'] == _me && t['status'] == 'open',
        'done' => t['status'] == 'done',
        _ => t['status'] == 'open',
      };
    }).toList();
    return _refreshable([
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'open', label: Text('To do')),
          ButtonSegment(value: 'mine', label: Text('Mine')),
          ButtonSegment(value: 'done', label: Text('Done')),
        ],
        selected: {_taskFilter},
        onSelectionChanged: (s) => setState(() => _taskFilter = s.first),
      ),
      const SizedBox(height: 12),
      if (tasks.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(switch (_taskFilter) {
            'mine' => 'Nothing is waiting on you.',
            'done' => 'Nothing has been finished yet.',
            _ => 'No open tasks. Add one with the button below.',
          }, textAlign: TextAlign.center),
        ),
      if (tasks.isNotEmpty)
        GroupCard(
          children: [
            for (final t in tasks)
              ListTile(
                contentPadding: const EdgeInsets.only(left: 4, right: 16),
                leading: Checkbox(
                  value: t['status'] == 'done',
                  onChanged: (v) => _run(
                    () => _api.setTaskDone(_c, t['id'] as String, v == true),
                    v == true ? 'Marked done.' : 'Opened again.',
                  ),
                ),
                title: Text(
                  '${t['title']}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: t['status'] == 'done'
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                subtitle: _taskLine(t, elections),
                onTap: () =>
                    _canEditTask(t) ? _editTask(t) : _showTask(t, elections),
              ),
          ],
        ),
    ]);
  }

  Widget? _taskLine(Map<String, dynamic> t, Map<Object?, String> elections) {
    final due = DateTime.tryParse('${t['due_on']}');
    final late =
        due != null &&
        t['status'] == 'open' &&
        due.isBefore(DateTime.now().subtract(const Duration(days: 1)));
    final parts = [
      if (t['status'] == 'done' && t['done_by'] != null)
        'Done by ${t['done_by']}'
      else if (t['assignee_name'] != null)
        '${t['assignee_name']}',
      if (due != null) '${late ? 'Was due' : 'Due'} ${formatDate(due)}',
      if (elections[t['election_id']] != null) elections[t['election_id']]!,
      if (elections[t['case_id']] != null) elections[t['case_id']]!,
      if (elections[t['event_id']] != null) elections[t['event_id']]!,
      if (elections[t['welfare_case_id']] != null)
        elections[t['welfare_case_id']]!,
      if (elections[t['meeting_id']] != null) elections[t['meeting_id']]!,
      if (t['period'] != null) 'Month end: ${formatPeriod('${t['period']}')}',
    ];
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' · '),
      style: late
          ? TextStyle(color: Theme.of(context).colorScheme.error)
          : null,
    );
  }

  void _showTask(Map<String, dynamic> t, Map<Object?, String> elections) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${t['title']}'),
        content: Text(
          [
            if (t['details'] != null) '${t['details']}',
            'Added by ${t['by'] ?? 'a member'}.',
            'Only the person who added it, the person doing it or the '
                'Chairperson and Secretary can change it.',
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ---------- minutes and decisions ----------

  Future<void> _editNote([Map<String, dynamic>? note]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _NoteEditor(
          note: note,
          onSave: (n) => _run(
            () => _api.saveNote(
              _c,
              id: note?['id'] as String?,
              kind: n.kind,
              title: n.title,
              body: n.body,
              metOn: n.metOn,
            ),
            note == null ? 'Saved to the office.' : 'Changes saved.',
          ),
        ),
      ),
    );
  }

  void _openNote(Map<String, dynamic> n) {
    final canEdit = _lead || n['mine'] == true;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(_kindNames[n['kind']] ?? 'Note'),
            actions: [
              if (canEdit)
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _editNote(n);
                  },
                ),
              if (canEdit)
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    if (!await _confirm('Remove "${n['title']}"?', 'Remove')) {
                      return;
                    }
                    if (await _run(
                      () => _api.removeNote(_c, n['id'] as String),
                      'Removed.',
                    )) {
                      nav.pop();
                    }
                  },
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${n['title']}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                _noteLine(n),
                style: TextStyle(color: Tones.of(context).muted),
              ),
              const SizedBox(height: 16),
              SelectableText('${n['body']}'),
            ],
          ),
        ),
      ),
    );
  }

  static const _kindNames = {
    'meeting': 'Meeting minutes',
    'decision': 'Decision',
    'note': 'Note',
  };

  static String _noteLine(Map<String, dynamic> n) {
    final met = DateTime.tryParse('${n['met_on']}');
    final at = DateTime.tryParse('${n['at']}');
    return [
      _kindNames[n['kind']] ?? 'Note',
      if (met != null) formatDate(met) else if (at != null) formatDate(at),
      if (n['by'] != null) 'by ${n['by']}',
    ].join(' · ');
  }

  Widget _notesTab() {
    final notes = _items('notes');
    return _refreshable([
      if (notes.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Write up meetings and record decisions here so every member '
            'of the office can find them later.',
            textAlign: TextAlign.center,
          ),
        ),
      if (notes.isNotEmpty)
        GroupCard(
          children: [
            for (final n in notes)
              ListTile(
                leading: IconBadge(switch (n['kind']) {
                  'meeting' => Icons.groups_outlined,
                  'decision' => Icons.gavel_rounded,
                  _ => Icons.sticky_note_2_outlined,
                }, size: 36),
                title: Text(
                  '${n['title']}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(_noteLine(n)),
                onTap: () => _openNote(n),
              ),
          ],
        ),
    ]);
  }

  // ---------- notices ----------

  Future<void> _postNotice() async {
    final r = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _NoticeDialog(),
    );
    if (r == null) return;
    await _run(
      () => _api.postNotice(_c, r.$1, r.$2),
      'Notice posted to every member.',
    );
  }

  Widget _noticesTab() {
    final notices = _items('notices');
    return _refreshable([
      Text(
        'Notices appear for every member on their home page'
        '${_c == 'ec' ? ' and at the top of Elections' : ''}, in the app '
        'and on the member website. '
        '${_lead ? 'You can post and withdraw them.' : 'The Chairperson and Secretary post them.'}',
        style: TextStyle(color: Tones.of(context).muted),
      ),
      const SizedBox(height: 12),
      if (notices.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('No notices yet.', textAlign: TextAlign.center),
        ),
      for (final n in notices)
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${n['title']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (n['withdrawn'] == true)
                      Pill('Withdrawn', color: Colors.grey.shade600)
                    else if (_lead)
                      TextButton(
                        onPressed: () async {
                          if (!await _confirm(
                            'Withdraw this notice? Members will no longer see it.',
                            'Withdraw',
                          )) {
                            return;
                          }
                          await _run(
                            () => _api.withdrawNotice(_c, n['id'] as String),
                            'Notice withdrawn.',
                          );
                        },
                        child: const Text('Withdraw'),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${n['body']}'),
                const SizedBox(height: 6),
                Text(
                  [
                    if (DateTime.tryParse('${n['at']}') case final at?)
                      formatDateTime(at),
                    if (n['by'] != null) '${n['by']}',
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 12,
                    color: Tones.of(context).muted,
                  ),
                ),
              ],
            ),
          ),
        ),
    ]);
  }

  // ---------- overview ----------

  Widget _overviewTab() {
    final h = _home!;
    final members = _items('members');
    final elections = _items('elections');
    final log = _items('log');
    final roll = h['roll'] is Map
        ? Map<String, dynamic>.from(h['roll'] as Map)
        : null;
    return _refreshable([
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (h['purpose'] != null) Text('${h['purpose']}'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Pill('You: ${h['role_name']}'),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _openChat,
                    icon: const Icon(Icons.forum_outlined),
                    label: const Text('Office chat'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      if (h.containsKey('elections')) ...[
        const SectionTitle('Elections'),
        if (elections.isEmpty)
          const Text(
            'No elections yet. Prepare one from More > Elections; it then '
            'appears here with its checklist.',
          ),
        for (final e in elections) _electionCard(e),
      ],
      if (roll != null) ..._rollSection(roll),
      if (h['cases'] is Map) ..._casesSection(),
      if (h['events'] is List) ..._eventsSection(),
      if (h['welfare'] is Map) ..._welfareSection(),
      if (h['register'] is Map) ..._registerSection(),
      if (h['meetings'] is List) ..._meetingsSection(),
      if (h['treasury'] is Map) ..._treasurySection(),
      if (h['council'] is Map) ..._councilSection(),
      SectionTitle('Members (${members.length})'),
      GroupCard(
        children: [
          for (final m in members)
            ListTile(
              leading: InitialsAvatar('${m['name']}', size: 36),
              title: Text('${m['name']}'),
              subtitle: Text('${m['member_no'] ?? ''}'),
              trailing: Pill('${m['role_name']}'),
            ),
        ],
      ),
      if (log.isNotEmpty) ...[
        const SectionTitle('Recent activity'),
        GroupCard(
          children: [
            for (final l in log.take(15))
              ListTile(
                dense: true,
                title: Text(
                  '${l['by'] ?? 'Someone'}: ${l['event']}'
                  '${l['detail'] == null ? '' : ' "${l['detail']}"'}',
                ),
                subtitle: Text(
                  DateTime.tryParse('${l['at']}') == null
                      ? ''
                      : formatDateTime(DateTime.parse('${l['at']}')),
                ),
              ),
          ],
        ),
      ],
    ]);
  }

  Widget _electionCard(Map<String, dynamic> e) {
    final steps = (e['steps'] as num?)?.toInt() ?? 0;
    final done = (e['steps_done'] as num?)?.toInt() ?? 0;
    final voters = (e['voters'] as num?)?.toInt() ?? 0;
    final voted = (e['voted'] as num?)?.toInt();
    final closes = DateTime.tryParse('${e['closes_at']}');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${e['title']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                Pill(switch (e['status']) {
                  'open' => 'Voting open',
                  'closed' => 'Closed',
                  _ => 'Being prepared',
                }),
              ],
            ),
            if (closes != null && e['status'] != 'closed')
              Text('Voting closes ${formatDateTime(closes)}'),
            if (voted != null) Text('$voted of $voters members have voted'),
            const SizedBox(height: 10),
            if (steps > 0) ...[
              Text('Checklist: $done of $steps steps done'),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: done / steps,
                  minHeight: 8,
                ),
              ),
            ] else if (_lead && _home?['has_checklist'] == true)
              OutlinedButton.icon(
                onPressed: () => _run(
                  () => _api.addChecklist(_c, e['id'] as String),
                  'Standard steps added to Tasks.',
                ),
                icon: const Icon(Icons.checklist_rounded),
                label: const Text('Add the standard steps'),
              )
            else
              const Text('No checklist yet.'),
          ],
        ),
      ),
    );
  }

  // ---------- Leadership Council: the association at a glance ----------

  List<Map<String, dynamic>> _councilMeetings() {
    final c = _home?['council'];
    if (c is! Map) return const [];
    return [
      for (final x in (c['meetings'] as List?) ?? const [])
        Map<String, dynamic>.from(x as Map),
    ];
  }

  List<Widget> _councilSection() {
    final c = Map<String, dynamic>.from(_home!['council'] as Map);
    final zones = [
      for (final x in (c['zones'] as List?) ?? const [])
        Map<String, dynamic>.from(x as Map),
    ];
    final waiting = Map<String, dynamic>.from(
      (c['waiting'] as Map?) ?? const {},
    );
    int w(String k) => (waiting[k] as num?)?.toInt() ?? 0;
    final positions = [
      for (final p in (c['positions'] as List?) ?? const []) '$p',
    ];
    final decisions = [
      if (w('dues_amounts') > 0)
        '${w('dues_amounts')} dues ${w('dues_amounts') == 1 ? 'amount' : 'amounts'} waiting for approval',
      if (w('benefit_amounts') > 0)
        '${w('benefit_amounts')} welfare benefit ${w('benefit_amounts') == 1 ? 'amount' : 'amounts'} waiting for approval',
      if (w('welfare_cases') > 0)
        '${w('welfare_cases')} welfare ${w('welfare_cases') == 1 ? 'case' : 'cases'} waiting for approval',
      if (w('complaints') > 0)
        '${w('complaints')} open ${w('complaints') == 1 ? 'complaint' : 'complaints'} with the Disciplinary Committee',
      if (positions.isNotEmpty) 'No one holds: ${positions.join(', ')}',
    ];
    final meetings = _councilMeetings();
    return [
      const SectionTitle('Waiting for the Council'),
      if (decisions.isEmpty)
        const Text('Nothing is waiting for a decision.')
      else
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final d in decisions)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text('• $d'),
                  ),
              ],
            ),
          ),
        ),
      SectionTitle('Zones (${formatPeriod('${c['month']}')})'),
      GroupCard(
        children: [
          for (final z in zones)
            ListTile(
              leading: IconBadge(Icons.location_city_outlined, size: 36),
              title: Text(
                '${z['name']}'
                '${z['mayor'] == null ? '' : ' · Mayor ${z['mayor']}'}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                [
                  '${z['members']} members',
                  '${z['executives']} of 6 executives',
                  '${z['dues_paid']} paid dues',
                  if (((z['missing'] as List?) ?? const []).isNotEmpty)
                    'Missing: ${(z['missing'] as List).join(', ')}',
                ].join(' · '),
              ),
            ),
        ],
      ),
      const SectionTitle('Council meetings'),
      if (meetings.isEmpty)
        const Text(
          'No executive or general meetings yet. Add them in More > Events '
          'and meetings; the Founder or General Secretary can then add the '
          'Council meeting steps.',
        ),
      for (final m in meetings) _meetingCard(m),
    ];
  }

  // ---------- Treasury: this month's money ----------

  List<Widget> _treasurySection() {
    final t = Map<String, dynamic>.from(_home!['treasury'] as Map);
    int n(String k) => (t[k] as num?)?.toInt() ?? 0;
    List<Map<String, dynamic>> rows(String k) => [
      for (final x in (t[k] as List?) ?? const [])
        Map<String, dynamic>.from(x as Map),
    ];
    final month = formatPeriod('${t['month']}');
    final zoneOnly = t['zone_only'] == true;
    final dues = t['dues'] is Map
        ? Map<String, dynamic>.from(t['dues'] as Map)
        : null;
    final proposals = rows('proposals');
    final unset = n('unset_dues');
    Widget breakdown(String title, List<Map<String, dynamic>> items) =>
        GroupCard(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            for (final x in items)
              ListTile(
                dense: true,
                title: Text('${x['name']}'),
                subtitle: Text(
                  '${x['count']} ${x['count'] == 1 ? 'receipt' : 'receipts'}',
                ),
                trailing: Text(
                  formatMoney((x['amount'] as num).toInt()),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        );
    return [
      SectionTitle(zoneOnly ? '$month in your zones' : month),
      Row(
        children: [
          Expanded(
            child: MetricTile(
              label: 'Received',
              value: formatMoney(n('received')),
              icon: Icons.south_west_rounded,
            ),
          ),
          if (!zoneOnly) ...[
            const SizedBox(width: 12),
            Expanded(
              child: MetricTile(
                label: 'Paid out',
                value: formatMoney(n('spent') + n('welfare_paid')),
                icon: Icons.north_east_rounded,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 8),
      Text(
        [
          '${n('receipts')} ${n('receipts') == 1 ? 'receipt' : 'receipts'}',
          if (n('voided') > 0) '${n('voided')} voided',
          if (!zoneOnly && n('welfare_paid') > 0)
            '${formatMoney(n('welfare_paid'))} of it welfare',
          if (!zoneOnly && n('to_pay') > 0)
            '${formatMoney(n('to_pay'))} welfare approved, still to pay',
        ].join(' · '),
      ),
      if (dues != null) ...[
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${dues['name']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dues['amount'] == null
                      ? 'No amount set yet.'
                      : '${dues['paid']} of ${dues['active']} active members '
                            'have paid for $month '
                            '(${formatMoney((dues['amount'] as num).toInt())} each).',
                ),
                if (dues['amount'] != null &&
                    ((dues['active'] as num?) ?? 0) > 0) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value:
                          ((dues['paid'] as num?) ?? 0) /
                          (dues['active'] as num),
                      minHeight: 8,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
      if (proposals.isNotEmpty || unset > 0)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Amounts waiting',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                for (final p in proposals)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${p['name']}: '
                      '${p['amount'] == null ? 'set' : 'change ${formatMoney((p['amount'] as num).toInt())}'} '
                      'to ${formatMoney((p['proposed'] as num).toInt())}, '
                      'waiting for the Founder or General Secretary',
                    ),
                  ),
                if (unset > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '$unset monthly ${unset == 1 ? 'due has' : 'dues have'} '
                      'no amount yet. Set it in More > Contribution types.',
                    ),
                  ),
              ],
            ),
          ),
        ),
      if (rows('by_type').isNotEmpty) ...[
        const SizedBox(height: 8),
        breakdown('By contribution', rows('by_type')),
      ],
      if (rows('by_collector').isNotEmpty) ...[
        const SizedBox(height: 8),
        breakdown('By collector', rows('by_collector')),
      ],
      if (rows('months').isNotEmpty) ...[
        const SectionTitle('Month end'),
        for (final m in rows('months')) _monthCard(m),
      ],
    ];
  }

  Widget _monthCard(Map<String, dynamic> m) {
    final steps = (m['steps'] as num?)?.toInt() ?? 0;
    final done = (m['steps_done'] as num?)?.toInt() ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatPeriod('${m['period']}'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            if (steps > 0) ...[
              const SizedBox(height: 6),
              Text('$done of $steps steps done'),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: done / steps,
                  minHeight: 8,
                ),
              ),
            ] else if (_lead)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: OutlinedButton.icon(
                  onPressed: () => _run(
                    () => _api.addMonthSteps(_c, '${m['period']}'),
                    'Month-end steps added to Tasks.',
                  ),
                  icon: const Icon(Icons.checklist_rounded),
                  label: const Text('Add the month-end steps'),
                ),
              )
            else
              const Text('No month-end steps yet.'),
          ],
        ),
      ),
    );
  }

  // ---------- Secretariat: the register and meetings ----------

  List<Widget> _registerSection() {
    final r = Map<String, dynamic>.from(_home!['register'] as Map);
    int n(String k) => (r[k] as num?)?.toInt() ?? 0;
    final active = n('active');
    final changes = [
      for (final x in (r['changes'] as List?) ?? const [])
        Map<String, dynamic>.from(x as Map),
    ];
    final gaps = [
      if (n('no_zone') > 0)
        '${n('no_zone')} active members have not picked their zone yet',
      if (n('no_phone') > 0) '${n('no_phone')} have no phone number',
      if (n('no_emergency') > 0)
        '${n('no_emergency')} have no emergency contact',
      if (active - n('ready') > 0)
        '${active - n('ready')} have not activated their sign-in',
    ];
    return [
      const SectionTitle('Membership register'),
      Row(
        children: [
          Expanded(
            child: MetricTile(
              label: 'Active members',
              value: '$active',
              icon: Icons.groups_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MetricTile(
              label: 'Signed in',
              value: '${n('ready')}',
              icon: Icons.verified_user_outlined,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ],
      ),
      if (n('suspended') + n('inactive') + n('deceased') > 0) ...[
        const SizedBox(height: 8),
        Text(
          [
            if (n('suspended') > 0) '${n('suspended')} suspended',
            if (n('inactive') > 0) '${n('inactive')} inactive',
            if (n('deceased') > 0) '${n('deceased')} deceased',
          ].join(' · '),
        ),
      ],
      if (gaps.isNotEmpty) ...[
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Records to complete',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                for (final g in gaps)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('• $g.'),
                  ),
              ],
            ),
          ),
        ),
      ],
      if (changes.isNotEmpty) ...[
        const SizedBox(height: 8),
        GroupCard(
          children: [
            for (final c in changes)
              ListTile(
                leading: InitialsAvatar('${c['name']}', size: 36),
                title: Text('${c['name']} · ${c['member_no']}'),
                subtitle: Text(
                  [
                    switch (c['status']) {
                      'suspended' => 'Suspended',
                      'deceased' => 'Deceased',
                      _ => 'Inactive',
                    },
                    if (DateTime.tryParse('${c['on']}') case final on?)
                      formatDate(on),
                  ].join(' · '),
                ),
              ),
          ],
        ),
      ],
    ];
  }

  List<Widget> _meetingsSection() {
    final meetings = _items('meetings');
    return [
      const SectionTitle('Meetings'),
      if (meetings.isEmpty)
        const Text(
          'No meetings yet. Add them in More > Events and meetings; they then '
          'appear here, and the General Secretary can add the meeting steps.',
        ),
      for (final m in meetings) _meetingCard(m),
    ];
  }

  Widget _meetingCard(Map<String, dynamic> m) {
    final upcoming = m['upcoming'] == true;
    final steps = (m['steps'] as num?)?.toInt() ?? 0;
    final done = (m['steps_done'] as num?)?.toInt() ?? 0;
    final present = (m['present'] as num?)?.toInt() ?? 0;
    final on = DateTime.tryParse('${m['held_on']}');
    final minutes = m['has_minutes'] == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${m['title']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                Pill(
                  upcoming
                      ? 'Coming up'
                      : minutes
                      ? 'Minutes kept'
                      : 'No minutes yet',
                  color: upcoming
                      ? null
                      : minutes
                      ? Colors.grey.shade600
                      : Theme.of(context).colorScheme.error,
                ),
              ],
            ),
            Text(
              [
                if (on != null) formatDateTime(on),
                if (m['zone'] != null) '${m['zone']}',
                if (m['venue'] != null) '${m['venue']}',
              ].join(' · '),
            ),
            if (!upcoming || present > 0) Text('$present attended'),
            if (upcoming && m['has_agenda'] != true)
              Text(
                'No agenda yet',
                style: TextStyle(fontSize: 12, color: Tones.of(context).muted),
              ),
            if (steps > 0) ...[
              const SizedBox(height: 10),
              Text('Meeting steps: $done of $steps done'),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: done / steps,
                  minHeight: 8,
                ),
              ),
            ] else if (_lead)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: OutlinedButton.icon(
                  onPressed: () => _run(
                    () => _api.addMeetingSteps(_c, m['id'] as String),
                    'Meeting steps added to Tasks.',
                  ),
                  icon: const Icon(Icons.checklist_rounded),
                  label: const Text('Add the meeting steps'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- Welfare Committee: cases and benefits ----------

  List<Map<String, dynamic>> _welfareCases() {
    final w = _home?['welfare'];
    if (w is! Map) return const [];
    return [
      for (final x in (w['recent'] as List?) ?? const [])
        Map<String, dynamic>.from(x as Map),
    ];
  }

  List<Widget> _welfareSection() {
    final w = Map<String, dynamic>.from(_home!['welfare'] as Map);
    final cases = _welfareCases();
    final proposals = [
      for (final x in (w['proposals'] as List?) ?? const [])
        Map<String, dynamic>.from(x as Map),
    ];
    final unset = (w['unset_types'] as num?)?.toInt() ?? 0;
    final toPay = (w['to_pay'] as num?)?.toInt() ?? 0;
    final paidTotal = (w['paid_total'] as num?)?.toInt() ?? 0;
    return [
      const SectionTitle('Welfare cases'),
      Row(
        children: [
          Expanded(
            child: MetricTile(
              label: 'Waiting for approval',
              value: '${w['pending'] ?? 0}',
              icon: Icons.hourglass_top_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MetricTile(
              label: 'Approved, to pay',
              value: '${w['approved'] ?? 0}',
              icon: Icons.payments_outlined,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        [
          if (toPay > 0) '${formatMoney(toPay)} still to pay',
          '${formatMoney(paidTotal)} paid on ${w['paid'] ?? 0} '
              '${w['paid'] == 1 ? 'case' : 'cases'}',
        ].join(' · '),
      ),
      if (proposals.isNotEmpty || unset > 0) ...[
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Benefit amounts',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                for (final p in proposals)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${p['name']}: '
                      '${p['amount'] == null ? 'change' : '${formatMoney((p['amount'] as num).toInt())} to'} '
                      '${formatMoney((p['proposed'] as num).toInt())}, '
                      'waiting for the Chairman'
                      '${p['by'] == null ? '' : ' (proposed by ${p['by']})'}',
                    ),
                  ),
                if (unset > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '$unset case ${unset == 1 ? 'type has' : 'types have'} '
                      'no benefit amount yet. The Treasurer sets them in '
                      'More > Welfare > Benefit amounts.',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
      const SizedBox(height: 8),
      if (cases.isEmpty)
        const Text(
          'No welfare cases yet. Cases are prepared and approved in '
          'More > Welfare; they then appear here.',
        ),
      for (final x in cases) _welfareCard(x),
    ];
  }

  Widget _welfareCard(Map<String, dynamic> x) {
    final status = '${x['status']}';
    final closed = status == 'paid' || status == 'rejected';
    final steps = (x['steps'] as num?)?.toInt() ?? 0;
    final done = (x['steps_done'] as num?)?.toInt() ?? 0;
    final amount = (x['amount'] as num?)?.toInt();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${x['member_name'] ?? 'Member'}'
                    '${x['member_no'] == null ? '' : ' · ${x['member_no']}'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                Pill(
                  switch (status) {
                    'approved' => 'Approved',
                    'paid' => 'Paid',
                    'rejected' => 'Rejected',
                    _ => 'Pending',
                  },
                  color: status == 'pending'
                      ? Theme.of(context).colorScheme.error
                      : closed
                      ? Colors.grey.shade600
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                '${x['case_no'] ?? 'Case'}',
                if (x['type'] != null) '${x['type']}',
                if (amount != null) formatMoney(amount),
              ].join(' · '),
            ),
            if (x['beneficiary'] != null) Text('For ${x['beneficiary']}'),
            if (x['by'] != null || x['decided_by'] != null) ...[
              const SizedBox(height: 4),
              Text(
                [
                  if (x['by'] != null) 'Prepared by ${x['by']}',
                  if (x['decided_by'] != null)
                    '${status == 'rejected' ? 'Rejected' : 'Approved'} by '
                        '${x['decided_by']}',
                ].join(' · '),
                style: TextStyle(fontSize: 12, color: Tones.of(context).muted),
              ),
            ],
            if (steps > 0) ...[
              const SizedBox(height: 10),
              Text('Case steps: $done of $steps done'),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: done / steps,
                  minHeight: 8,
                ),
              ),
            ] else if (!closed && _lead)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: OutlinedButton.icon(
                  onPressed: () => _run(
                    () => _api.addWelfareSteps(_c, x['id'] as String),
                    'Case steps added to Tasks.',
                  ),
                  icon: const Icon(Icons.checklist_rounded),
                  label: const Text('Add the case steps'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- Organizing Committee: events ----------

  List<Widget> _eventsSection() {
    final events = _items('events');
    return [
      const SectionTitle('Events'),
      if (events.isEmpty)
        const Text(
          'No events yet. Add them in More > Events and meetings; they then '
          'appear here, and the Organizer can add the planning steps.',
        ),
      for (final e in events) _eventCard(e),
    ];
  }

  Widget _eventCard(Map<String, dynamic> e) {
    final planned = e['status'] == 'planned';
    final steps = (e['steps'] as num?)?.toInt() ?? 0;
    final done = (e['steps_done'] as num?)?.toInt() ?? 0;
    final present = (e['present'] as num?)?.toInt() ?? 0;
    final on = DateTime.tryParse('${e['starts_on']}');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${e['name']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                Pill(switch (e['status']) {
                  'held' => 'Held',
                  'cancelled' => 'Cancelled',
                  _ => 'Planned',
                }, color: planned ? null : Colors.grey.shade600),
              ],
            ),
            Text(
              [
                if (on != null) formatDateTime(on),
                if (e['venue'] != null) '${e['venue']}',
              ].join(' · '),
            ),
            if (!planned || present > 0) Text('$present attended'),
            if (steps > 0) ...[
              const SizedBox(height: 10),
              Text('Planning: $done of $steps steps done'),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: done / steps,
                  minHeight: 8,
                ),
              ),
            ] else if (planned && _lead)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: OutlinedButton.icon(
                  onPressed: () => _run(
                    () => _api.addEventSteps(_c, e['id'] as String),
                    'Planning steps added to Tasks.',
                  ),
                  icon: const Icon(Icons.checklist_rounded),
                  label: const Text('Add the planning steps'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- Disciplinary Committee: the case book ----------

  List<Map<String, dynamic>> _cases() {
    final c = _home?['cases'];
    if (c is! Map) return const [];
    return [
      for (final x in (c['recent'] as List?) ?? const [])
        Map<String, dynamic>.from(x as Map),
    ];
  }

  List<Widget> _casesSection() {
    final c = Map<String, dynamic>.from(_home!['cases'] as Map);
    final cases = _cases();
    return [
      SectionTitle(
        'Cases',
        trailing: TextButton(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    DisciplineScreen(access: ChatAccess(_api.token)),
              ),
            );
            _load();
          },
          child: const Text('Open the case book'),
        ),
      ),
      Row(
        children: [
          Expanded(
            child: MetricTile(
              label: 'Open complaints',
              value: '${c['open'] ?? 0}',
              icon: Icons.report_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MetricTile(
              label: 'Warnings sent',
              value: '${c['warnings'] ?? 0}',
              icon: Icons.gavel_rounded,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (cases.isEmpty)
        const Text(
          'No complaints yet. Zone Mayors and Zone Secretaries send them from '
          "a member's page; they arrive here.",
        ),
      for (final x in cases) _caseCard(x),
    ];
  }

  Widget _caseCard(Map<String, dynamic> x) {
    final complaint = x['kind'] == 'complaint';
    final open = x['status'] == 'open';
    final steps = (x['steps'] as num?)?.toInt() ?? 0;
    final done = (x['steps_done'] as num?)?.toInt() ?? 0;
    final at = DateTime.tryParse('${x['at']}');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${x['member_name'] ?? 'Member'}'
                    '${x['member_no'] == null ? '' : ' · ${x['member_no']}'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                Pill(
                  !complaint
                      ? 'Warning'
                      : open
                      ? 'Open'
                      : 'Closed',
                  color: complaint && open
                      ? Theme.of(context).colorScheme.error
                      : Colors.grey.shade600,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${x['details']}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              [
                complaint ? 'From ${x['by']}' : 'Sent by ${x['by']}',
                if (at != null) formatDate(at),
              ].join(' · '),
              style: TextStyle(fontSize: 12, color: Tones.of(context).muted),
            ),
            if (complaint && steps > 0) ...[
              const SizedBox(height: 10),
              Text('Hearing steps: $done of $steps done'),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: done / steps,
                  minHeight: 8,
                ),
              ),
            ] else if (complaint && open && _lead)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: OutlinedButton.icon(
                  onPressed: () => _run(
                    () => _api.addCaseSteps(_c, x['id'] as String),
                    'Hearing steps added to Tasks.',
                  ),
                  icon: const Icon(Icons.checklist_rounded),
                  label: const Text('Add the hearing steps'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _rollSection(Map<String, dynamic> roll) {
    final active = (roll['active'] as num?)?.toInt() ?? 0;
    final ready = (roll['ready'] as num?)?.toInt() ?? 0;
    final zones = [
      for (final z in (roll['zones'] as List?) ?? const [])
        Map<String, dynamic>.from(z as Map),
    ];
    return [
      const SectionTitle('Voter roll'),
      Row(
        children: [
          Expanded(
            child: MetricTile(
              label: 'Active members (voters)',
              value: '$active',
              icon: Icons.groups_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MetricTile(
              label: 'Can sign in to vote',
              value: '$ready',
              icon: Icons.verified_user_outlined,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Members vote with their member ID. ${active - ready} active '
          '${active - ready == 1 ? 'member has' : 'members have'} not '
          'activated their sign-in yet; remind them before voting opens. '
          'The voters list is fixed when voting opens.',
        ),
      ),
      GroupCard(
        children: [
          for (final z in zones)
            ListTile(
              dense: true,
              title: Text('${z['zone']}'),
              trailing: Text('${z['ready']} of ${z['active']} ready'),
            ),
        ],
      ),
    ];
  }

  Widget _refreshable(List<Widget> children) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: children,
    ),
  );

  Widget? _fab() {
    if (_home == null) return null;
    return switch (_tabs.index) {
      1 => FloatingActionButton.extended(
        onPressed: _editTask,
        icon: const Icon(Icons.add_task),
        label: const Text('New task'),
      ),
      2 => FloatingActionButton.extended(
        onPressed: _editNote,
        icon: const Icon(Icons.edit_note),
        label: const Text('Write'),
      ),
      3 when _lead => FloatingActionButton.extended(
        onPressed: _postNotice,
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('Post notice'),
      ),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final h = _home;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (h != null)
            IconButton(
              tooltip: 'Office chat',
              icon: const Icon(Icons.forum_outlined),
              onPressed: _openChat,
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Tasks'),
            Tab(text: 'Minutes'),
            Tab(text: 'Notices'),
          ],
        ),
      ),
      floatingActionButton: _fab(),
      body: h == null
          ? _refreshable([
              if (_error != null)
                Text(_error!)
              else
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ])
          : TabBarView(
              controller: _tabs,
              children: [
                _overviewTab(),
                _tasksTab(),
                _notesTab(),
                _noticesTab(),
              ],
            ),
    );
  }
}

typedef _TaskInput = ({
  String title,
  String? details,
  String? assignee,
  DateTime? dueOn,
  String? electionId,
});

class _TaskSheet extends StatefulWidget {
  const _TaskSheet({
    required this.task,
    required this.members,
    required this.elections,
    required this.canRemove,
    required this.onSave,
    required this.onRemove,
  });

  final Map<String, dynamic>? task;
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> elections;
  final bool canRemove;
  final Future<bool> Function(_TaskInput) onSave;
  final Future<bool> Function() onRemove;

  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
  late final _title = TextEditingController(
    text: widget.task?['title'] as String?,
  );
  late final _details = TextEditingController(
    text: widget.task?['details'] as String?,
  );
  late String? _assignee = widget.task?['assignee'] as String?;
  late String? _election = widget.task?['election_id'] as String?;
  late DateTime? _due = DateTime.tryParse('${widget.task?['due_on']}');
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _go(Future<bool> Function() action) async {
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    final ok = await action();
    if (!mounted) return;
    if (ok) {
      nav.pop(true);
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberKeys = {for (final m in widget.members) m['key']};
    final electionIds = {for (final e in widget.elections) e['id']};
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.task == null ? 'New task' : 'Task',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              autofocus: widget.task == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'What needs doing'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _details,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Details (optional)',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: memberKeys.contains(_assignee) ? _assignee : null,
              decoration: const InputDecoration(labelText: 'Who does it'),
              items: [
                const DropdownMenuItem(value: null, child: Text('No one yet')),
                for (final m in widget.members)
                  DropdownMenuItem(
                    value: m['key'] as String,
                    child: Text('${m['name']}'),
                  ),
              ],
              onChanged: (v) => setState(() => _assignee = v),
            ),
            if (widget.elections.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: electionIds.contains(_election)
                    ? _election
                    : null,
                decoration: const InputDecoration(labelText: 'For election'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  for (final e in widget.elections)
                    DropdownMenuItem(
                      value: e['id'] as String,
                      child: Text('${e['title']}'),
                    ),
                ],
                onChanged: (v) => setState(() => _election = v),
              ),
            ],
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(
                _due == null ? 'No due date' : 'Due ${formatDate(_due)}',
              ),
              trailing: _due == null
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _due = null),
                    ),
              onTap: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  initialDate: _due ?? now,
                  firstDate: DateTime(now.year - 1),
                  lastDate: DateTime(now.year + 3),
                );
                if (d != null) setState(() => _due = d);
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (widget.canRemove)
                  TextButton(
                    onPressed: _busy ? null : () => _go(widget.onRemove),
                    child: const Text('Remove'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () {
                          if (_title.text.trim().length < 2) return;
                          _go(
                            () => widget.onSave((
                              title: _title.text.trim(),
                              details: _details.text.trim(),
                              assignee: _assignee,
                              dueOn: _due,
                              electionId: _election,
                            )),
                          );
                        },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

typedef _NoteInput = ({
  String kind,
  String title,
  String body,
  DateTime? metOn,
});

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({required this.note, required this.onSave});

  final Map<String, dynamic>? note;
  final Future<bool> Function(_NoteInput) onSave;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late String _kind = widget.note?['kind'] as String? ?? 'meeting';
  late final _title = TextEditingController(
    text: widget.note?['title'] as String?,
  );
  late final _body = TextEditingController(
    text: widget.note?['body'] as String?,
  );
  late DateTime? _metOn = widget.note == null
      ? DateTime.now()
      : DateTime.tryParse('${widget.note?['met_on']}');
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().length < 2 || _body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give it a title and write something.')),
      );
      return;
    }
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    final ok = await widget.onSave((
      kind: _kind,
      title: _title.text.trim(),
      body: _body.text.trim(),
      metOn: _kind == 'meeting' ? _metOn : null,
    ));
    if (!mounted) return;
    if (ok) {
      nav.pop();
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'Write' : 'Edit'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'meeting', label: Text('Minutes')),
              ButtonSegment(value: 'decision', label: Text('Decision')),
              ButtonSegment(value: 'note', label: Text('Note')),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: switch (_kind) {
                'meeting' => 'Meeting (for example: Planning meeting)',
                'decision' => 'Decision in a few words',
                _ => 'Title',
              },
            ),
          ),
          if (_kind == 'meeting')
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(
                _metOn == null ? 'Date of meeting' : formatDate(_metOn),
              ),
              onTap: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  initialDate: _metOn ?? now,
                  firstDate: DateTime(now.year - 2),
                  lastDate: DateTime(now.year + 1),
                );
                if (d != null) setState(() => _metOn = d);
              },
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            minLines: 10,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              alignLabelWithHint: true,
              labelText: switch (_kind) {
                'meeting' => 'Who attended, what was discussed and agreed',
                'decision' => 'What was decided, and why',
                _ => 'Note',
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeDialog extends StatefulWidget {
  const _NoticeDialog();

  @override
  State<_NoticeDialog> createState() => _NoticeDialogState();
}

class _NoticeDialogState extends State<_NoticeDialog> {
  final _title = TextEditingController();
  final _body = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Notice to all members'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'For example: Nominations are open',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              minLines: 4,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Notice'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_title.text.trim().length < 2 || _body.text.trim().isEmpty) {
              return;
            }
            Navigator.of(context).pop((_title.text.trim(), _body.text.trim()));
          },
          child: const Text('Post'),
        ),
      ],
    );
  }
}
