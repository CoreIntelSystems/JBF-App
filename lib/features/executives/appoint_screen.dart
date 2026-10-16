import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../data/database.dart';
import '../../data/repositories/events_repository.dart';
import '../../data/repositories/member_repository.dart';
import '../auth/auth_cubit.dart';
import '../members/member_picker.dart';

/// Records a member taking up a position.
class AppointScreen extends StatefulWidget {
  const AppointScreen({super.key});

  @override
  State<AppointScreen> createState() => _AppointScreenState();
}

class _AppointScreenState extends State<AppointScreen> {
  final _responsibilities = TextEditingController();
  Member? _member;
  ExecutivePosition? _position;
  String? _zoneId;
  DateTime _start = DateTime.now();
  DateTime? _end;
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
    _responsibilities.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(DateTime.now().year + 10),
  );

  Future<void> _save() async {
    final member = _member;
    final position = _position;
    if (member == null || position == null) {
      setState(() => _error = 'Choose the member and the position.');
      return;
    }
    final services = context.read<AppServices>();
    final user = context.read<AuthCubit>().user!;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await services.events.appoint(
        memberId: member.id,
        position: position,
        zoneId: _zoneId,
        termStart: _start,
        termEnd: _end,
        responsibilities: _responsibilities.text,
        actor: user.actor(services.deviceId),
      );
      if (mounted) Navigator.of(context).pop();
    } on EventsException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    return Scaffold(
      appBar: AppBar(title: const Text('Appoint executive')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.person_search),
              title: Text(_member?.fullName ?? 'Choose member'),
              subtitle: _member == null ? null : Text(_member!.memberNo),
              onTap: () async {
                final m = await Navigator.of(context).push<Member>(
                  MaterialPageRoute(builder: (_) => const MemberPicker()),
                );
                if (m != null) setState(() => _member = m);
              },
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<ExecutivePosition>>(
            stream: services.events.watchPositions(),
            builder: (context, snap) {
              final positions = (snap.data ?? const <ExecutivePosition>[])
                  .where((p) => p.isActive)
                  .toList();
              return DropdownButtonFormField<String>(
                initialValue: _position?.id,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Position'),
                items: [
                  for (final p in positions)
                    DropdownMenuItem(value: p.id, child: Text(p.title)),
                ],
                onChanged: (id) => setState(
                  () => _position = positions.firstWhere((p) => p.id == id),
                ),
              );
            },
          ),
          if (_position?.level == PositionLevel.zone) ...[
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
              onChanged: (z) => setState(() => _zoneId = z),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.play_arrow_outlined),
                  title: const Text('Term starts'),
                  subtitle: Text(formatDate(_start)),
                  onTap: () async {
                    final d = await _pickDate(_start);
                    if (d != null) setState(() => _start = d);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.stop_outlined),
                  title: const Text('Term ends (optional)'),
                  subtitle: Text(_end == null ? 'Not set' : formatDate(_end)),
                  trailing: _end == null
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _end = null),
                        ),
                  onTap: () async {
                    final d = await _pickDate(
                      _end ??
                          DateTime(_start.year + 2, _start.month, _start.day),
                    );
                    if (d != null) setState(() => _end = d);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _responsibilities,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Responsibilities'),
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
            child: const Text('Save appointment'),
          ),
        ],
      ),
    );
  }
}
