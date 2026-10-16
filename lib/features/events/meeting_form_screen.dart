import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../data/database.dart';
import '../../data/repositories/events_repository.dart';
import '../../data/repositories/member_repository.dart';
import '../auth/auth_cubit.dart';
import 'events_common.dart';

class MeetingFormScreen extends StatefulWidget {
  const MeetingFormScreen({super.key, this.meeting});

  /// Null to schedule a new meeting.
  final Meeting? meeting;

  @override
  State<MeetingFormScreen> createState() => _MeetingFormScreenState();
}

class _MeetingFormScreenState extends State<MeetingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.meeting?.title);
  late final _venue = TextEditingController(text: widget.meeting?.venue);
  late final _agenda = TextEditingController(text: widget.meeting?.agenda);
  late MeetingKind _kind = widget.meeting?.kind ?? MeetingKind.general;
  late String? _zoneId = widget.meeting?.zoneId;
  late DateTime _heldOn =
      widget.meeting?.heldOn ??
      DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day + 1,
        16,
      );
  List<Zone> _zones = const [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    context.read<AppServices>().members.zones().then((z) {
      if (mounted) setState(() => _zones = z.where((x) => x.isActive).toList());
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _venue.dispose();
    _agenda.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final services = context.read<AppServices>();
    final user = context.read<AuthCubit>().user!;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final m = await services.events.saveMeeting(
        MeetingDraft(
          title: _title.text,
          kind: _kind,
          heldOn: _heldOn,
          zoneId: _zoneId,
          venue: _venue.text,
          agenda: _agenda.text,
        ),
        user.actor(services.deviceId),
        id: widget.meeting?.id,
      );
      await scheduleOccasionReminder(
        services.reminders,
        m.id,
        m.title,
        m.heldOn,
        m.venue,
      );
      if (mounted) Navigator.of(context).pop(m);
    } on EventsException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.meeting == null ? 'New meeting' : 'Edit meeting'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<MeetingKind>(
              initialValue: _kind,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Type of meeting'),
              items: [
                for (final k in MeetingKind.values)
                  DropdownMenuItem(value: k, child: Text(k.label)),
              ],
              onChanged: (k) => setState(() => _kind = k!),
            ),
            if (_kind == MeetingKind.zonal) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _zoneId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Zone'),
                items: [
                  for (final z in _zones)
                    DropdownMenuItem(
                      value: z.id,
                      child: Text(zoneDisplayName(z)),
                    ),
                ],
                validator: (v) => v == null ? 'Choose the zone' : null,
                onChanged: (z) => setState(() => _zoneId = z),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. October monthly meeting',
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter a title' : null,
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Date and time'),
                subtitle: Text(formatDateTime(_heldOn)),
                onTap: () async {
                  final d = await pickDateTime(context, _heldOn);
                  if (d != null) setState(() => _heldOn = d);
                },
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _venue,
              decoration: const InputDecoration(labelText: 'Venue'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _agenda,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(labelText: 'Agenda'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Save meeting'),
            ),
          ],
        ),
      ),
    );
  }
}
