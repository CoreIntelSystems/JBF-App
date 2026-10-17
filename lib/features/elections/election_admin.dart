import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/format.dart';
import 'candidate_photo.dart';
import 'election_api.dart';

/// Electoral Commission: set up a new election (posts and closing time),
/// or change one still being prepared when [existing] is given.
class CreateElectionScreen extends StatefulWidget {
  const CreateElectionScreen({super.key, required this.api, this.existing});

  final ElectionApi api;

  /// A draft election as election_get returns it.
  final Map<String, dynamic>? existing;

  @override
  State<CreateElectionScreen> createState() => _CreateElectionScreenState();
}

class _CreateElectionScreenState extends State<CreateElectionScreen> {
  late final Map<String, dynamic>? _e = widget.existing;
  late final _title = TextEditingController(text: _e?['title'] as String?);
  late final _notes = TextEditingController(text: _e?['notes'] as String?);
  late final _posts = <({String? id, TextEditingController title, int seats})>[
    if (_e == null)
      (id: null, title: TextEditingController(), seats: 1)
    else
      for (final p in (_e['posts'] as List).cast<Map>())
        (
          id: p['id'] as String,
          title: TextEditingController(text: p['title'] as String),
          seats: p['seats'] as int,
        ),
  ];
  late DateTime _closes =
      DateTime.tryParse('${_e?['closes_at']}')?.toLocal() ??
      DateTime.now().add(const Duration(days: 3));
  bool _saving = false;
  String? _error;

  /// Posts already in the draft that have candidates.
  bool _hasCandidates(String? postId) =>
      postId != null &&
      (_e!['posts'] as List).cast<Map>().any(
        (p) => p['id'] == postId && (p['candidates'] as List).isNotEmpty,
      );

  Future<void> _removePost(int i) async {
    final p = _posts[i];
    if (_hasCandidates(p.id)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(
            'Take "${p.title.text}" out of this election? Its candidates '
            'are taken off too.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep it'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Take it out'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _posts.removeAt(i));
  }

  Future<void> _pickTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _closes,
      firstDate: DateTime.now().isAfter(_closes) ? _closes : DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 120)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_closes),
    );
    if (time == null) return;
    setState(
      () => _closes = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _save() async {
    final posts = [
      for (final p in _posts)
        if (p.title.text.trim().isNotEmpty)
          (id: p.id, title: p.title.text.trim(), seats: p.seats),
    ];
    if (_title.text.trim().length < 3 || posts.isEmpty) {
      setState(
        () => _error = 'Give the election a name and at least one post.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final String id;
      if (_e == null) {
        id = await widget.api.create(
          title: _title.text.trim(),
          notes: _notes.text.trim(),
          closesAt: _closes,
          posts: [for (final p in posts) (title: p.title, seats: p.seats)],
        );
      } else {
        id = _e['id'] as String;
        await widget.api.update(
          id,
          title: _title.text.trim(),
          notes: _notes.text.trim(),
          closesAt: _closes,
          posts: posts,
        );
      }
      if (mounted) Navigator.of(context).pop(id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = electionError(e);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_e == null ? 'New election' : 'Change election'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Name of the election',
              hintText: 'e.g. 2027 Executive Elections',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes for voters (optional)',
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: const Text('Voting closes'),
            subtitle: Text(formatDateTime(_closes)),
            trailing: TextButton(
              onPressed: _pickTime,
              child: const Text('Change'),
            ),
          ),
          const Divider(),
          const Text(
            'Posts to vote for',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          for (var i = 0; i < _posts.length; i++)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _posts[i].title,
                    decoration: InputDecoration(labelText: 'Post ${i + 1}'),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _posts[i].seats,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (var n = 1; n <= 5; n++)
                      DropdownMenuItem(
                        value: n,
                        child: Text(n == 1 ? '1 seat' : '$n seats'),
                      ),
                  ],
                  onChanged: (n) => setState(
                    () => _posts[i] = (
                      id: _posts[i].id,
                      title: _posts[i].title,
                      seats: n ?? 1,
                    ),
                  ),
                ),
                if (_posts.length > 1)
                  IconButton(
                    tooltip: 'Take this post out',
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => _removePost(i),
                  ),
              ],
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(
                () => _posts.add((
                  id: null,
                  title: TextEditingController(),
                  seats: 1,
                )),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add another post'),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving
                  ? 'Saving...'
                  : _e == null
                  ? 'Create election'
                  : 'Save changes',
            ),
          ),
          const SizedBox(height: 8),
          if (_e == null)
            const Text(
              'Next you add the candidates. A different Commission officer '
              'then opens the voting.',
            ),
        ],
      ),
    );
  }
}

