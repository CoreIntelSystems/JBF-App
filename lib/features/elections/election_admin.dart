import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/format.dart';
import 'candidate_photo.dart';
import 'election_api.dart';

/// Electoral Commission: set up a new election (posts and closing time).
class CreateElectionScreen extends StatefulWidget {
  const CreateElectionScreen({super.key, required this.api});

  final ElectionApi api;

  @override
  State<CreateElectionScreen> createState() => _CreateElectionScreenState();
}

class _CreateElectionScreenState extends State<CreateElectionScreen> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  final _posts = <({TextEditingController title, int seats})>[
    (title: TextEditingController(), seats: 1),
  ];
  DateTime _closes = DateTime.now().add(const Duration(days: 3));
  bool _saving = false;
  String? _error;

  Future<void> _pickTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _closes,
      firstDate: DateTime.now(),
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
          (title: p.title.text.trim(), seats: p.seats),
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
      final id = await widget.api.create(
        title: _title.text.trim(),
        notes: _notes.text.trim(),
        closesAt: _closes,
        posts: posts,
      );
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
      appBar: AppBar(title: const Text('New election')),
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
                    () => _posts[i] = (title: _posts[i].title, seats: n ?? 1),
                  ),
                ),
              ],
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(
                () => _posts.add((title: TextEditingController(), seats: 1)),
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
            child: Text(_saving ? 'Saving...' : 'Create election'),
          ),
          const SizedBox(height: 8),
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
/// short message to voters.
class CandidateEditor extends StatefulWidget {
  const CandidateEditor({
    super.key,
    required this.api,
    required this.postId,
    required this.postTitle,
  });

  final ElectionApi api;
  final String postId;
  final String postTitle;

  @override
  State<CandidateEditor> createState() => _CandidateEditorState();
}

class _CandidateEditorState extends State<CandidateEditor> {
  final _search = TextEditingController();
  final _manifesto = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _found = [];
  Map<String, dynamic>? _member;
  String? _photo;
  bool _saving = false;
  String? _error;

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
        ],
      ),
    );
  }
}
