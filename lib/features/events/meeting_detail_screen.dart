import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../data/database.dart';
import '../../data/repositories/events_repository.dart';
import '../../domain/permissions.dart';
import '../auth/auth_cubit.dart';
import 'attendance_screen.dart';
import 'meeting_form_screen.dart';

class MeetingDetailScreen extends StatefulWidget {
  const MeetingDetailScreen({super.key, required this.meetingId});
  final String meetingId;

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  late final _services = context.read<AppServices>();
  late final Stream<Meeting> _meeting = _services.events.watchMeeting(
    widget.meetingId,
  );
  late final Stream<List<AttendanceEntry>> _attendance = _services.events
      .watchAttendance(widget.meetingId);

  Future<void> _editMinutes(Meeting m) async {
    final ctl = TextEditingController(text: m.minutes);
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Minutes'),
        content: TextField(
          controller: ctl,
          minLines: 6,
          maxLines: 14,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Decisions taken, who will do what, next meeting',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (text == null || !mounted) return;
    final user = context.read<AuthCubit>().user!;
    await _services.events.saveMinutes(
      m.id,
      text,
      user.actor(_services.deviceId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit c) => c.user);
    final canManage = user?.can(Perm.eventsManage) ?? false;
    final canAttend = (user?.can(Perm.attendanceRecord) ?? false) || canManage;
    final text = Theme.of(context).textTheme;
    return StreamBuilder<Meeting>(
      stream: _meeting,
      builder: (context, snap) {
        final m = snap.data;
        if (m == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(m.title),
            actions: [
              if (canManage)
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MeetingFormScreen(meeting: m),
                    ),
                  ),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(m.kind.label, style: text.labelLarge),
              const SizedBox(height: 4),
              Text(formatDateTime(m.heldOn), style: text.titleMedium),
              if (m.venue != null) Text(m.venue!),
              if (m.agenda != null) ...[
                const SizedBox(height: 16),
                Text('Agenda', style: text.titleMedium),
                Text(m.agenda!),
              ],
              const SizedBox(height: 16),
              Text('Attendance', style: text.titleMedium),
              StreamBuilder<List<AttendanceEntry>>(
                stream: _attendance,
                builder: (context, snap) {
                  final c = EventsRepository.count(snap.data ?? const []);
                  return Text(
                    '${c.present} present, ${c.absent} absent, '
                    '${c.excused} excused',
                  );
                },
              ),
              if (canAttend) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AttendanceScreen(
                        occasionId: m.id,
                        title: m.title,
                        meeting: m,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.how_to_reg),
                  label: const Text('Take attendance'),
                ),
              ],
              const SizedBox(height: 16),
              Text('Minutes', style: text.titleMedium),
              Text(m.minutes ?? 'No minutes yet.'),
              if (canManage) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _editMinutes(m),
                  icon: const Icon(Icons.notes),
                  label: Text(
                    m.minutes == null ? 'Write minutes' : 'Edit minutes',
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
