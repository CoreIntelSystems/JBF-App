import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../data/database.dart';
import '../../domain/permissions.dart';
import '../auth/auth_cubit.dart';
import 'event_detail_screen.dart';
import 'event_form_screen.dart';
import 'meeting_detail_screen.dart';
import 'meeting_form_screen.dart';

/// Events and meetings, upcoming first within each list.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));
  late final _services = context.read<AppServices>();
  late final Stream<List<Event>> _events = _services.events.watchEvents();
  late final Stream<List<Meeting>> _meetings = _services.events.watchMeetings();

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  /// Upcoming soonest first, then past most recent first.
  static List<T> _order<T>(List<T> items, DateTime Function(T) at) {
    final now = DateTime.now().subtract(const Duration(hours: 12));
    final upcoming = items.where((e) => at(e).isAfter(now)).toList()
      ..sort((a, b) => at(a).compareTo(at(b)));
    final past = items.where((e) => !at(e).isAfter(now)).toList();
    return [...upcoming, ...past];
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit c) => c.user);
    final canManage = user?.can(Perm.eventsManage) ?? false;
    final now = DateTime.now().subtract(const Duration(hours: 12));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events and meetings'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Events'),
            Tab(text: 'Meetings'),
          ],
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              heroTag: 'events-fab',
              onPressed: () => _open(
                _tabs.index == 0
                    ? const EventFormScreen()
                    : const MeetingFormScreen(),
              ),
              icon: const Icon(Icons.add),
              label: Text(_tabs.index == 0 ? 'New event' : 'New meeting'),
            )
          : null,
      body: TabBarView(
        controller: _tabs,
        children: [
          StreamBuilder<List<Event>>(
            stream: _events,
            builder: (context, snap) {
              final items = snap.data;
              if (items == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (items.isEmpty) {
                return const _Empty('No events yet.');
              }
              return ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  for (final e in _order(items, (e) => e.startsOn))
                    ListTile(
                      leading: Icon(
                        e.status == EventStatus.cancelled
                            ? Icons.event_busy
                            : e.startsOn.isAfter(now)
                            ? Icons.event
                            : Icons.event_available,
                      ),
                      title: Text(e.name),
                      subtitle: Text(
                        [
                          formatDateTime(e.startsOn),
                          if (e.venue != null) e.venue!,
                          if (e.status != EventStatus.planned) e.status.label,
                        ].join(', '),
                      ),
                      onTap: () => _open(EventDetailScreen(eventId: e.id)),
                    ),
                ],
              );
            },
          ),
          StreamBuilder<List<Meeting>>(
            stream: _meetings,
            builder: (context, snap) {
              final items = snap.data;
              if (items == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (items.isEmpty) {
                return const _Empty('No meetings yet.');
              }
              return ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  for (final m in _order(items, (m) => m.heldOn))
                    ListTile(
                      leading: Icon(
                        m.heldOn.isAfter(now)
                            ? Icons.groups_outlined
                            : Icons.groups,
                      ),
                      title: Text(m.title),
                      subtitle: Text(
                        '${m.kind.label}, ${formatDateTime(m.heldOn)}',
                      ),
                      onTap: () => _open(MeetingDetailScreen(meetingId: m.id)),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(24), child: Text(text)),
  );
}
