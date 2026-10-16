import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ui.dart';
import 'candidate_photo.dart';
import 'election_api.dart';

/// Who is on the Electoral Commission. The Founder and General Secretary
/// appoint the Chairperson (and anyone else); the Chairperson appoints the
/// Secretary and members. The cloud checks every change.
class CommissionScreen extends StatefulWidget {
  const CommissionScreen({super.key, required this.api});

  final ElectionApi api;

  @override
  State<CommissionScreen> createState() => _CommissionScreenState();
}

class _CommissionScreenState extends State<CommissionScreen> {
  Map<String, dynamic>? _c;
  String? _error;

  static const _roleNames = {
    'chair': 'Chairperson',
    'secretary': 'Secretary',
    'member': 'Member',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await widget.api.commission();
      if (mounted) {
        setState(() {
          _c = c;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = electionError(e));
    }
  }

  Future<void> _add() async {
    final c = _c!;
    final picked = await showModalBottomSheet<(Map<String, dynamic>, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddOfficer(
        api: widget.api,
        canAppointChair: c['can_appoint_chair'] == true,
      ),
    );
    if (picked == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.api.appoint(picked.$1['key'] as String, picked.$2);
      messenger.showSnackBar(
        SnackBar(content: Text('${picked.$1['name']} joined the Commission.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(electionError(e))));
    }
    _load();
  }

  Future<void> _remove(Map officer) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text('Remove ${officer['name']} from the Commission?'),
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
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.api.removeOfficer(officer['key'] as String);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(electionError(e))));
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final canAppoint = c?['can_appoint'] == true;
    final officers = ((c?['officers'] as List?) ?? const []).cast<Map>();
    final mine = c?['mine'];
    return Scaffold(
      appBar: AppBar(title: const Text('Electoral Commission')),
      floatingActionButton: canAppoint
          ? FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Add member'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            const Text(
              'The Commission prepares and runs elections. The Founder and '
              'General Secretary appoint the Chairperson; the Chairperson '
              'appoints the Secretary and members. It cannot change while '
              'voting is open, and Commission members cannot be candidates.',
            ),
            const SizedBox(height: 12),
            if (_error != null) Text(_error!),
            if (c == null && _error == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (c != null && officers.isEmpty)
              const Text('No one has been appointed yet.'),
            for (final o in officers)
              Card(
                child: ListTile(
                  leading: CandidatePhoto(
                    name: '${o['name'] ?? '?'}',
                    size: 44,
                  ),
                  title: Text(
                    '${o['name'] ?? 'Member'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('${o['member_no'] ?? ''}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Pill(_roleNames['${o['role']}'] ?? '${o['role']}'),
                      if (canAppoint &&
                          (o['role'] != 'chair' ||
                              c?['can_appoint_chair'] == true))
                        IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.close),
                          onPressed: () => _remove(o),
                        ),
                    ],
                  ),
                ),
              ),
            if (mine != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'You are on the Commission as ${_roleNames[mine]}.',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddOfficer extends StatefulWidget {
  const _AddOfficer({required this.api, required this.canAppointChair});

  final ElectionApi api;
  final bool canAppointChair;

  @override
  State<_AddOfficer> createState() => _AddOfficerState();
}

class _AddOfficerState extends State<_AddOfficer> {
  Timer? _debounce;
  List<Map<String, dynamic>> _found = [];
  String _role = 'member';
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String q) {
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add to the Commission',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              if (widget.canAppointChair)
                const ButtonSegment(value: 'chair', label: Text('Chair')),
              const ButtonSegment(value: 'secretary', label: Text('Secretary')),
              const ButtonSegment(value: 'member', label: Text('Member')),
            ],
            selected: {_role},
            onSelectionChanged: (s) => setState(() => _role = s.first),
          ),
          const SizedBox(height: 8),
          TextField(
            autofocus: true,
            onChanged: _search,
            decoration: const InputDecoration(
              labelText: 'Find an active member',
              hintText: 'Name or member ID',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          if (_error != null) Text(_error!),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final f in _found)
                  ListTile(
                    title: Text(f['name'] as String),
                    subtitle: Text('${f['member_no']}'),
                    onTap: () => Navigator.of(context).pop((f, _role)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
