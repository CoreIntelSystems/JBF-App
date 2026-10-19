import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../core/share_file.dart';
import '../../data/backup_service.dart';
import '../../data/repositories/actor.dart';
import '../auth/auth_cubit.dart';
import '../reports/report_export.dart' show ymd;

/// Password-protected backups to keep off the phone, restore on a new
/// phone, and the automatic daily copies kept on this phone.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  late Future<List<AutoBackup>> _auto = _loadAuto();
  bool _busy = false;

  BackupService get _backup => context.read<AppServices>().backup!;

  Future<List<AutoBackup>> _loadAuto() =>
      context.read<AppServices>().backup?.autoBackups() ??
      Future.value(const []);

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<String?> _askPassword({required bool confirm}) async {
    final a = TextEditingController();
    final b = TextEditingController();
    String? error;
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(confirm ? 'Backup password' : 'Enter backup password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (confirm)
                const Text(
                  'You need this password to restore. It cannot be '
                  'recovered, so write it down somewhere safe.',
                ),
              TextField(
                controller: a,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (confirm)
                TextField(
                  controller: b,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Repeat password',
                  ),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (confirm && a.text.length < 10) {
                  setState(() => error = 'Use at least 10 characters.');
                } else if (confirm && a.text != b.text) {
                  setState(() => error = 'The passwords do not match.');
                } else {
                  Navigator.of(context).pop(a.text);
                }
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create() async {
    final services = context.read<AppServices>();
    final user = context.read<AuthCubit>().user;
    final password = await _askPassword(confirm: true);
    if (password == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await _backup.createBackup(password);
      await services.audit.log(
        user?.actor(services.deviceId) ??
            Actor.system(deviceId: services.deviceId),
        'backup.create',
        newValue: {'bytes': bytes.length},
      );
      await shareBytes(
        bytes,
        'jbf-backup-${ymd(DateTime.now())}.jbf',
        mimeType: 'application/octet-stream',
        text: 'JBF encrypted backup',
      );
    } on BackupException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmRestore(String what) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace all data on this phone?'),
          content: Text(
            '$what\n\nEverything on this phone will be replaced by the '
            'backup. The app will close; open it again and sign in with an '
            'account from the backup.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Restore'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _finishRestore(Future<dynamic> Function() prepare) async {
    final services = context.read<AppServices>();
    setState(() => _busy = true);
    try {
      final file = await prepare();
      await services.db.close();
      await _backup.replaceDatabase(file);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Backup restored'),
          content: const Text('The app will now close. Open it again.'),
          actions: [
            FilledButton(
              onPressed: () => SystemNavigator.pop(),
              child: const Text('Close app'),
            ),
          ],
        ),
      );
    } on BackupException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreFile() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Choose a .jbf backup',
    );
    if (picked == null) return;
    final Uint8List bytes = await picked.xFile.readAsBytes();
    final password = await _askPassword(confirm: false);
    if (password == null) return;
    BackupInfo info;
    try {
      setState(() => _busy = true);
      info = await _backup.inspect(bytes, password);
    } on BackupException catch (e) {
      _snack(e.message);
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    final ok = await _confirmRestore(
      '${info.orgName}: ${info.members} members, ${info.payments} payments'
      '${info.lastActivity == null ? '' : ', last used ${formatDate(info.lastActivity)}'}.',
    );
    if (!ok) return;
    await _finishRestore(() => _backup.prepareRestore(bytes, password));
  }

  Future<void> _restoreAuto(AutoBackup b) async {
    final ok = await _confirmRestore(
      'Automatic copy from ${formatDateTime(b.takenAt)}.',
    );
    if (!ok) return;
    await _finishRestore(() => _backup.prepareAutoRestore(b));
  }

  @override
  Widget build(BuildContext context) {
    final available = context.read<AppServices>().backup != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Backup and restore')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy) const LinearProgressIndicator(),
            const Text(
              'Make a backup at least once a month and keep it off this '
              'phone (Google Drive, email or another phone). It is '
              'encrypted with a password you choose.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: available ? _create : null,
              icon: const Icon(Icons.backup),
              label: const Text('Create backup and share'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: available ? _restoreFile : null,
              icon: const Icon(Icons.restore),
              label: const Text('Restore from a backup file'),
            ),
            const SizedBox(height: 24),
            Text(
              'Automatic copies on this phone',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              'Taken once a day when the app opens; the last 7 are kept. '
              'They do not help if the phone is lost.',
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<AutoBackup>>(
              future: _auto,
              builder: (context, snap) {
                final items = snap.data ?? const [];
                if (items.isEmpty) {
                  return const ListTile(title: Text('None yet'));
                }
                return Card(
                  child: Column(
                    children: [
                      for (final b in items)
                        ListTile(
                          leading: const Icon(Icons.history),
                          title: Text(formatDateTime(b.takenAt)),
                          trailing: TextButton(
                            onPressed: () => _restoreAuto(b),
                            child: const Text('Restore'),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _auto = _loadAuto()),
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}
