import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../data/database.dart';
import '../../data/sync/sync_api.dart';
import '../chats/chats_screen.dart';

Future<String?> _askText(
  BuildContext context, {
  required String title,
  required String label,
  required String action,
  String? intro,
}) {
  final text = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (intro != null) ...[Text(intro), const SizedBox(height: 8)],
          TextField(
            key: const Key('disciplineText'),
            controller: text,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: label),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(text.text.trim()),
          child: Text(action),
        ),
      ],
    ),
  );
}

/// A Zone Mayor or Zone Secretary (or the General Secretary) sends a
/// complaint about [member] to the Disciplinary Committee.
Future<void> fileComplaint(
  BuildContext context,
  ChatAccess access,
  Member member,
) async {
  final api = context.read<AppServices>().sync.api;
  final messenger = ScaffoldMessenger.of(context);
  final details = await _askText(
    context,
    title: 'Complaint about ${member.fullName}',
    label: 'What happened',
    action: 'Send to committee',
    intro: 'Only the Disciplinary Committee will read this.',
  );
  if (details == null || details.isEmpty) return;
  try {
    await api.disciplineFile(
      access.token,
      member.id,
      details,
      asName: access.asName,
    );
    messenger.showSnackBar(
      const SnackBar(content: Text('Sent to the Disciplinary Committee.')),
    );
  } on SyncException catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          e.offline ? 'Connect to the internet to send this.' : e.message,
        ),
      ),
    );
  }
}

/// The Disciplinary Committee's complaints and warnings.
class DisciplineScreen extends StatefulWidget {
  const DisciplineScreen({super.key, required this.access});

  final ChatAccess access;

  @override
  State<DisciplineScreen> createState() => _DisciplineScreenState();
}

class _DisciplineScreenState extends State<DisciplineScreen> {
  late final _api = context.read<AppServices>().sync.api;
  List<DisciplineCase>? _cases;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await _api.disciplineList(
        widget.access.token,
        asName: widget.access.asName,
      );
      if (mounted) {
        setState(() {
          _cases = c;
          _error = null;
        });
      }
    } on SyncException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.offline
              ? 'This needs internet. Connect and pull down to try again.'
              : e.message,
        );
      }
    }
  }

  Future<void> _open(DisciplineCase c) async {
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(
                '${c.memberName}${c.memberNo == null ? '' : ' (${c.memberNo})'}',
              ),
              subtitle: Text(
                '${c.kind == 'warning' ? 'Warning' : 'Complaint by ${c.by}'}'
                ' · ${formatDate(c.at)}\n\n${c.details}',
              ),
              isThreeLine: true,
            ),
            ListTile(
              leading: const Icon(Icons.warning_amber_outlined),
              title: const Text('Send a warning'),
              subtitle: const Text('The member sees it on their page'),
              onTap: () => Navigator.of(context).pop('warn'),
            ),
            if (c.kind == 'complaint' && c.open)
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Close this complaint'),
                onTap: () => Navigator.of(context).pop('close'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    String? warning;
    if (choice == 'warn') {
      warning = await _askText(
        context,
        title: 'Warning to ${c.memberName}',
        label: 'Warning',
        action: 'Send warning',
      );
      if (warning == null || warning.isEmpty) return;
    }
    try {
      await _api.disciplineWarn(
        widget.access.token,
        c.memberId,
        warning: warning,
        closeCase: c.kind == 'complaint' && c.open ? c.id : null,
        asName: widget.access.asName,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            warning == null ? 'Complaint closed.' : 'Warning sent.',
          ),
        ),
      );
      await _load();
    } on SyncException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.offline ? 'No internet connection.' : e.message),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cases = _cases;
    return Scaffold(
      appBar: AppBar(title: const Text('Discipline')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_error != null)
              Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
            if (cases == null && _error == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (cases != null && cases.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text('No complaints.', textAlign: TextAlign.center),
              ),
            for (final c in cases ?? const <DisciplineCase>[])
              ListTile(
                leading: Icon(
                  c.kind == 'warning'
                      ? Icons.warning_amber_outlined
                      : c.open
                      ? Icons.report_outlined
                      : Icons.check_circle_outline,
                ),
                title: Text(c.memberName),
                subtitle: Text(
                  '${c.kind == 'warning'
                      ? 'Warning'
                      : c.open
                      ? 'Open complaint'
                      : 'Closed complaint'}'
                  ' · ${formatDate(c.at)} · ${c.details}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _open(c),
              ),
          ],
        ),
      ),
    );
  }
}
