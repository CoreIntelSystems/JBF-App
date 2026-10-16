import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../core/ui.dart';
import '../chats/chats_screen.dart' show ChatAccess;
import 'office_api.dart';
import 'office_screen.dart';

IconData officeIcon(String key) => switch (key) {
  'ec' => Icons.how_to_vote_rounded,
  'welfare' => Icons.volunteer_activism,
  'discipline' => Icons.gavel_outlined,
  'organizing' => Icons.event_available_outlined,
  _ => Icons.groups_2_outlined,
};

/// The committee offices this person sits in, as tiles under a heading.
/// Shows nothing when they sit in none or the cloud cannot be reached, so
/// it can sit on any home screen.
class MyOffices extends StatefulWidget {
  const MyOffices({super.key, required this.access});

  final ChatAccess access;

  @override
  State<MyOffices> createState() => _MyOfficesState();
}

class _MyOfficesState extends State<MyOffices> {
  late final _api = OfficeApi(
    context.read<AppServices>().sync.api,
    widget.access.token,
  );
  List<Map<String, dynamic>> _offices = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o = await _api.list();
      if (mounted) setState(() => _offices = o);
    } catch (_) {
      // No internet or no member sign-in: the tiles simply stay hidden.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_offices.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('My committee office'),
        GroupCard(
          children: [
            for (final o in _offices)
              ListTile(
                leading: IconBadge(officeIcon('${o['key']}'), size: 36),
                title: Text(
                  '${o['name']}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(_subtitle(o)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => OfficeScreen(
                        api: _api,
                        committee: '${o['key']}',
                        title: '${o['name']}',
                      ),
                    ),
                  );
                  _load();
                },
              ),
          ],
        ),
      ],
    );
  }

  static String _subtitle(Map<String, dynamic> o) {
    final mine = (o['my_tasks'] as num?)?.toInt() ?? 0;
    final open = (o['open_tasks'] as num?)?.toInt() ?? 0;
    return [
      '${o['role_name']}',
      if (mine > 0)
        '$mine ${mine == 1 ? 'task' : 'tasks'} for you'
      else if (open > 0)
        '$open open ${open == 1 ? 'task' : 'tasks'}',
    ].join(' · ');
  }
}

/// The latest notices committees have posted to every member. Shows
/// nothing when there are none or the cloud cannot be reached.
class CommitteeNotices extends StatefulWidget {
  const CommitteeNotices({super.key, required this.access});

  final ChatAccess access;

  @override
  State<CommitteeNotices> createState() => _CommitteeNoticesState();
}

class _CommitteeNoticesState extends State<CommitteeNotices> {
  List<Map<String, dynamic>> _notices = const [];

  @override
  void initState() {
    super.initState();
    OfficeApi(context.read<AppServices>().sync.api, widget.access.token)
        .notices()
        .then((n) {
          if (mounted) setState(() => _notices = n.take(5).toList());
        })
        .catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final n in _notices)
          Card(
            child: ListTile(
              leading: IconBadge(officeIcon('${n['committee']}'), size: 36),
              title: Text(
                '${n['title']}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${n['body']}\n'
                '${['From the ${n['from'] ?? 'committee'}', if (DateTime.tryParse('${n['at']}') case final at?) formatDate(at)].join(' · ')}',
              ),
              isThreeLine: true,
            ),
          ),
      ],
    );
  }
}
