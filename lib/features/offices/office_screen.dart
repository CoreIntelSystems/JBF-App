import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/sync/sync_api.dart' show ChatChannel;
import '../chats/chats_screen.dart';
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
          id: 'office:$_c',
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
        'Notices appear for every member on the Elections page, in the app '
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
