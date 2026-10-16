import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../data/database.dart';
import '../../data/repositories/events_repository.dart';
import '../../domain/permissions.dart';
import '../auth/auth_cubit.dart';
import '../members/member_detail_screen.dart';
import 'appoint_screen.dart';

/// Who holds which position, with past terms kept as history.
class ExecutivesScreen extends StatefulWidget {
  const ExecutivesScreen({super.key});

  @override
  State<ExecutivesScreen> createState() => _ExecutivesScreenState();
}

class _ExecutivesScreenState extends State<ExecutivesScreen> {
  late final _services = context.read<AppServices>();
  late final Stream<List<ExecutiveView>> _current = _services.events
      .watchExecutives();
  late final Stream<List<ExecutiveView>> _past = _services.events
      .watchExecutives(current: false);

  Future<void> _show(ExecutiveView v, bool canManage) async {
    final (attended, held) = await _services.events.meetingAttendance(v);
    if (!mounted) return;
    final e = v.executive;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              v.member.fullName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(v.title),
            const SizedBox(height: 8),
            Text(
              'Term: ${formatDate(e.termStart)} to '
              '${e.endedOn != null
                  ? formatDate(e.endedOn)
                  : e.termEnd != null
                  ? '${formatDate(e.termEnd)} (planned)'
                  : 'present'}',
            ),
            if (e.endedReason != null) Text('Left: ${e.endedReason}'),
            if (e.responsibilities != null) ...[
              const SizedBox(height: 8),
              Text(e.responsibilities!),
            ],
            const SizedBox(height: 8),
            Text(
              held == 0
                  ? 'No executive meetings during this term yet.'
                  : 'Attended $attended of $held executive meetings.',
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop('member'),
              child: const Text('Open member'),
            ),
            if (canManage && v.isCurrent) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop('end'),
                child: const Text('End term'),
              ),
            ],
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'member') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MemberDetailScreen(memberId: v.member.id),
        ),
      );
    } else if (action == 'end') {
      await _endTerm(v);
    }
  }

  Future<void> _endTerm(ExecutiveView v) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('End ${v.member.fullName}\'s term?'),
        content: TextField(
          controller: reason,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'e.g. Term ended, resigned, elections',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End term'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final user = context.read<AuthCubit>().user!;
    await _services.events.endTerm(
      v.executive.id,
      DateTime.now(),
      reason.text,
      user.actor(_services.deviceId),
    );
  }

  Widget _list(
    Stream<List<ExecutiveView>> stream,
    bool canManage,
    String empty,
  ) => StreamBuilder<List<ExecutiveView>>(
    stream: stream,
    builder: (context, snap) {
      final items = snap.data;
      if (items == null) {
        return const Center(child: CircularProgressIndicator());
      }
      if (items.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(empty, textAlign: TextAlign.center),
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          for (final v in items)
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(v.member.fullName),
              subtitle: Text(
                '${v.title}\nSince ${formatDate(v.executive.termStart)}'
                '${v.executive.endedOn == null ? '' : ' to ${formatDate(v.executive.endedOn)}'}',
              ),
              isThreeLine: true,
              onTap: () => _show(v, canManage),
            ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit c) => c.user);
    final canManage = user?.can(Perm.executivesManage) ?? false;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Executives'),
          actions: [
            if (canManage)
              IconButton(
                tooltip: 'Positions',
                icon: const Icon(Icons.account_tree_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PositionsScreen(),
                  ),
                ),
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Current'),
              Tab(text: 'Past'),
            ],
          ),
        ),
        floatingActionButton: canManage
            ? FloatingActionButton.extended(
                heroTag: 'executives-fab',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AppointScreen(),
                  ),
                ),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Appoint'),
              )
            : null,
        body: TabBarView(
          children: [
            _list(
              _current,
              canManage,
              'No executives recorded yet. Tap Appoint to add the current '
              'office holders.',
            ),
            _list(_past, canManage, 'No past terms yet.'),
          ],
        ),
      ),
    );
  }
}

/// The list of positions, with a way to add new ones.
class PositionsScreen extends StatelessWidget {
  const PositionsScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final services = context.read<AppServices>();
    final user = context.read<AuthCubit>().user!;
    final title = TextEditingController();
    var level = PositionLevel.national;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New position'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PositionLevel>(
                initialValue: level,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Level'),
                items: [
                  for (final l in PositionLevel.values)
                    DropdownMenuItem(value: l, child: Text(l.label)),
                ],
                onChanged: (l) => setState(() => level = l!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await services.events.addPosition(
        title.text,
        level,
        user.actor(services.deviceId),
      );
    } on EventsException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Positions')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'positions-fab',
        tooltip: 'Add position',
        onPressed: () => _add(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<ExecutivePosition>>(
        stream: context.read<AppServices>().events.watchPositions(),
        builder: (context, snap) => ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            for (final p in snap.data ?? const <ExecutivePosition>[])
              ListTile(title: Text(p.title), subtitle: Text(p.level.label)),
          ],
        ),
      ),
    );
  }
}

/// Positions a member holds or held, for the member page.
class MemberPositionsSection extends StatelessWidget {
  const MemberPositionsSection({super.key, required this.member});
  final Member member;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ExecutiveView>>(
      stream: context.read<AppServices>().events.watchMemberPositions(
        member.id,
      ),
      builder: (context, snap) {
        final items = snap.data ?? const <ExecutiveView>[];
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Positions', style: Theme.of(context).textTheme.titleMedium),
              for (final v in items)
                Text(
                  '${v.title} (${formatDate(v.executive.termStart)} to '
                  '${v.executive.endedOn == null ? 'present' : formatDate(v.executive.endedOn)})',
                ),
            ],
          ),
        );
      },
    );
  }
}
