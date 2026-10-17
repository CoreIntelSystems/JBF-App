import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../data/database.dart';
import '../../data/repositories/events_repository.dart';
import '../auth/auth_cubit.dart';
import 'scan_screen.dart';

/// Mark who is present, absent or excused, by hand or by scanning ID cards.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    super.key,
    required this.occasionId,
    required this.title,
    this.meeting,
  });

  /// The event's or meeting's id.
  final String occasionId;
  final String title;

  /// Decides who is expected; null for events (all active members).
  final Meeting? meeting;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late final _services = context.read<AppServices>();
  late final Stream<List<AttendanceEntry>> _records = _services.events
      .watchAttendance(widget.occasionId);
  List<Member>? _expected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _services.events.expected(meeting: widget.meeting).then((m) {
      if (mounted) setState(() => _expected = m);
    });
  }

  Future<void> _mark(Member m, AttendanceStatus s) {
    final user = context.read<AuthCubit>().user!;
    return _services.events.mark(
      widget.occasionId,
      m.id,
      s,
      user.actor(_services.deviceId),
      recordedByName: user.displayName,
    );
  }

  Future<void> _closeRegister() async {
    final expected = _expected;
    if (expected == null) return;
    final user = context.read<AuthCubit>().user!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark everyone else absent?'),
        content: const Text(
          'Members not yet marked will be recorded as absent. You can still '
          'change anyone afterwards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Mark absent'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _services.events.markRestAbsent(
      widget.occasionId,
      expected,
      user.actor(_services.deviceId),
      recordedByName: user.displayName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final expected = _expected;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Mark the rest absent',
            icon: const Icon(Icons.playlist_remove),
            onPressed: _closeRegister,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'attendance-scan',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                ScanScreen(occasionId: widget.occasionId, title: widget.title),
          ),
        ),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan ID cards'),
      ),
      body: expected == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<AttendanceEntry>>(
              stream: _records,
              builder: (context, snap) {
                final records = snap.data ?? const <AttendanceEntry>[];
                final byMember = {for (final r in records) r.member.id: r};
                final people = <Member>[
                  ...expected,
                  for (final r in records)
                    if (!expected.any((m) => m.id == r.member.id)) r.member,
                ];
                final q = _query.toLowerCase();
                final shown = q.isEmpty
                    ? people
                    : people
                          .where(
                            (m) =>
                                m.fullName.toLowerCase().contains(q) ||
                                (m.whatsappName ?? '').toLowerCase().contains(
                                  q,
                                ) ||
                                m.memberNo.toLowerCase().contains(q),
                          )
                          .toList();
                final c = EventsRepository.count(records);
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: shown.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${c.present} present, ${c.absent} absent, '
                              '${c.excused} excused, '
                              '${people.length - records.length} not marked',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                hintText: 'Search name or ID',
                              ),
                              onChanged: (v) => setState(() => _query = v),
                            ),
                          ],
                        ),
                      );
                    }
                    final m = shown[i - 1];
                    final r = byMember[m.id]?.record;
                    return _AttendanceTile(
                      member: m,
                      record: r,
                      onMark: (s) => _mark(m, s),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _AttendanceTile extends StatelessWidget {
  const _AttendanceTile({
    required this.member,
    required this.record,
    required this.onMark,
  });

  final Member member;
  final AttendanceRecord? record;
  final ValueChanged<AttendanceStatus> onMark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = record?.status;
    Widget button(AttendanceStatus s, IconData icon, Color color) => IconButton(
      tooltip: '${s.label}: ${member.fullName}',
      isSelected: status == s,
      icon: Icon(icon),
      selectedIcon: Icon(icon, color: color),
      style: status == s
          ? IconButton.styleFrom(backgroundColor: color.withValues(alpha: 0.15))
          : null,
      onPressed: () => onMark(s),
    );
    return ListTile(
      title: Text(member.fullName),
      subtitle: Text(
        [
          member.memberNo,
          if (status != null) status.label,
          if (record?.method == AttendanceMethod.qr) 'scanned',
        ].join(', '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(AttendanceStatus.present, Icons.check_circle, Colors.green),
          button(AttendanceStatus.absent, Icons.cancel, scheme.error),
          button(AttendanceStatus.excused, Icons.event_busy, Colors.orange),
        ],
      ),
    );
  }
}
