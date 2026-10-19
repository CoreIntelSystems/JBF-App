import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../data/sync/sync_api.dart';
import '../../domain/zone_rules.dart';

/// A member from the founding list checks and corrects their own name,
/// contact details and zones. Saved online; pops true when it saved.
class MemberProfileScreen extends StatefulWidget {
  const MemberProfileScreen({
    super.key,
    required this.home,
    required this.session,
  });

  final MemberHome home;
  final MemberSession session;

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  static const _fields = <(String, String, TextInputType)>[
    ('full_name', 'Full name', TextInputType.name),
    ('whatsapp_name', 'WhatsApp name', TextInputType.text),
    ('phone', 'Phone number', TextInputType.phone),
    ('whatsapp', 'Second or WhatsApp number', TextInputType.phone),
    ('email', 'Email', TextInputType.emailAddress),
    ('occupation', 'Occupation', TextInputType.text),
    ('location', 'Town or area', TextInputType.text),
    ('address', 'Address', TextInputType.streetAddress),
    ('emergency_name', 'Emergency contact name', TextInputType.name),
    ('emergency_phone', 'Emergency contact phone', TextInputType.phone),
  ];

  late final _controllers = {
    for (final (key, _, _) in _fields)
      key: TextEditingController(text: widget.home.profile[key] ?? ''),
  };
  late String? _gender = widget.home.profile['gender'];
  late final Set<String> _zones = {
    for (final z in widget.home.zoneIds)
      if (widget.home.zoneOptions.any((o) => o.$1 == z)) z,
  };
  bool get _locked => widget.home.zonesLocked;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_locked && _zones.isEmpty) {
      setState(() => _error = ZoneRules.tooFewMessage);
      return;
    }
    if (_controllers['full_name']!.text.trim().isEmpty) {
      setState(() => _error = 'Enter your full name.');
      return;
    }
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final api = context.read<AppServices>().sync.api;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Keep the main zone first.
      final ordered = [
        ...widget.home.zoneIds.where(_zones.contains),
        ..._zones.where((z) => !widget.home.zoneIds.contains(z)),
      ];
      await api.memberUpdateProfile(widget.session.token, {
        for (final e in _controllers.entries) e.key: e.value.text,
        'gender': _gender,
      }, zoneIds: _locked ? null : ordered);
      messenger.showSnackBar(const SnackBar(content: Text('Details saved.')));
      nav.pop(true);
    } on SyncException catch (e) {
      setState(
        () => _error = e.offline
            ? 'Connect to the internet to save your details.'
            : e.message,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My details'),
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
          const Text('Check your details and correct anything that is wrong.'),
          const SizedBox(height: 12),
          for (final (key, label, type) in _fields) ...[
            TextField(
              key: Key('profile_$key'),
              controller: _controllers[key],
              keyboardType: type,
              decoration: InputDecoration(labelText: label),
            ),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<String?>(
            initialValue: _gender,
            decoration: const InputDecoration(labelText: 'Gender'),
            items: const [
              DropdownMenuItem(value: null, child: Text('Not said')),
              DropdownMenuItem(value: 'Male', child: Text('Male')),
              DropdownMenuItem(value: 'Female', child: Text('Female')),
            ],
            onChanged: (v) => setState(() => _gender = v),
          ),
          const SizedBox(height: 16),
          Text('My zone', style: theme.textTheme.titleSmall),
          if (_locked) ...[
            Text(
              widget.home.zoneOptions
                  .where((o) => widget.home.zoneIds.contains(o.$1))
                  .map((o) => o.$2)
                  .join(', '),
              style: theme.textTheme.bodyLarge,
            ),
            const Text(
              'Zone chosen. To change it, contact your Zone Secretary.',
            ),
          ] else ...[
            const Text(
              'Choose one zone, or two at most. This cannot be changed later.',
            ),
            for (final (id, name) in widget.home.zoneOptions)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(name),
                value: _zones.contains(id),
                onChanged: (on) => setState(() {
                  _error = null;
                  if (on == true) {
                    if (_zones.length >= ZoneRules.maxZones) {
                      _error = ZoneRules.tooManyMessage;
                    } else {
                      _zones.add(id);
                    }
                  } else {
                    _zones.remove(id);
                  }
                }),
              ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('Save my details'),
          ),
        ],
      ),
    );
  }
}