/// Electoral Commission: add a candidate to a post, with a picture and a
/// short message to voters, or change or take off [existing] one.
class CandidateEditor extends StatefulWidget {
  const CandidateEditor({
    super.key,
    required this.api,
    required this.postId,
    required this.postTitle,
    this.existing,
  });

  final ElectionApi api;
  final String postId;
  final String postTitle;

  /// A candidate as election_get returns it.
  final Map<String, dynamic>? existing;

  @override
  State<CandidateEditor> createState() => _CandidateEditorState();
}

class _CandidateEditorState extends State<CandidateEditor> {
  final _search = TextEditingController();
  final _manifesto = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _found = [];
  late final Map<String, dynamic>? _was = widget.existing;
  late Map<String, dynamic>? _member = _was == null
      ? null
      : {
          'key': _was['member_key'],
          'name': _was['name'],
          'member_no': _was['member_no'],
        };
  late String? _photo = _was?['photo'] as String?;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _manifesto.text = (_was?['manifesto'] as String?) ?? '';
  }

  Future<void> _remove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(
          'Take ${_was!['name']} off the ballot for ${widget.postTitle}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Take off'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.removeCandidate(_was!['id'] as String);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = electionError(e);
          _saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final r = await widget.api.findMember(q);
        if (mounted) setState(() => _found = r);
      } catch (e) {
        if (mounted) setState(() => _error = electionError(e));
      }
    });
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 480,
      maxHeight: 480,
      imageQuality: 70,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final type = picked.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
    final url = 'data:image/$type;base64,${base64Encode(bytes)}';
    if (url.length > 280000) {
      setState(() => _error = 'That picture is too big. Choose a smaller one.');
      return;
    }
    setState(() {
      _photo = url;
      _error = null;
    });
  }

  Future<void> _save() async {
    final m = _member;
    if (m == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.setCandidate(
        postId: widget.postId,
        memberKey: m['key'] as String,
        manifesto: _manifesto.text,
        photo: _photo,
      );
      // Someone else now stands in place of the candidate being changed.
      final was = _was;
      if (was != null && was['member_key'] != m['key']) {
        await widget.api.removeCandidate(was['id'] as String);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = electionError(e);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _member;
    return Scaffold(
      appBar: AppBar(title: Text('Candidate for ${widget.postTitle}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (m == null) ...[
            TextField(
              controller: _search,
              onChanged: _onSearch,
              decoration: const InputDecoration(
                labelText: 'Find an active member',
                hintText: 'Name or member ID',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            for (final f in _found)
              ListTile(
                leading: CandidatePhoto(name: f['name'] as String, size: 40),
                title: Text(f['name'] as String),
                subtitle: Text('${f['member_no']}'),
                onTap: () => setState(() => _member = f),
              ),
          ] else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CandidatePhoto(
                name: m['name'] as String,
                photo: _photo,
                size: 72,
              ),
              title: Text(
                m['name'] as String,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${m['member_no']}'),
              trailing: TextButton(
                onPressed: () => setState(() => _member = null),
                child: const Text('Change'),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(_photo == null ? 'Add picture' : 'Change picture'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _manifesto,
              maxLines: 4,
              maxLength: 1500,
              decoration: const InputDecoration(
                labelText: 'Message to voters (optional)',
              ),
            ),
          ],
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: m == null || _saving ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Save candidate'),
          ),
          if (_was != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving ? null : _remove,
              icon: const Icon(Icons.person_remove_outlined),
              label: const Text('Take off the ballot'),
            ),
          ],
        ],
      ),
    );
  }
}
