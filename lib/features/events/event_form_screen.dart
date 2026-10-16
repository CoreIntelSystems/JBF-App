import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/repositories/events_repository.dart';
import '../auth/auth_cubit.dart';
import 'events_common.dart';

class EventFormScreen extends StatefulWidget {
  const EventFormScreen({super.key, this.event});

  /// Null to create a new event.
  final Event? event;

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.event?.name);
  late final _venue = TextEditingController(text: widget.event?.venue);
  late final _description = TextEditingController(
    text: widget.event?.description,
  );
  late final _budget = TextEditingController(
    text: widget.event?.budget == null ? '' : moneyInput(widget.event!.budget!),
  );
  late final _transport = TextEditingController(
    text: widget.event?.transportNotes,
  );
  late final _accommodation = TextEditingController(
    text: widget.event?.accommodationNotes,
  );
  late EventKind _kind = widget.event?.kind ?? EventKind.general;
  late DateTime _startsOn =
      widget.event?.startsOn ??
      DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day + 7,
        14,
      );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _name,
      _venue,
      _description,
      _budget,
      _transport,
      _accommodation,
    ]) {
      c.dispose();
    }
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
      final e = await services.events.saveEvent(
        EventDraft(
          name: _name.text,
          kind: _kind,
          startsOn: _startsOn,
          venue: _venue.text,
          description: _description.text,
          budget: _budget.text.trim().isEmpty ? null : parseMoney(_budget.text),
          transportNotes: _transport.text,
          accommodationNotes: _accommodation.text,
        ),
        user.actor(services.deviceId),
        id: widget.event?.id,
      );
      await scheduleOccasionReminder(
        services.reminders,
        e.id,
        e.name,
        e.startsOn,
        e.venue,
      );
      if (mounted) Navigator.of(context).pop(e);
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
        title: Text(widget.event == null ? 'New event' : 'Edit event'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Event name'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter the event name' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EventKind>(
              initialValue: _kind,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [
                for (final k in EventKind.values)
                  DropdownMenuItem(value: k, child: Text(k.label)),
              ],
              onChanged: (k) => setState(() => _kind = k!),
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.event),
                title: const Text('Date and time'),
                subtitle: Text(formatDateTime(_startsOn)),
                onTap: () async {
                  final d = await pickDateTime(context, _startsOn);
                  if (d != null) setState(() => _startsOn = d);
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
              controller: _budget,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Budget (optional)',
                prefixText: 'GHS ',
              ),
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return null;
                final a = parseMoney(v!);
                return a == null || a < 0 ? 'Enter a valid amount' : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Programme / notes'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _transport,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Transport plan',
                hintText: 'Bus hire, pick-up points, times',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _accommodation,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Accommodation plan',
                hintText: 'Hotel, rooms, who shares',
              ),
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
              child: const Text('Save event'),
            ),
          ],
        ),
      ),
    );
  }
}
